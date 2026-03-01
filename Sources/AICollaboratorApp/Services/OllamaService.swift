//
//  OllamaService.swift
//  AICollaborator
//
//  Created: 2025-04-10
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Service for interacting with Ollama models
public actor OllamaService {
    // MARK: - Types

    /// Model information from Ollama
    public struct OllamaModel: Identifiable, Equatable, Codable, Sendable {
        public let name: String
        public let size: Int
        public let modifiedAt: Date
        public let digest: String
        public let details: ModelDetails?

        public var id: String { name }

        public var formattedSize: String {
            let formatter = ByteCountFormatter()
            formatter.allowedUnits = [.useGB, .useMB]
            formatter.countStyle = .file
            return formatter.string(fromByteCount: Int64(size))
        }
    }

    /// Detailed model parameters
    public struct ModelDetails: Codable, Equatable, Sendable {
        public let family: String?
        public let parameterCount: String?
        public let quantization: String?
        public let temperature: Double?
    }

    /// Generation options for Ollama models
    public struct GenerationOptions: Codable, Equatable, Sendable {
        public var temperature: Double
        public var topP: Double
        public var numPredict: Int
        public var stop: [String]?

        public static let `default` = GenerationOptions(
            temperature: 0.7,
            topP: 0.9,
            numPredict: 512
        )

        public init(
            temperature: Double = 0.7,
            topP: Double = 0.9,
            numPredict: Int = 512,
            stop: [String]? = nil
        ) {
            self.temperature = temperature
            self.topP = topP
            self.numPredict = numPredict
            self.stop = stop
        }
    }

    /// Progress information for model pull
    public struct PullProgress: Sendable {
        public let status: String
        public let completed: Int?
        public let total: Int?

        public var progressFraction: Double? {
            guard let c = completed, let t = total, t > 0 else { return nil }
            return Double(c) / Double(t)
        }
    }

    /// Error types for OllamaService
    public enum OllamaServiceError: Error, LocalizedError {
        case modelNotFound(String)
        case requestFailed(String)
        case invalidResponse(String)
        case serverUnavailable
        case encodingFailed

        public var errorDescription: String? {
            switch self {
            case .modelNotFound(let name): return "Model not found: \(name)"
            case .requestFailed(let details): return "Request failed: \(details)"
            case .invalidResponse(let details): return "Invalid response: \(details)"
            case .serverUnavailable: return "Ollama server is not available"
            case .encodingFailed: return "Failed to encode request body"
            }
        }
    }

    // MARK: - Properties

    private let baseURL: URL
    private var availableModels: [OllamaModel] = []
    private var lastModelRefresh: Date?
    private(set) public var selectedModel: String?

    // MARK: - Initialization

    public init(baseURL: URL = URL(string: "http://localhost:11434")!) {
        self.baseURL = baseURL
    }

    // MARK: - Public Methods

    /// Check if Ollama server is available
    public func checkAvailability() async -> Bool {
        let url = baseURL.appendingPathComponent("api/tags")
        var request = URLRequest(url: url)
        request.timeoutInterval = 5.0
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }

    /// Select a model for use
    public func selectModel(_ modelName: String) async throws {
        let models = try await listModels()
        guard models.contains(where: { $0.name == modelName }) else {
            throw OllamaServiceError.modelNotFound(modelName)
        }
        self.selectedModel = modelName
    }

    /// List available models from Ollama
    public func listModels(forceRefresh: Bool = false) async throws -> [OllamaModel] {
        if !forceRefresh,
           !availableModels.isEmpty,
           let lastRefresh = lastModelRefresh,
           Date().timeIntervalSince(lastRefresh) < 60 {
            return availableModels
        }

        let url = baseURL.appendingPathComponent("api/tags")
        var request = URLRequest(url: url)
        request.timeoutInterval = 10.0

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let modelsArray = json["models"] as? [[String: Any]] else {
                throw OllamaServiceError.invalidResponse("Could not parse models list")
            }

            let formatter = ISO8601DateFormatter()
            let models: [OllamaModel] = modelsArray.compactMap { dict in
                guard let name = dict["name"] as? String else { return nil }
                let size = dict["size"] as? Int ?? 0
                let modifiedAt = formatter.date(from: dict["modified_at"] as? String ?? "") ?? Date()
                let digest = dict["digest"] as? String ?? ""

                var details: ModelDetails? = nil
                if let detailsDict = dict["details"] as? [String: Any] {
                    details = ModelDetails(
                        family: detailsDict["family"] as? String,
                        parameterCount: detailsDict["parameter_count"] as? String,
                        quantization: detailsDict["quantization"] as? String,
                        temperature: detailsDict["temperature"] as? Double
                    )
                }

                return OllamaModel(
                    name: name, size: size, modifiedAt: modifiedAt,
                    digest: digest, details: details
                )
            }

            self.availableModels = models
            self.lastModelRefresh = Date()
            return models
        } catch let error as OllamaServiceError {
            throw error
        } catch {
            throw OllamaServiceError.requestFailed(error.localizedDescription)
        }
    }

    /// Generate text from a prompt (streaming)
    public func generateText(
        prompt: String,
        model: String? = nil,
        options: GenerationOptions = .default
    ) async throws -> AsyncThrowingStream<String, Error> {
        let modelName = model ?? selectedModel ?? "llama3.2:latest"
        let url = baseURL.appendingPathComponent("api/generate")

        var bodyDict: [String: Any] = [
            "model": modelName,
            "prompt": prompt,
            "stream": true,
            "options": [
                "temperature": options.temperature,
                "top_p": options.topP,
                "num_predict": options.numPredict
            ] as [String: Any]
        ]
        if let stop = options.stop { bodyDict["stop"] = stop }

        guard let bodyData = try? JSONSerialization.data(withJSONObject: bodyDict) else {
            throw OllamaServiceError.encodingFailed
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = bodyData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 120.0

        let capturedRequest = request
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    let (data, response) = try await URLSession.shared.data(for: capturedRequest)
                    guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                        continuation.finish(throwing: OllamaServiceError.serverUnavailable)
                        return
                    }

                    let lines = String(data: data, encoding: .utf8)?
                        .components(separatedBy: .newlines) ?? []
                    for line in lines {
                        guard !line.isEmpty else { continue }
                        guard let lineData = line.data(using: .utf8),
                              let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any] else {
                            continue
                        }

                        if let token = json["response"] as? String {
                            continuation.yield(token)
                        }

                        if let done = json["done"] as? Bool, done {
                            break
                        }
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    /// Generate text (non-streaming, returns complete response)
    public func generateTextComplete(
        prompt: String,
        model: String? = nil,
        options: GenerationOptions = .default
    ) async throws -> String {
        let modelName = model ?? selectedModel ?? "llama3.2:latest"
        let url = baseURL.appendingPathComponent("api/generate")

        let bodyDict: [String: Any] = [
            "model": modelName,
            "prompt": prompt,
            "stream": false,
            "options": [
                "temperature": options.temperature,
                "top_p": options.topP,
                "num_predict": options.numPredict
            ] as [String: Any]
        ]

        guard let bodyData = try? JSONSerialization.data(withJSONObject: bodyDict) else {
            throw OllamaServiceError.encodingFailed
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = bodyData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 120.0

        let (data, _) = try await URLSession.shared.data(for: request)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let response = json["response"] as? String else {
            throw OllamaServiceError.invalidResponse("Could not parse generate response")
        }

        return response
    }

    /// Pull a model from Ollama repository
    public func pullModel(modelName: String) async throws -> AsyncThrowingStream<PullProgress, Error> {
        let url = baseURL.appendingPathComponent("api/pull")
        let bodyDict: [String: Any] = ["name": modelName, "stream": true]

        guard let bodyData = try? JSONSerialization.data(withJSONObject: bodyDict) else {
            throw OllamaServiceError.encodingFailed
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = bodyData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 600.0

        let capturedPullRequest = request
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    let (data, _) = try await URLSession.shared.data(for: capturedPullRequest)
                    let lines = String(data: data, encoding: .utf8)?
                        .components(separatedBy: .newlines) ?? []
                    for line in lines {
                        guard !line.isEmpty else { continue }
                        guard let lineData = line.data(using: .utf8),
                              let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any] else {
                            continue
                        }

                        let status = json["status"] as? String ?? ""
                        let completed = json["completed"] as? Int
                        let total = json["total"] as? Int

                        continuation.yield(PullProgress(status: status, completed: completed, total: total))

                        if status == "success" { break }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
