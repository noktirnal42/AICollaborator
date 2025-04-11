//
//  OllamaService.swift
//  AICollaborator
//
//  Created: 2025-04-10
//

import Foundation
import Alamofire
import SwiftyJSON

/// Service for interacting with Ollama models
public actor OllamaService {
    // MARK: - Types
    
    /// Model information from Ollama
    public struct OllamaModel: Identifiable, Equatable, Codable {
        /// Unique model name
        public let name: String
        
        /// Model size in bytes
        public let size: Int
        
        /// Model modification time
        public let modifiedAt: Date
        
        /// Model digest (unique identifier)
        public let digest: String
        
        /// Model details/parameters
        public let details: ModelDetails?
        
        /// Unique identifier for Identifiable conformance
        public var id: String { name }
        
        /// Formatted size string
        public var formattedSize: String {
            let formatter = ByteCountFormatter()
            formatter.allowedUnits = [.useGB, .useMB]
            formatter.countStyle = .file
            return formatter.string(fromByteCount: Int64(size))
        }
    }
    
    /// Detailed model parameters
    public struct ModelDetails: Codable, Equatable {
        /// Model family/architecture
        public let family: String?
        
        /// Model parameter count
        public let parameterCount: String?
        
        /// Model quantization level
        public let quantization: String?
        
        /// Model temperature setting
        public let temperature: Double?
    }
    
    /// Generation options for Ollama models
    public struct GenerationOptions: Codable, Equatable {
        /// Temperature (randomness)
        public var temperature: Double
        
        /// Top-p sampling
        public var topP: Double
        
        /// Number of predictions to generate
        public var numPredict: Int
        
        /// Model specific options
        public var modelOptions: [String: Any]?
        
        /// Default generation options
        public static let `default` = GenerationOptions(
            temperature: 0.7,
            topP: 0.9,
            numPredict: 512
        )
        
        /// Initialize with custom parameters
        public init(
            temperature: Double = 0.7,
            topP: Double = 0.9,
            numPredict: Int = 512,
            modelOptions: [String: Any]? = nil
        ) {
            self.temperature = temperature
            self.topP = topP
            self.numPredict = numPredict
            self.modelOptions = modelOptions
        }
    }
    
    // MARK: - Properties
    
    /// Base URL for Ollama API
    private let baseURL: URL
    
    /// AF session manager
    private let session: Session
    
    /// Logger instance
    private let logger = Logger()
    
    /// Currently available models (cached)
    private var availableModels: [OllamaModel] = []
    
    /// Last refresh time for model list
    private var lastModelRefresh: Date?
    
    /// Currently selected model
    private(set) public var selectedModel: String?
    
    // MARK: - Initialization
    
    /// Initialize with custom Ollama API URL
    /// - Parameter baseURL: Base URL for Ollama API
    public init(baseURL: URL = URL(string: "http://localhost:11434")!) {
        self.baseURL = baseURL
        
        // Configure AF session
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30.0
        self.session = Session(configuration: configuration)
    }
    
    // MARK: - Public Methods
    
    /// List available models from Ollama
    /// - Parameter forceRefresh: Whether to bypass cache
    /// - Returns: Array of available models
    public func listModels(forceRefresh: Bool = false) async throws -> [OllamaModel] {
        // Check cache first unless force refresh requested
        if !forceRefresh, 
           !availableModels.isEmpty, 
           let lastRefresh = lastModelRefresh, 
           Date().timeIntervalSince(lastRefresh) < 60 {
            return availableModels
        }
        
        let url = baseURL.appendingPathComponent("api/tags")
        
        do {
            let data = try await session.request(url, method: .get)
                .validate()
                .serializingData()
                .value
            
            let json = try JSON(data: data)
            var models: [OllamaModel] = []
            
            if let modelsArray = json["models"].array {
                for modelJson in modelsArray {
                    let name = modelJson["name"].stringValue
                    let size = modelJson["size"].intValue
                    let modifiedAt = ISO8601DateFormatter().date(from: modelJson["modified_at"].stringValue) ?? Date()
                    let digest = modelJson["digest"].stringValue
                    
                    // Parse details if available
                    var details: ModelDetails? = nil
                    if let detailsJson = modelJson["details"].dictionary {
                        details = ModelDetails(
                            family: detailsJson["family"]?.string,
                            parameterCount: detailsJson["parameter_count"]?.string,
                            quantization: detailsJson["quantization"]?.string,
                            temperature: detailsJson["temperature"]?.double
                        )
                    }
                    
                    let model = OllamaModel(
                        name: name,
                        size: size,
                        modifiedAt: modifiedAt,
                        digest: digest,
                        details: details
                    )
                    
                    models.append(model)
                }
            }
            
            // Update cache
            self.availableModels = models
            self.lastModelRefresh = Date()
            
            return models
        } catch {
            logger.error("Error listing Ollama models: \(error.localizedDescription)")
            throw OllamaServiceError.requestFailed(error.localizedDescription)
        }
    }
    
    /// Pull a model from Ollama repository
    /// - Parameter modelName: Name of the model to pull
    /// - Returns: Progress updates as they arrive
    public func pullModel(modelName: String) async throws -> AsyncThrowingStream<PullProgress, Error> {
        let url = baseURL.appendingPathComponent("api/pull")
        
        let parameters: [String: Any] = [
            "name": modelName
        ]
        
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    // Make the pull request
                    let task = session.streamRequest(url, method: .post, parameters: parameters, encoding: JSONEncoding.default)
                        .validate()
                        .responseStream { stream in
                            switch stream.event {
                            case .stream(let result):
                                switch result {
                                case .success(let data):
                                    if let json = try? JSON(data: data) {
                                        // Extract progress information
                                        let status = json["status"].stringValue
                                        let completed = json["completed"].boolValue
                                        let progress = json["progress"].doubleValue
                                        let total = json["total"].intValue
                                        let downloaded = json["downloaded"].intValue
                                        
                                        let progressUpdate = PullProgress(
                                            status: status,
                                            completed: completed,
                                            progress: progress,
                                            total: total,
                                            downloaded: downloaded
                                        )
                                        
                                        continuation.yield(progressUpdate)
                                        
                                        if completed {
                                            continuation.finish()
                                        }
                                    }
                                case .failure(let error):
                                    continuation.finish(throwing: OllamaServiceError.requestFailed(error.localizedDescription))
                                }
                            case .complete(let completion):
                                if let error = completion.error {
                                    continuation.finish(throwing: OllamaServiceError.requestFailed(error.localizedDescription))
                                } else {
                                    // Ensure we finish if no final update was received
                                    continuation.finish()
                                }
                            }
                        }
                    
                    // Keep task alive
                    task.resume()
                    
                    // When the task is cancelled, finish the stream
                    continuation.onTermination = { _ in
                        task.cancel()
                    }
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    /// Select a model to use
    /// - Parameter modelName: Name of the model to select
    public func selectModel(_ modelName: String) async throws {
        // Verify model exists
        let models = try await listModels()
        guard models.contains(where: { $0.name == modelName }) else {
            throw OllamaServiceError.modelNotFound(modelName)
        }
        
        self.selectedModel = modelName
        logger.info("Selected model: \(modelName)")
    }
    
    /// Generate text using selected model
    /// - Parameters:
    ///   - prompt: Input prompt
    ///   - options: Generation options
    /// - Returns: Stream of generated text chunks
    public func generateText(prompt: String, options: GenerationOptions = .default) async throws -> AsyncThrowingStream<String, Error> {
        // Ensure a model is selected
        guard let modelName = selectedModel else {
            throw OllamaServiceError.noModelSelected
        }
        
        let url = baseURL.appendingPathComponent("api/generate")
        
        var parameters: [String: Any] = [
            "model": modelName,
            "prompt": prompt,
            "stream": true,
            "options": [
                "temperature": options.temperature,
                "top_p": options.topP,
                "num_predict": options.numPredict
            ]
        ]
        
        // Add any model-specific options
        if let modelOptions = options.modelOptions {
            var allOptions = parameters["options"] as! [String: Any]
            for (key, value) in modelOptions {
                allOptions[key] = value
            }
            parameters["options"] = allOptions
        }
        
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    // Make the generate request
                    let task = session.streamRequest(url, method: .post, parameters: parameters, encoding: JSONEncoding.default)
                        .validate()
                        .responseStream { stream in
                            switch stream.event {
                            case .stream(let result):
                                switch result {
                                case .success(let data):
                                    if let json = try? JSON(data: data) {
                                        // Extract generated text chunk
                                        let response = json["response"].stringValue
                                        let done = json["done"].boolValue
                                        
                                        if !response.isEmpty {
                                            continuation.yield(response)
                                        }
                                        
                                        if done {
                                            continuation.finish()
                                        }
                                    }
                                case .failure(let error):
                                    continuation.finish(throwing: OllamaServiceError.requestFailed(error.localizedDescription))
                                }
                            case .complete(let completion):
                                if let error = completion.error {
                                    continuation.finish(throwing: OllamaServiceError.requestFailed(error.localizedDescription))
                                } else {
                                    // Ensure we finish if no final update was received
                                    continuation.finish()
                                }
                            }
                        }
                    
                    // Keep task alive
                    task.resume()
                    
                    // When the task is cancelled, finish the stream
                    continuation.onTermination = { _ in
                        task.cancel()
                    }
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    /// Check if Ollama service is available
    /// - Returns: True if available
    public func checkAvailability() async -> Bool {
        do {
            let url = baseURL.appendingPathComponent("api/tags")
            _ = try await session.request(url, method: .get)
                .validate()
                .serializingData()
                .value
            return true
        } catch {
            logger.error("Ollama service unavailable: \(error.localizedDescription)")
            return false
        }
    }
}

// MARK: - Supporting Types

/// Progress update during model pull
public struct PullProgress: Equatable {
    /// Current status message
    public let status: String
    
    /// Whether the pull has completed
    public let completed: Bool
    
    /// Progress percentage (0-100)
    public let progress: Double
    
    /// Total size in bytes
    public let total: Int
    
    /// Downloaded bytes
    public let downloaded: Int
    
    /// Formatted download progress string
    public var formattedProgress: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .file
        return "\(formatter.string(fromByteCount: Int64(downloaded))) / \(formatter.string(fromByteCount: Int64(total)))"
    }
}

/// Errors specific to Ollama service
public enum OllamaServiceError: Error, LocalizedError {
    /// No model is selected
    case noModelSelected
    
    /// Requested model was not found
    case modelNotFound(String)
    
    /// API request failed
    case requestFailed(String)
    
    /// Invalid response format
    case invalidResponse(String)
    
    /// Localized error descriptions
    public var errorDescription: String? {
        switch self {
        case .noModelSelected:
            return "No Ollama model selected. Please select a model first."
        case .modelNotFound(let model):
            return "Ollama model '\(model)' not found. Please check available models."
        case .requestFailed(let reason):
            return "Ollama API request failed: \(reason)"
        case .invalidResponse(let reason):
            return "Invalid response from Ollama API: \(reason)"
        }
    }
}

/// Simple logger for OllamaService
private struct Logger {
    func info(_ message: String) {
        print("[OllamaService] INFO: \(message)")
    }
    
    func error(_ message: String) {
        print("[OllamaService] ERROR: \(message)")
    }
}

