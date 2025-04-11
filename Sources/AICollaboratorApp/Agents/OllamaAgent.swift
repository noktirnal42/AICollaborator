//
//  OllamaAgent.swift
//  AICollaborator
//
//  Created: 2025-04-10
//

import Foundation
import SwiftyJSON

/// Specialized agent for Ollama model interactions
public actor OllamaAgent: BaseAIAgent {
    // MARK: - Types
    
    /// Ollama model family types
    public enum ModelFamily {
        case llama
        case mistral
        case phi
        case gemma
        case mixtral
        case codellama
        case stable
        case other(String)
        
        /// Map to capabilities
        var defaultCapabilities: [AICapability] {
            switch self {
            case .llama, .mistral, .gemma, .mixtral:
                return [
                    .basicCompletion,
                    .textAnalysis,
                    .conversational,
                    .contextRetrieval,
                    .dataSummarization
                ]
            case .codellama:
                return [
                    .basicCompletion,
                    .codeGeneration,
                    .codeCompletion,
                    .textAnalysis
                ]
            case .phi:
                return [
                    .basicCompletion,
                    .textAnalysis,
                    .codeGeneration
                ]
            case .stable:
                return [
                    .imageGeneration,
                    .multimodal
                ]
            case .other:
                return [.basicCompletion]
            }
        }
        
        /// Get optimal temperature
        var recommendedTemperature: Double {
            switch self {
            case .codellama:
                return 0.3  // Lower temperature for code
            case .llama, .mistral, .phi:
                return 0.7  // Balanced for general use
            case .gemma:
                return 0.8  // Slightly more creative
            case .mixtral:
                return 0.75
            case .stable:
                return 0.8
            case .other:
                return 0.7
            }
        }
        
        /// Parse from model name
        static func fromModelName(_ name: String) -> ModelFamily {
            let lowercaseName = name.lowercased()
            
            if lowercaseName.contains("llama") {
                if lowercaseName.contains("code") {
                    return .codellama
                } else {
                    return .llama
                }
            } else if lowercaseName.contains("mistral") {
                return .mistral
            } else if lowercaseName.contains("phi") {
                return .phi
            } else if lowercaseName.contains("gemma") {
                return .gemma
            } else if lowercaseName.contains("mixtral") {
                return .mixtral
            } else if lowercaseName.contains("stable") {
                return .stable
            } else {
                return .other(name)
            }
        }
    }
    
    // MARK: - Properties
    
    /// Direct access to the Ollama service
    private let ollamaService: OllamaService
    
    /// Available models (cached)
    private var availableModels: [OllamaService.OllamaModel] = []
    
    /// Currently selected model
    private var currentModel: String?
    
    /// Model family 
    private var modelFamily: ModelFamily
    
    /// Cache for task execution
    private var responseCache: [String: (response: String, timestamp: Date)] = [:]
    
    /// Maximum cache size
    private let maxCacheSize = 50
    
    /// Cache expiration time (10 minutes)
    private let cacheExpirationSeconds: TimeInterval = 600
    
    // MARK: - Initialization
    
    /// Initialize the Ollama agent
    /// - Parameters:
    ///   - ollamaService: Ollama service instance
    ///   - initialModel: Initial model to use
    ///   - configuration: Agent configuration
    public init(
        ollamaService: OllamaService,
        initialModel: String? = nil,
        configuration: AgentConfiguration = AgentConfiguration()
    ) {
        self.ollamaService = ollamaService
        
        // Determine model family or use default
        self.modelFamily = initialModel.map { ModelFamily.fromModelName($0) } ?? .llama
        
        // Set current model
        self.currentModel = initialModel
        
        // Derive capabilities from model family
        let capabilities = modelFamily.defaultCapabilities
        
        // Create base configuration with optimized parameters
        var optimizedConfig = configuration
        if optimizedConfig.modelId == nil {
            optimizedConfig.modelId = initialModel
        }
        
        // Use recommended temperature if not specified
        if optimizedConfig.temperature == 0.7 { // default value
            optimizedConfig.temperature = modelFamily.recommendedTemperature
        }
        
        // Initialize base agent with optimized configuration
        super.init(
            name: "OllamaAgent",
            version: "1.0",
            description: "Specialized agent for Ollama model interactions",
            capabilities: capabilities,
            configuration: optimizedConfig,
            ollamaService: ollamaService
        )
    }
    
    // MARK: - Model Management
    
    /// List available models
    /// - Parameter forceRefresh: Whether to force refresh the model list
    /// - Returns: Array of available models
    public func listModels(forceRefresh: Bool = false) async throws -> [OllamaService.OllamaModel] {
        // Get models from service
        let models = try await ollamaService.listModels(forceRefresh: forceRefresh)
        
        // Cache locally
        self.availableModels = models
        
        return models
    }
    
    /// Select a model to use
    /// - Parameter modelName: Name of the model to select
    /// - Returns: Success or failure
    public func selectModel(_ modelName: String) async throws {
        // Check if model is available
        let models = try await listModels()
        guard models.contains(where: { $0.name == modelName }) else {
            throw OllamaAgentError.modelNotFound(modelName)
        }
        
        // Select in the service
        try await ollamaService.selectModel(modelName)
        
        // Update current model
        self.currentModel = modelName
        
        // Update model family
        self.modelFamily = ModelFamily.fromModelName(modelName)
        
        // Update configuration
        var newConfig = configuration
        newConfig.modelId = modelName
        newConfig.temperature = modelFamily.recommendedTemperature
        
        // Initialize with new configuration
        _ = await initialize(with: newConfig)
    }
    
    /// Pull a new model
    /// - Parameter modelName: Name of the model to pull
    /// - Returns: Progress updates stream
    public func pullModel(_ modelName: String) async throws -> AsyncThrowingStream<PullProgress, Error> {
        // Delegate to service
        let progressStream = try await ollamaService.pullModel(modelName: modelName)
        
        // Convert to our progress type
        return AsyncThrowingStream<PullProgress, Error> { continuation in
            Task {
                do {
                    for try await progress in progressStream {
                        // Convert OllamaService.PullProgress to our PullProgress
                        let agentProgress = PullProgress(
                            modelName: modelName,
                            status: progress.status,
                            progress: progress.progress,
                            downloadedMB: Double(progress.downloaded) / 1_048_576.0,
                            totalMB: Double(progress.total) / 1_048_576.0
                        )
                        
                        continuation.yield(agentProgress)
                        
                        if progress.completed {
                            // Refresh model list when complete
                            _ = try? await listModels(forceRefresh: true)
                            continuation.finish()
                        }
                    }
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Overridden Methods
    
    /// Process an AI task
    /// - Parameter task: The task to process
    /// - Returns: Task result
    public override func processTask(_ task: AITask) async throws -> AITaskResult {
        // Check if we have a valid model selected
        guard currentModel != nil else {
            throw OllamaAgentError.noModelSelected
        }
        
        // Check cache for identical tasks
        let cacheKey = generateCacheKey(for: task)
        if let cached = responseCache[cacheKey], 
           Date().timeIntervalSince(cached.timestamp) < cacheExpirationSeconds {
            // Log cache hit
            logger.info("Cache hit for task: \(task.taskId)")
            
            // Create result from cached response
            return AITaskResult(
                taskId: task.taskId,
                status: .completed,
                output: cached.response,
                completedAt: Date(),
                executionTime: 0.01 // Very fast as it's cached
            )
        }
        
        // Apply Ollama-specific optimizations before processing
        let optimizedTask = optimizeTaskForOllama(task)
        
        // Use the base implementation for processing
        let result = try await super.processTask(optimizedTask)
        
        // Cache the result if successful
        if result.status == .completed {
            cacheResponse(result.output as? String ?? "", for: cacheKey)
        }
        
        return result
    }
    
    /// Initialize the agent with configuration
    /// - Parameter config: Configuration to use
    /// - Returns: Initialization result
    public override func initialize(with config: AgentConfiguration) async -> AgentInitResult {
        // Update the model ID from configuration if provided
        if let modelId = config.modelId, modelId != currentModel {
            do {
                try await selectModel(modelId)
            } catch {
                return .failure("Failed to select model: \(error.localizedDescription)")
            }
        }
        
        // Call base implementation
        return await super.initialize(with: config)
    }
    
    // MARK: - Helper Methods
    
    /// Generate a cache key for a task
    /// - Parameter task: The task to generate key for
    /// - Returns: Cache key string
    private func generateCacheKey(for task: AITask) -> String {
        // Combine model name, query, and required capabilities for uniqueness
        let model = currentModel ?? "default"
        let capabilities = task.requiredCapabilities.map { $0.rawValue }.sorted().joined(separator: ",")
        
        return "\(model)|\(capabilities)|\(task.query)"
    }
    
    /// Cache a response
    /// - Parameters:
    ///   - response: Response to cache
    ///   - key: Cache key
    private func cacheResponse(_ response: String, for key: String) {
        // Add to cache
        responseCache[key] = (response: response, timestamp: Date())
        
        // Prune cache if needed
        if responseCache.count > maxCacheSize {
            // Remove oldest entries
            let sortedKeys = responseCache.keys.sorted { lhs, rhs in
                return responseCache[lhs]!.timestamp < responseCache[rhs]!.timestamp
            }
            
            // Remove oldest entries
            let keysToRemove = sortedKeys.prefix(responseCache.count - maxCacheSize)
            for key in keysToRemove {
                responseCache.removeValue(forKey: key)
            }
        }
    }
    
    /// Optimize a task for Ollama processing
    /// - Parameter task: Original task
    /// - Returns: Optimized task
    private func optimizeTaskForOllama(_ task: AITask) -> AITask {
        var updatedContext = task.context
        
        // Add model-specific context
        updatedContext["model"] = currentModel
        updatedContext["modelFamily"] = String(describing: modelFamily)
        
        // Generate model-specific prompt enhancements
        let enhancedQuery: String
        
        switch modelFamily {
        case .codellama:
            // For code generation, add specific prompting
            if task.requiredCapabilities.contains(.codeGeneration) {
                enhancedQuery = optimizeCodePrompt(task.query, context: updatedContext)
            } else {
                enhancedQuery = task.query
            }
            
        case .llama, .mistral, .phi, .gemma, .mixtral:
            // For general models, add general enhancements
            enhancedQuery = optimizeGeneralPrompt(task.query, context: updatedContext)
            
        default:
            enhancedQuery = task.query
        }
        
        // Create optimized task
        return AITask(
            description: task.description,
            query: enhancedQuery,
            context: updatedContext,
            requiredCapabilities: task.requiredCapabilities,
            priority: task.priority,
            timeout: task.timeout,
            createdBy: task.createdBy
        )
    }
    
    /// Optimize a code generation prompt
    /// - Parameters:
    ///   - query: Original query
    ///   - context: Task context
    /// - Returns: Optimized query
    private func optimizeCodePrompt(_ query: String, context: [String: Any]) -> String {
        // Extract language preference if available
        let language = context["language"] as? String
        
        // If we're already explicitly asking for code, don't modify too much
        if query.lowercased().contains("code") {
            if let language = language {
                return "Generate \(language) code for the following task:\n\n\(query)\n\nProvide a complete implementation with comments."
            } else {
                return "Generate code for the following task:\n\n\(query)\n\nProvide a complete implementation with comments."
            }
        } else {
            // For queries that don't explicitly mention code
            if let language = language {
                return "Write \(language) code to solve the following problem:\n\n\(query)\n\nInclude comments and example usage."
            } else {
                return "Write code to solve the following problem:\n\n\(query)\n\nInclude comments and example usage."
            }
        }
    }
    
    /// Optimize a general prompt
    /// - Parameters:
    ///   - query: Original query
    ///   - context: Task context
    /// - Returns: Optimized query
    private func optimizeGeneralPrompt(_ query: String, context: [String: Any]) -> String {
        // Check for conversation history
        if let history = context["conversationHistory"] as? [String] {
            // If we have conversation history, format as chat
            return formatChatPrompt(query, history: history)
        }
        
        // Simple enhancement for analytical tasks
        if query.lowercased().contains("analyze") || query.lowercased().contains("summarize") {
            return "Analyze the following and provide a detailed response:\n\n\(query)"
        }
        
        // Default enhancement
        return query
    }
    
    /// Format a prompt as a chat conversation
    /// - Parameters:
    ///   - query: Current user query
    ///   - history: Conversation history
    /// - Returns: Formatted chat prompt
    private func formatChatPrompt(_ query: String, history: [String]) -> String {
        var formattedHistory = ""
        
        for (index, message) in history.enumerated() {
            let role = index % 2 == 0 ? "User" : "Assistant"
            formattedHistory += "\(role): \(message)\n\n"
        }
        
        return "\(formattedHistory)User: \(query)\n\nAssistant:"
    }
}

// MARK: - Supporting Types

/// Progress information during model pull operations
public struct PullProgress: Equatable {
    /// Name of the model being pulled
    public let modelName: String
    
    /// Current status message
    public let status: String
    
    /// Progress percentage (0.0 to 1.0)
    public let progress: Double
    
    /// Downloaded data in megabytes
    public let downloadedMB: Double
    
    /// Total size in megabytes
    public let totalMB: Double
    
    /// Whether pull is complete
    public var isComplete: Bool {
        return progress >= 1.0
    }
    
    /// Formatted progress string
    public var formattedProgress: String {
        let downloadedFormatted = String(format: "%.1f", downloadedMB)
        let totalFormatted = String(format: "%.1f", totalMB)
        let percentFormatted = String(format: "%.1f", progress * 100.0)
        
        return "\(downloadedFormatted) MB / \(totalFormatted) MB (\(percentFormatted)%)"
    }
}

/// Errors specific to Ollama agent
public enum OllamaAgentError: Error, LocalizedError {
    /// No model is selected
    case noModelSelected
    
    /// Requested model was not found
    case modelNotFound(String)
    
    /// Model initialization failed
    case modelInitializationFailed(String)
    
    /// Server error
    case serverError(String)
    
    /// Rate limit exceeded
    case rateLimitExceeded
    
    /// Prompt too long
    case promptTooLong
    
    /// Context window overflow
    case contextOverflow
    
    /// Generation interrupted
    case generationInterrupted
    
    /// Localized error descriptions
    public var errorDescription: String? {
        switch self {
        case .noModelSelected:
            return "No Ollama model selected. Please select a model using selectModel() before processing tasks."
        case .modelNotFound(let model):
            return "Ollama model '\(model)' not found. Please check available models with listModels()."
        case .modelInitializationFailed(let reason):
            return "Failed to initialize Ollama model: \(reason)"
        case .serverError(let message):
            return "Ollama server error: \(message)"
        case .rateLimitExceeded:
            return "Ollama rate limit exceeded. Please reduce request frequency."
        case .promptTooLong:
            return "The provided prompt is too long for the selected model."
        case .contextOverflow:
            return "Context window exceeded for the selected model."
        case .generationInterrupted:
            return "Text generation was interrupted."
        }
    }
}

extension OllamaAgent {
    // MARK: - Additional Utility Methods
    
    /// Get information about a specific model
    /// - Parameter modelName: Name of the model
    /// - Returns: Model information if found
    public func getModelInfo(_ modelName: String) async throws -> OllamaService.OllamaModel? {
        // Refresh model list
        let models = try await listModels()
        
        // Find the specific model
        return models.first(where: { $0.name == modelName })
    }
    
    /// Check if a model requires additional memory
    /// - Parameter modelName: Name of the model to check
    /// - Returns: Memory requirements estimate in GB
    public func estimateModelMemoryRequirements(_ modelName: String) async -> Double {
        do {
            if let model = try await getModelInfo(modelName) {
                // Size in GB
                let sizeGB = Double(model.size) / 1_073_741_824.0
                
                // Models typically need 2x their file size in RAM
                return sizeGB * 2.0
            }
        } catch {
            // If we can't get info, use heuristics based on name
            let family = ModelFamily.fromModelName(modelName)
            
            switch family {
            case .llama:
                if modelName.contains("70") {
                    return 16.0 // 70B models need ~16GB
                } else if modelName.contains("13") {
                    return 8.0 // 13B models need ~8GB
                } else {
                    return 4.0 // 7B models need ~4GB
                }
            case .mixtral:
                return 12.0 // Mixtral models need ~12GB
            case .codellama:
                return 8.0 // CodeLlama models typically need ~8GB
            default:
                return 4.0 // Default estimate
            }
        }
        
        return 4.0 // Default fallback
    }
    
    /// Check if current system can run a specific model
    /// - Parameter modelName: Name of the model to check
    /// - Returns: Viability assessment result
    public func checkModelViability(_ modelName: String) async -> (viable: Bool, reason: String?) {
        // Get memory requirements
        let requiredMemoryGB = await estimateModelMemoryRequirements(modelName)
        
        // Get system memory (this is simplified, real implementation would use actual system calls)
        let availableMemoryGB = 16.0 // Example value, should be determined at runtime
        
        if requiredMemoryGB > availableMemoryGB {
            return (false, "Model requires approximately \(String(format: "%.1f", requiredMemoryGB)) GB of RAM, but only \(String(format: "%.1f", availableMemoryGB)) GB is available")
        }
        
        return (true, nil)
    }
    
    /// Provides detailed description of a model's capabilities
    /// - Parameter modelName: Name of the model
    /// - Returns: Capabilities description
    public func describeModelCapabilities(_ modelName: String) -> String {
        let family = ModelFamily.fromModelName(modelName)
        
        switch family {
        case .llama:
            return """
            Llama models excel at:
            - General text generation and completion
            - Conversational interactions
            - Basic reasoning tasks
            - Document analysis
            
            Suitable for most general-purpose tasks.
            """
        case .codellama:
            return """
            CodeLlama models excel at:
            - Code generation
            - Code completion
            - Code analysis and explanation
            - Technical documentation
            
            Optimized for programming-related tasks.
            """
        case .mistral:
            return """
            Mistral models excel at:
            - Efficient text generation
            - Instruction following
            - Reasoning tasks
            
            Good balance of performance and resource requirements.
            """
        case .gemma:
            return """
            Gemma models excel at:
            - Efficient text generation
            - Instruction following
            - Creative writing
            
            Lightweight and efficient for general-purpose use.
            """
        case .phi:
            return """
            Phi models excel at:
            - Efficient performance on smaller hardware
            - Basic text and code tasks
            - Lightweight applications
            
            Designed for efficiency over raw performance.
            """
        case .mixtral:
            return """
            Mixtral models excel at:
            - Multi-domain expertise
            - Complex reasoning
            - Diverse task handling
            
            Uses mixture-of-experts architecture for improved capabilities.
            """
        case .stable:
            return """
            Stable models excel at:
            - Image generation
            - Visual content creation
            - Multi-modal tasks
            
            Specialized for visual content generation.
            """
        case .other:
            return "Custom or specialized model. Capabilities depend on specific training and architecture."
        }
    }
}
