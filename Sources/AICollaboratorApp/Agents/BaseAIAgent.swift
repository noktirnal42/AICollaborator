//
//  BaseAIAgent.swift
//  AICollaborator
//
//  Created: 2025-04-10
//

import Foundation
import NaturalLanguage
import SwiftyJSON

/// Base implementation of the AICollaboratorAgent protocol
/// Provides core functionality for AI agents in the system
public actor BaseAIAgent: AICollaboratorAgent {
    // MARK: - Properties
    
    /// Agent unique identifier
    public let agentId: AIAgentExchangeId
    
    /// Agent name
    public let name: String
    
    /// Agent version
    public let version: String
    
    /// Agent description
    public let description: String
    
    /// Supported capabilities
    private let capabilities: [AICapability]
    
    /// Current agent state
    private var state: AgentState = .initializing
    
    /// Agent configuration
    private var configuration: AgentConfiguration
    
    /// Reference to Ollama service if available
    private var ollamaService: OllamaService?
    
    /// Task history cache
    private var taskHistory: [UUID: AITaskResult] = [:]
    
    /// Maximum task history items to keep
    private let maxTaskHistoryItems = 50
    
    /// Logger for agent operations
    private let logger = AgentLogger()
    
    /// Progress monitoring for long-running tasks
    private var progressMonitors: [UUID: TaskProgressMonitor] = [:]
    
    // MARK: - Initialization
    
    /// Initialize a new base AI agent
    /// - Parameters:
    ///   - name: Agent name
    ///   - version: Agent version
    ///   - description: Agent description
    ///   - capabilities: Array of supported capabilities
    ///   - configuration: Initial configuration
    ///   - ollamaService: Optional OllamaService for model access
    public init(
        name: String,
        version: String,
        description: String,
        capabilities: [AICapability],
        configuration: AgentConfiguration = AgentConfiguration(),
        ollamaService: OllamaService? = nil
    ) {
        self.agentId = AIAgentExchangeId()
        self.name = name
        self.version = version
        self.description = description
        self.capabilities = capabilities
        self.configuration = configuration
        self.ollamaService = ollamaService
        
        // Set initial state
        self.state = .idle
        
        logger.info("Agent initialized: \(name) v\(version)")
    }
    
    // MARK: - AICollaboratorAgent Protocol Implementation
    
    /// Process an AI task
    /// - Parameter task: The task to process
    /// - Returns: The result of task processing
    public func processTask(_ task: AITask) async throws -> AITaskResult {
        guard supportsAllCapabilities(task.requiredCapabilities) else {
            let missingCapabilities = task.requiredCapabilities.filter { !capabilities.contains($0) }
            throw AgentError.capabilityNotSupported(missingCapabilities.first ?? .basicCompletion)
        }
        
        // Update state to busy
        updateState(.busy(taskId: task.taskId))
        
        // Create task progress monitor
        let progressMonitor = TaskProgressMonitor(
            taskId: task.taskId,
            startTime: Date(),
            expectedDuration: calculateExpectedDuration(for: task)
        )
        progressMonitors[task.taskId] = progressMonitor
        
        do {
            // Perform pre-processing
            let processedTask = try await preprocessTask(task)
            
            // Process based on capability requirements
            let result: AITaskResult
            
            // Choose processing method based on required capabilities
            if task.requiredCapabilities.contains(.codeGeneration) {
                result = try await processCodeGenerationTask(processedTask)
            } else if task.requiredCapabilities.contains(.textAnalysis) {
                result = try await processTextAnalysisTask(processedTask)
            } else if task.requiredCapabilities.contains(.conversational) {
                result = try await processConversationalTask(processedTask)
            } else {
                // Default processing for basic completion
                result = try await processBasicTask(processedTask)
            }
            
            // Update state back to idle
            updateState(.idle)
            
            // Clean up progress monitor
            progressMonitors.removeValue(forKey: task.taskId)
            
            // Add to task history
            recordTaskResult(result)
            
            return result
        } catch {
            // Update state to error
            updateState(.error(error.localizedDescription))
            
            // Clean up progress monitor
            progressMonitors.removeValue(forKey: task.taskId)
            
            // Convert error to appropriate result
            let errorResult = AITaskResult(
                taskId: task.taskId,
                status: .failed,
                output: error.localizedDescription
            )
            
            // Add to task history
            recordTaskResult(errorResult)
            
            throw error
        }
    }
    
    /// Provide the capabilities supported by this agent
    /// - Returns: Array of supported capabilities
    public func provideCapabilities() -> [AICapability] {
        return capabilities
    }
    
    /// Get the current state of the agent
    /// - Returns: Current agent state
    public func getState() -> AgentState {
        return state
    }
    
    /// Initialize the agent with the provided configuration
    /// - Parameter config: Agent configuration
    /// - Returns: Initialization result
    public func initialize(with config: AgentConfiguration) async -> AgentInitResult {
        updateState(.initializing)
        
        // Update configuration
        self.configuration = config
        
        do {
            // Perform initialization tasks
            
            // Initialize Ollama model if applicable
            if let ollamaService = ollamaService, let modelId = config.modelId {
                let isAvailable = await ollamaService.checkAvailability()
                if isAvailable {
                    try await ollamaService.selectModel(modelId)
                    logger.info("Selected Ollama model: \(modelId)")
                } else {
                    logger.warning("Ollama service unavailable, proceeding without model integration")
                }
            }
            
            // Successful initialization
            updateState(.idle)
            return .success
        } catch {
            // Failed initialization
            updateState(.error(error.localizedDescription))
            return .failure(error.localizedDescription)
        }
    }
    
    /// Gracefully shutdown the agent
    /// - Returns: Success or error result
    public func shutdown() async -> Result<Void, Error> {
        updateState(.shuttingDown)
        
        do {
            // Perform any cleanup operations
            
            // Clear caches
            taskHistory.removeAll()
            progressMonitors.removeAll()
            
            // Successfully shutdown
            updateState(.terminated)
            return .success(())
        } catch {
            updateState(.error(error.localizedDescription))
            return .failure(error)
        }
    }
    
    // MARK: - Task Processing Methods
    
    /// Process a basic task using default capabilities
    /// - Parameter task: The task to process
    /// - Returns: Task result
    private func processBasicTask(_ task: AITask) async throws -> AITaskResult {
        logger.info("Processing basic task: \(task.description)")
        
        // Update progress
        progressMonitors[task.taskId]?.updateProgress(status: "Generating response", progress: 0.2)
        
        // Process using Ollama if available, otherwise use built-in processing
        if let ollamaService = ollamaService, let _ = ollamaService.selectedModel {
            return try await processWithOllama(task, options: GenerationOptions(
                temperature: configuration.temperature,
                topP: 0.9,
                numPredict: 512
            ))
        } else {
            // Use built-in processing
            return try await fallbackProcessing(task)
        }
    }
    
    /// Process a code generation task
    /// - Parameter task: The task to process
    /// - Returns: Task result
    private func processCodeGenerationTask(_ task: AITask) async throws -> AITaskResult {
        logger.info("Processing code generation task: \(task.description)")
        
        // Update progress
        progressMonitors[task.taskId]?.updateProgress(status: "Analyzing code context", progress: 0.1)
        
        // Prepare prompt with code generation specific instructions
        var prompt = task.query
        
        // Check if we need to add code generation instructions
        if !prompt.lowercased().contains("generate code") && !prompt.lowercased().contains("write code") {
            prompt = "Generate code for the following task: \(prompt)"
        }
        
        // Add language preference if available in context
        if let language = task.context["language"] as? String {
            prompt = "Generate \(language) code for: \(task.query)"
        }
        
        progressMonitors[task.taskId]?.updateProgress(status: "Generating code", progress: 0.3)
        
        // Process using Ollama if available
        if let ollamaService = ollamaService, let _ = ollamaService.selectedModel {
            // Use lower temperature for code generation
            let options = GenerationOptions(
                temperature: max(0.1, configuration.temperature - 0.2),  // Lower temperature for code
                topP: 0.95,
                numPredict: 1024  // Larger context for code generation
            )
            
            // Create modified task with enhanced prompt
            var enhancedTask = task
            enhancedTask = AITask(
                description: task.description,
                query: prompt,
                context: task.context,
                requiredCapabilities: task.requiredCapabilities,
                priority: task.priority,
                timeout: task.timeout,
                createdBy: task.createdBy
            )
            
            return try await processWithOllama(enhancedTask, options: options)
        } else {
            // Fall back to built-in processing
            return try await fallbackProcessing(task)
        }
    }
    
    /// Process a text analysis task
    /// - Parameter task: The task to process
    /// - Returns: Task result
    private func processTextAnalysisTask(_ task: AITask) async throws -> AITaskResult {
        logger.info("Processing text analysis task: \(task.description)")
        
        // Update progress
        progressMonitors[task.taskId]?.updateProgress(status: "Analyzing text", progress: 0.2)
        
        // Use NLP for basic analysis if needed
        if let textToAnalyze = task.context["text"] as? String {
            let language = detectLanguage(textToAnalyze)
            let sentiment = analyzeSentiment(textToAnalyze)
            
            // Include analysis results in context
            var updatedContext = task.context
            updatedContext["detectedLanguage"] = language
            updatedContext["sentimentScore"] = sentiment
            
            // Create modified task with analysis results
            var enhancedTask = task
            enhancedTask = AITask(
                description: task.description,
                query: task.query,
                context: updatedContext,
                requiredCapabilities: task.requiredCapabilities,
                priority: task.priority,
                timeout: task.timeout,
                createdBy: task.createdBy
            )
            
            progressMonitors[task.taskId]?.updateProgress(status: "Generating analysis", progress: 0.5)
            
            // Process with enhanced context
            if let ollamaService = ollamaService, let _ = ollamaService.selectedModel {
                return try await processWithOllama(enhancedTask, options: GenerationOptions(
                    temperature: configuration.temperature,
                    topP: 0.9,
                    numPredict: 768
                ))
            } else {
                return try await fallbackProcessing(enhancedTask)
            }
        } else {
            // No specific text to analyze, treat as regular task
            return try await processBasicTask(task)
        }
    }
    
    /// Process a conversational task
    /// - Parameter task: The task to process
    /// - Returns: Task result
    private func processConversationalTask(_ task: AITask) async throws -> AITaskResult {
        logger.info("Processing conversational task: \(task.description)")
        
        // Update progress
        progressMonitors[task.taskId]?.updateProgress(status: "Processing conversation", progress: 0.3)
        
        // Extract conversation history if available
        var conversationHistory: [String] = []
        if let history = task.context["conversationHistory"] as? [String] {
            conversationHistory = history
        }
        
        // Add current query to history
        conversationHistory.append("User: \(task.query)")
        
        // Prepare conversation prompt
        let conversationPrompt: String
        if conversationHistory.count > 1 {
            conversationPrompt = "Continue this conversation:\n\n\(conversationHistory.joined(separator: "\n"))\n\nAssistant:"
        } else {
            conversationPrompt = "Respond to this user query:\n\nUser: \(task.query)\n\nAssistant:"
        }
        
        // Use Ollama for conversational tasks if available
        if let ollamaService = ollamaService, let _ = ollamaService.selectedModel {
            // Create task with conversation prompt
            var conversationalTask = task
            conversationalTask = AITask(
                description: task.description,
                query: conversationPrompt,
                context: task.context,
                requiredCapabilities: task.requiredCapabilities,
                priority: task.priority,
                timeout: task.timeout,
                createdBy: task.createdBy
            )
            
            return try await processWithOllama(conversationalTask, options: GenerationOptions(
                temperature: min(1.0, configuration.temperature + 0.1),  // Slightly higher temperature for conversational
                topP: 0.95,
                numPredict: 1024
            ))
        } else {
            // Use fallback processing
            var conversationalTask = task
            conversationalTask = AITask(
                description: task.description,
                query: conversationPrompt,
                context: task.context,
                requiredCapabilities: task.requiredCapabilities,
                priority: task.priority,
                timeout: task.timeout,
                createdBy: task.createdBy
            )
            
            return try await fallbackProcessing(conversationalTask)
        }
    }
    
    /// Process a task using Ollama service
    /// - Parameters:
    ///   - task: The task to process
    ///   - options: Generation options for Ollama
    /// - Returns: Task result
    private func processWithOllama(_ task: AITask, options: GenerationOptions) async throws -> AITaskResult {
        guard let ollamaService = ollamaService, let _ = ollamaService.selectedModel else {
            throw AgentError.processingError("Ollama service not available")
        }
        
        // Create a response collector
        var responseText = ""
        var lastProgressUpdate = Date()
        let progressUpdateInterval: TimeInterval = 0.5
        
        // Generate text using Ollama
        let stream = try await ollamaService.generateText(prompt: task.query, options: options)
        
        // Process the stream of generated text
        for try await chunk in stream {
            responseText += chunk
            
            // Update progress periodically
            let now = Date()
            if now.timeIntervalSince(lastProgressUpdate) >= progressUpdateInterval {
                let progress = min(0.9, 0.3 + Double(responseText.count) / 1000.0)
                progressMonitors[task.taskId]?.updateProgress(
                    status: "

