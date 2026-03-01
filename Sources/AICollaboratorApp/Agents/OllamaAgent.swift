//
//  OllamaAgent.swift
//  AICollaborator
//
//  Created: 2025-04-10
//

import Foundation

/// Specialized agent for Ollama model interactions
public actor OllamaAgent: @preconcurrency AICollaboratorAgent {

    // MARK: - Types

    /// Ollama model family types
    public enum ModelFamily: Sendable {
        case llama
        case mistral
        case phi
        case gemma
        case mixtral
        case codellama
        case other(String)

        /// Map to capabilities
        var defaultCapabilities: [AICapability] {
            switch self {
            case .llama, .mistral, .gemma, .mixtral:
                return [.basicCompletion, .textAnalysis, .conversational, .summarization]
            case .codellama:
                return [.basicCompletion, .codeGeneration, .textAnalysis]
            case .phi:
                return [.basicCompletion, .textAnalysis, .codeGeneration]
            case .other:
                return [.basicCompletion]
            }
        }

        var recommendedTemperature: Double {
            switch self {
            case .codellama: return 0.3
            case .llama, .mistral, .phi: return 0.7
            case .gemma: return 0.8
            case .mixtral: return 0.75
            case .other: return 0.7
            }
        }

        static func fromModelName(_ name: String) -> ModelFamily {
            let lower = name.lowercased()
            if lower.contains("llama") {
                return lower.contains("code") ? .codellama : .llama
            } else if lower.contains("mistral") { return .mistral
            } else if lower.contains("phi") { return .phi
            } else if lower.contains("gemma") { return .gemma
            } else if lower.contains("mixtral") { return .mixtral
            } else { return .other(name) }
        }
    }

    /// Error types for OllamaAgent
    public enum OllamaAgentError: Error, LocalizedError, Sendable {
        case modelNotFound(String)
        case noModelSelected
        case generationFailed(String)

        public var errorDescription: String? {
            switch self {
            case .modelNotFound(let name): return "Model not found: \(name)"
            case .noModelSelected: return "No model selected. Call selectModel() first."
            case .generationFailed(let details): return "Generation failed: \(details)"
            }
        }
    }

    // MARK: - Properties

    private let ollamaService: OllamaService
    private var availableModels: [OllamaService.OllamaModel] = []
    private var currentModel: String?
    private var modelFamily: ModelFamily
    private var state: AgentState = .idle
    private var responseCache: [String: (response: String, timestamp: Date)] = [:]
    private let maxCacheSize = 50
    private let cacheExpirationSeconds: TimeInterval = 600

    // MARK: - Initialization

    public init(
        ollamaService: OllamaService,
        initialModel: String? = nil
    ) {
        self.ollamaService = ollamaService
        self.currentModel = initialModel
        self.modelFamily = initialModel.map { ModelFamily.fromModelName($0) } ?? .llama
    }

    // MARK: - AICollaboratorAgent Protocol

    public func processTask(_ task: AITask) async throws -> AITaskResult {
        state = .busy(taskId: task.taskId)
        defer { state = .idle }

        let prompt: String
        switch task.input {
        case .text(let text): prompt = text
        default: prompt = task.query
        }

        // Check cache
        let cacheKey = "\(currentModel ?? "default")_\(prompt)"
        if let cached = responseCache[cacheKey],
           Date().timeIntervalSince(cached.timestamp) < cacheExpirationSeconds {
            return AITaskResult(taskId: task.taskId, status: .completed, output: cached.response)
        }

        do {
            let selectedModel = await ollamaService.selectedModel
            let model = currentModel ?? selectedModel ?? "llama3.2:latest"
            let response = try await ollamaService.generateTextComplete(prompt: prompt, model: model)

            // Cache the response
            if responseCache.count >= maxCacheSize {
                responseCache.removeAll()
            }
            responseCache[cacheKey] = (response: response, timestamp: Date())

            return AITaskResult(taskId: task.taskId, status: .completed, output: response)
        } catch {
            throw error
        }
    }

    public func provideCapabilities() -> [AICapability] {
        return modelFamily.defaultCapabilities
    }

    public func getState() -> AgentState { return state }

    public func initialize(with config: AgentConfiguration) async -> AgentInitResult {
        state = .initializing
        if let modelId = config.modelId {
            do {
                try await ollamaService.selectModel(modelId)
                self.currentModel = modelId
                self.modelFamily = ModelFamily.fromModelName(modelId)
            } catch {
                print("[OllamaAgent] Could not select model '\(modelId)': \(error.localizedDescription)")
            }
        }
        state = .idle
        return .success
    }

    public func shutdown() async -> Result<Void, Error> {
        state = .terminated
        return .success(())
    }

    // MARK: - Model Management

    /// List available models
    public func listModels(forceRefresh: Bool = false) async throws -> [OllamaService.OllamaModel] {
        let models = try await ollamaService.listModels(forceRefresh: forceRefresh)
        self.availableModels = models
        return models
    }

    /// Select a model to use
    public func selectModel(_ modelName: String) async throws {
        try await ollamaService.selectModel(modelName)
        self.currentModel = modelName
        self.modelFamily = ModelFamily.fromModelName(modelName)
    }

    /// Get streaming text generation
    public func streamText(
        prompt: String,
        options: OllamaService.GenerationOptions = .default
    ) async throws -> AsyncThrowingStream<String, Error> {
        let selectedModel = await ollamaService.selectedModel
        let model = currentModel ?? selectedModel ?? "llama3.2:latest"
        return try await ollamaService.generateText(prompt: prompt, model: model, options: options)
    }
}
