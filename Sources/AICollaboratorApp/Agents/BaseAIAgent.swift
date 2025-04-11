//
//  BaseAIAgent.swift
//  AICollaborator
//
//  Created: 2025-04-10
//

import Foundation
import Alamofire
import AsyncAlgorithms

/// Base implementation of the AIAgent protocol.
///
/// `BaseAIAgent` provides a foundation for building custom AI agents by
/// implementing common functionality that most agents will need. Custom
/// agents can inherit from this class and override methods as needed.
@available(macOS 15.0, *)
open class BaseAIAgent: AIAgent {
    
    // MARK: - Properties
    
    /// Configuration for this agent.
    private var agentConfiguration: AIAgentConfiguration
    
    /// Queue for managing concurrent task execution.
    private let taskQueue = TaskQueue()
    
    /// Capabilities supported by this agent.
    private let agentCapabilities: [AICapability]
    
    /// Logger for agent operations.
    internal let logger = Logger(category: "BaseAIAgent")
    
    // MARK: - Initialization
    
    /// Initialize a new base AI agent.
    ///
    /// - Parameters:
    ///   - capabilities: Array of capabilities supported by this agent.
    ///   - configuration: Configuration for this agent.
    public init(
        capabilities: [AICapability],
        configuration: AIAgentConfiguration = AIAgentConfiguration()
    ) {
        self.agentCapabilities = capabilities
        self.agentConfiguration = configuration
    }
    
    // MARK: - AIAgent Protocol Implementation
    
    /// Execute a task within the given context.
    ///
    /// This base implementation handles common pre- and post-processing steps,
    /// and delegates the actual task execution to the `performTask` method,
    /// which subclasses should override.
    ///
    /// - Parameters:
    ///   - task: The task to execute.
    ///   - context: The context in which to execute the task.
    /// - Returns: The result of the task execution.
    /// - Throws: Errors encountered during task execution.
    open func execute(task: AITask, in context: AIContext) async throws -> AITaskResult {
        logger.info("Executing task: \(task.taskId)")
        
        // Check if agent can execute the task
        guard canExecute(task: task) else {
            throw AICollaboratorError.unsupportedOperation
        }
        
        // Prepare for task execution
        guard await prepare(for: task) else {
            throw AICollaboratorError.taskExecutionFailed("Failed to prepare for task execution")
        }
        
        // Track execution time
        let startTime = Date()
        
        do {
            // Execute the task with timeout
            let result = try await withTimeout(seconds: agentConfiguration.timeoutSeconds) {
                try await self.performTask(task: task, in: context)
            }
            
            // Calculate execution duration
            let endTime = Date()
            let executionDuration = endTime.timeIntervalSince(startTime)
            
            // Create the final result with execution metrics
            let finalResult = AITaskResult(
                resultId: result.resultId,
                taskId: task.taskId,
                status: result.status,
                output: result.output,
                error: result.error,
                completedAt: endTime,
                executionDuration: executionDuration,
                resourceUsage: result.resourceUsage,
                metadata: result.metadata
            )
            
            // Clean up after execution
            await cleanup(after: task, result: finalResult)
            
            logger.info("Task completed in \(executionDuration) seconds: \(task.taskId)")
            return finalResult
            
        } catch let error as AICollaboratorError where error == .timeout {
            // Handle timeout
            logger.error("Task timed out: \(task.taskId)")
            
            let timeoutResult = AITaskResult(
                resultId: UUID(),
                taskId: task.taskId,
                status: .timeout,
                error: "Task execution timed out after \(agentConfiguration.timeoutSeconds) seconds",
                completedAt: Date()
            )
            
            await cleanup(after: task, result: timeoutResult)
            return timeoutResult
            
        } catch {
            // Handle other errors
            logger.error("Task failed: \(task.taskId) - \(error.localizedDescription)")
            
            let errorResult = AITaskResult(
                resultId: UUID(),
                taskId: task.taskId,
                status: .failed,
                error: error.localizedDescription,
                completedAt: Date()
            )
            
            await cleanup(after: task, result: errorResult)
            return errorResult
        }
    }
    
    /// Get the agent's capabilities.
    ///
    /// - Returns: Array of capabilities supported by this agent.
    open func capabilities() -> [AICapability] {
        return agentCapabilities
    }
    
    /// Get the agent's configuration.
    ///
    /// - Returns: The agent's configuration.
    open func configuration() -> AIAgentConfiguration {
        return agentConfiguration
    }
    
    /// Update the agent's configuration.
    ///
    /// - Parameter configuration: The new configuration.
    /// - Returns: `true` if the configuration was updated successfully.
    @discardableResult
    open func updateConfiguration(_ configuration: AIAgentConfiguration) -> Bool {
        self.agentConfiguration = configuration
        return true
    }
    
    // MARK: - Methods to Override
    
    /// Perform the actual task execution.
    ///
    /// Subclasses must override this method to implement their specific task execution logic.
    ///
    /// - Parameters:
    ///   - task: The task to execute.
    ///   - context: The context in which to execute the task.
    /// - Returns: The result of the task execution.
    /// - Throws: Errors encountered during task execution.
    open func performTask(task: AITask, in context: AIContext) async throws -> AITaskResult {
        // Default implementation throws an error
        // Subclasses must override this method
        throw AICollaboratorError.unsupportedOperation
    }
    
    // MARK: - Helper Methods
    
    /// Execute a task with a timeout.
    ///
    /// - Parameters:
    ///   - seconds: Timeout duration in seconds.
    ///   - task: The task to execute.
    /// - Returns

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
                    status: "Generating response",
                    progress: progress
                )
                lastProgressUpdate = now
            }
        }
        
        // Post-process the response if needed
        let processedResponse = postprocessResponse(responseText, for: task)
        
        // Create and return the task result
        return AITaskResult(
            taskId: task.taskId,
            status: .completed,
            output: processedResponse,
            completedAt: Date(),
            executionTime: progressMonitors[task.taskId]?.elapsedTime
        )
    }
    
    /// Fallback processing when Ollama is not available
    /// - Parameter task: The task to process
    /// - Returns: Task result
    private func fallbackProcessing(_ task: AITask) async throws -> AITaskResult {
        logger.info("Using fallback processing for task: \(task.description)")
        
        // Update progress
        progressMonitors[task.taskId]?.updateProgress(status: "Preparing response", progress: 0.5)
        
        // Simulate processing time based on task complexity
        let processingTime = calculateProcessingTime(for: task)
        try await Task.sleep(for: .seconds(processingTime))
        
        // Generate a basic response based on the task type
        let response: String
        
        switch true {
        case task.requiredCapabilities.contains(.codeGeneration):
            response = generateFallbackCodeResponse(for: task)
        case task.requiredCapabilities.contains(.textAnalysis):
            response = generateFallbackAnalysisResponse(for: task)
        case task.requiredCapabilities.contains(.conversational):
            response = generateFallbackConversationResponse(for: task)
        default:
            response = """
            I've processed your request: "\(task.description)"
            
            This is a fallback response as the requested AI model is not available.
            For full functionality, please ensure Ollama is running with appropriate models.
            
            Your query: \(task.query)
            """
        }
        
        // Update progress to complete
        progressMonitors[task.taskId]?.updateProgress(status: "Completed", progress: 1.0)
        
        // Return the result
        return AITaskResult(
            taskId: task.taskId,
            status: .completed,
            output: response,
            completedAt: Date(),
            executionTime: progressMonitors[task.taskId]?.elapsedTime
        )
    }
    
    // MARK: - Helper Methods
    
    /// Preprocess a task before execution
    /// - Parameter task: The task to preprocess
    /// - Returns: Preprocessed task
    private func preprocessTask(_ task: AITask) async throws -> AITask {
        logger.debug("Preprocessing task: \(task.taskId)")
        
        // Perform common preprocessing steps
        var processedTask = task
        
        // Example: Add timestamp to context
        var updatedContext = task.context
        updatedContext["preprocessTimestamp"] = Date().timeIntervalSince1970
        
        // Example: Enhance prompt based on capabilities
        var enhancedQuery = task.query
        
        // Add special instructions for code tasks
        if task.requiredCapabilities.contains(.codeGeneration) && 
           !enhancedQuery.lowercased().contains("code") {
            enhancedQuery = "Generate code for: \(enhancedQuery)"
        }
        
        // Create updated task
        processedTask = AITask(
            description: task.description,
            query: enhancedQuery,
            context: updatedContext,
            requiredCapabilities: task.requiredCapabilities,
            priority: task.priority,
            timeout: task.timeout,
            createdBy: task.createdBy
        )
        
        return processedTask
    }
    
    /// Post-process a response after generation
    /// - Parameters:
    ///   - response: Raw response text
    ///   - task: Original task
    /// - Returns: Processed response
    private func postprocessResponse(_ response: String, for task: AITask) -> String {
        // Clean up response if needed
        var processedResponse = response
        
        // Remove any unnecessary prefixes
        if processedResponse.hasPrefix("Assistant: ") {
            processedResponse = String(processedResponse.dropFirst(11))
        }
        
        // Trim whitespace
        processedResponse = processedResponse.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Add task-specific formatting
        if task.requiredCapabilities.contains(.codeGeneration) {
            // Ensure code blocks are properly formatted
            if !processedResponse.contains("```") {
                // Try to detect language
                let language = inferCodeLanguage(from: processedResponse, context: task.context)
                processedResponse = "```\(language)\n\(processedResponse)\n```"
            }
        }
        
        return processedResponse
    }
    
    /// Generate a fallback code response
    /// - Parameter task: The task to generate code for
    /// - Returns: Generated code response
    private func generateFallbackCodeResponse(for task: AITask) -> String {
        // Determine language from context if available
        let language = task.context["language"] as? String ?? "python"
        
        // Generate a simple code example
        switch language.lowercased() {
        case "swift":
            return """
            ```swift
            // Example Swift implementation
            struct ExampleImplementation {
                // Properties
                let name: String
                let value: Int
                
                // Methods
                func process() -> String {
                    return "Processed: \\(name) with value \\(value)"
                }
                
                // Example usage
                static func example() {
                    let example = ExampleImplementation(name: "Test", value: 42)
                    print(example.process())
                }
            }
            ```
            
            This is a fallback implementation. Please provide specific requirements for a more accurate solution.
            """
        case "python":
            return """
            ```python
            # Example Python implementation
            class ExampleImplementation:
                def __init__(self, name, value):
                    self.name = name
                    self.value = value
                    
                def process(self):
                    return f"Processed: {self.name} with value {self.value}"
                
                @staticmethod
                def example():
                    example = ExampleImplementation("Test", 42)
                    print(example.process())
                    
            # Usage
            if __name__ == "__main__":
                ExampleImplementation.example()
            ```
            
            This is a fallback implementation. Please provide specific requirements for a more accurate solution.
            """
        default:
            return """
            ```
            // Example implementation
            function process(name, value) {
                return `Processed: ${name} with value ${value}`;
            }
            
            // Usage
            console.log(process("Test", 42));
            ```
            
            This is a fallback implementation. Please provide specific requirements for a more accurate solution.
            """
        }
    }
    
    /// Generate a fallback analysis response
    /// - Parameter task: The task to generate analysis for
    /// - Returns: Generated analysis response
    private func generateFallbackAnalysisResponse(for task: AITask) -> String {
        // Extract text to analyze if available
        let textToAnalyze = task.context["text"] as? String ?? task.query
        
        // Perform basic analysis
        let language = detectLanguage(textToAnalyze)
        let sentiment = analyzeSentiment(textToAnalyze)
        let wordCount = textToAnalyze.split(separator: " ").count
        
        return """
        ## Text Analysis Results
        
        **Basic Metrics:**
        - Word count: \(wordCount)
        - Detected language: \(language)
        - Sentiment score: \(sentiment) (\(describeSentiment(sentiment)))
        
        **Summary:**
        This is a \(wordCount < 100 ? "short" : "longer") text in \(language) with a generally \(describeSentiment(sentiment).lowercased()) tone.
        
        Note: This is a fallback analysis. For more comprehensive analysis, please ensure an appropriate AI model is available.
        """
    }
    
    /// Generate a fallback conversation response
    /// - Parameter task: The conversational task
    /// - Returns: Generated conversation response
    private func generateFallbackConversationResponse(for task: AITask) -> String {
        // Extract query
        let query = task.query
        
        // Generate a simple response based on detected intent
        if query.lowercased().contains("hello") || query.lowercased().contains("hi") {
            return "Hello! I'm an AI assistant. How can I help you today?"
        } else if query.lowercased().contains("help") {
            return """
            I can help you with various tasks, including:
            - Answering questions
            - Generating code examples
            - Analyzing text
            - Having conversations
            
            What would you like assistance with?
            """
        } else if query.lowercased().contains("thank") {
            return "You're welcome! Is there anything else I can help you with?"
        } else {
            return """
            I've received your message. This is a fallback response since I'm currently operating in limited mode.
            
            For full conversational capabilities, please ensure an appropriate AI model is configured.
            
            How else can I assist you today?
            """
        }
    }
    
    /// Calculate expected duration for a task
    /// - Parameter task: The task to calculate for
    /// - Returns: Expected duration in seconds
    private func calculateExpectedDuration(for task: AITask) -> TimeInterval {
        // Base duration depends on priority
        var baseDuration: TimeInterval
        switch task.priority {
        case .critical:
            baseDuration = 5.0
        case .high:
            baseDuration = 10.0
        case .normal:
            baseDuration = 15.0
        case .low:
            baseDuration = 20.0
        }
        
        // Adjust for task complexity based on required capabilities
        if task.requiredCapabilities.contains(.codeGeneration) {
            baseDuration *= 1.5
        }
        
        if task.requiredCapabilities.contains(.textAnalysis) {
            baseDuration *= 1.2
        }
        
        // Adjust for query length
        let queryLength = task.query.count
        let lengthFactor = 1.0 + Double(min(queryLength, 1000)) / 1000.0
        
        return baseDuration * lengthFactor
    }
    
    /// Calculate processing time for fallback responses
    /// - Parameter task: The task to calculate for
    /// - Returns: Processing time in seconds
    private func calculateProcessingTime(for task: AITask) -> TimeInterval {
        // Simulate varying processing times based on task complexity
        var baseTime: TimeInterval = 1.0
        
        // Adjust for task type
        if task.requiredCapabilities.contains(.codeGeneration) {
            baseTime += 1.5
        } else if task.requiredCapabilities.contains(.textAnalysis) {
            baseTime += 1.0
        }
        
        // Add some randomness
        baseTime += Double.random(in: 0.5...1.5)
        
        return baseTime
    }
    
    /// Infer the programming language from code snippet
    /// - Parameters:
    ///   - code: Code snippet
    ///   - context: Task context
    /// - Returns: Inferred language name
    private func inferCodeLanguage(from code: String, context: [String: Any]) -> String {
        // First check if language is specified in context
        if let language = context["language"] as? String {
            return language
        }
        
        // Basic language detection based on syntax patterns
        if code.contains("func ") && code.contains("let ") && code.contains("var ") {
            return "swift"
        } else if code.contains("def ") && code.contains("import ") && (code.contains("self") || code.contains("class ")){
            return "python"
        } else if code.contains("function ") && code.contains("const ") && code.contains("let ") {
            return "javascript"
        } else if code.contains("public class ") && code.contains("void ") && code.contains("new ") {
            return "java"
        } else if code.contains("#include ") && code.contains("int ") && code.contains("return ") {
        }
        
        // Default to "generic" if we can't detect
        return "generic"
    }
    
    /// Detect the language of a text
    /// - Parameter text: Text to analyze
    /// - Returns: Language name
    private func detectLanguage(_ text: String) -> String {
        // Use NaturalLanguage framework for language detection
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        
        // Get the dominant language
        guard let languageCode = recognizer.dominantLanguage?.rawValue else {
            return "Unknown"
        }
        
        // Convert language code to readable name
        switch languageCode {
        case "en": return "English"
        case "fr": return "French"
        case "es": return "Spanish"
        case "de": return "German"
        case "it": return "Italian"
        case "pt": return "Portuguese"
        case "ru": return "Russian"
        case "zh": return "Chinese"
        case "ja": return "Japanese"
        case "ko": return "Korean"
        case "ar": return "Arabic"
        case "hi": return "Hindi"
        default: return languageCode
        }
    }
    
    /// Analyze sentiment of a text
    /// - Parameter text: Text to analyze
    /// - Returns: Sentiment score (-1.0 to 1.0)
    private func analyzeSentiment(_ text: String) -> Double {
        // This is a simple heuristic-based sentiment analyzer
        // In a real implementation, this would use a more sophisticated model
        
        // Positive words increase score
        let positiveWords = ["good", "great", "excellent", "amazing", "awesome", "fantastic", 
                            "wonderful", "best", "love", "happy", "positive", "beautiful", 
                            "perfect", "like", "enjoy", "nice", "helpful", "improved"]
        
        // Negative words decrease score
        let negativeWords = ["bad", "awful", "terrible", "horrible", "worst", "hate", 
                              "sad", "negative", "ugly", "broken", "dislike", "poor", 
                              "disappointing", "wrong", "failed", "error", "confusing"]
        
        // Intensifiers increase the effect
        let intensifiers = ["very", "extremely", "incredibly", "absolutely", "really", "highly"]
        
        // Negators flip the sentiment
        let negators = ["not", "no", "never", "don't", "doesn't", "cannot", "can't", "isn't", "aren't", "wasn't", "weren't"]
        
        // Convert to lowercase and split into words
        let words = text.lowercased().split(separator: " ").map { String($0) }
        
        var score = 0.0
        var intensityMultiplier = 1.0
        var negationActive = false
        
        for (index, word) in words.enumerated() {
            // Clean the word of punctuation
            let cleanWord = word.trimmingCharacters(in: .punctuationCharacters)
            
            // Check for intensifiers
            if intensifiers.contains(cleanWord) {
                intensityMultiplier = 1.5
                continue
            }
            
            // Check for negators
            if negators.contains(cleanWord) {
                negationActive = true
                continue
            }
            
            // Check for positive words
            if positiveWords.contains(cleanWord) {
                score += 0.1 * intensityMultiplier * (negationActive ? -1 : 1)
            }
            
            // Check for negative words
            if negativeWords.contains(cleanWord) {
                score -= 0.1 * intensityMultiplier * (negationActive ? -1 : 1)
            }
            
            // Reset modifiers after applying them
            intensityMultiplier = 1.0
            
            // Reset negation after a few words
            if negationActive && index > 0 && (index % 3 == 0) {
                negationActive = false
            }
        }
        
        // Clamp score to range -1.0 to 1.0
        return max(-1.0, min(1.0, score))
    }
    
    /// Describe sentiment in words
    /// - Parameter score: Sentiment score
    /// - Returns: Description
    private func describeSentiment(_ score: Double) -> String {
        if score >= 0.5 {
            return "Very Positive"
        } else if score >= 0.2 {
            return "Positive"
        } else if score > -0.2 {
            return "Neutral"
        } else if score > -0.5 {
            return "Negative"
        } else {
            return "Very Negative"
        }
    }
    
    /// Record a task result in history
    /// - Parameter result: The result to record
    private func recordTaskResult(_ result: AITaskResult) {
        // Add to history
        taskHistory[result.taskId] = result
        
        // Prune history if needed
        if taskHistory.count > maxTaskHistoryItems {
            // Remove oldest items
            let sortedKeys = taskHistory.keys.sorted { lhs, rhs in
                guard let lhsResult = taskHistory[lhs], let rhsResult = taskHistory[rhs] else {
                    return false
                }
                return lhsResult.completedAt < rhsResult.completedAt
            }
            
            // Remove oldest entries
            let keysToRemove = sortedKeys.prefix(taskHistory.count - maxTaskHistoryItems)
            for key in keysToRemove {
                taskHistory.removeValue(forKey: key)
            }
        }
    }
    
    /// Update the agent state
    /// - Parameter newState: New state to set
    private func updateState(_ newState: AgentState) {
        state = newState
        logger.info("Agent \(name) state changed to: \(stateDescription(newState))")
    }
    
    /// Get a readable description of an agent state
    /// - Parameter state: The state to describe
    /// - Returns: Human-readable description
    private func stateDescription(_ state: AgentState) -> String {
        switch state {
        case .initializing:
            return "Initializing"
        case .idle:
            return "Idle"
        case .busy(let taskId):
            return "Busy (Task: \(taskId))"
        case .paused:
            return "Paused"
        case .shuttingDown:
            return "Shutting Down"
        case .terminated:
            return "Terminated"
        case .error(let message):
            return "Error: \(message)"
        }
    }
    
    /// Check if the agent supports all required capabilities
    /// - Parameter requiredCapabilities: Set of capabilities to check
    /// - Returns: True if all capabilities are supported
    private func supportsAllCapabilities(_ requiredCapabilities: Set<AICapability>) -> Bool {
        return requiredCapabilities.isSubset(of: Set(capabilities))
    }
}

// MARK: - Utility Types

/// Monitors progress of a long-running task
fileprivate class TaskProgressMonitor {
    /// Task ID
    let taskId: UUID
    
    /// When the task started
    let startTime: Date
    
    /// Current status message
    private(set) var status: String = "Starting"
    
    /// Current progress (0.0 - 1.0)
    private(set) var progress: Double = 0.0
    
    /// Expected duration for the task
    let expectedDuration: TimeInterval
    
    /// Latest update time
    private(set) var lastUpdateTime: Date
    
    /// Elapsed time since task start
    var elapsedTime: TimeInterval {
        return Date().timeIntervalSince(startTime)
    }
    
    /// Estimated time remaining
    var estimatedTimeRemaining: TimeInterval {
        if progress >= 0.99 {
            return 0
        }
        
        let timeElapsed = elapsedTime
        if progress > 0.05 {
            // Calculate based on current progress
            return timeElapsed * (1.0 - progress) / progress
        } else {
            // Fall back to expected duration if progress is too small
            return max(0, expectedDuration - timeElapsed)
        }
    }
    
    /// Initialize a new task progress monitor
    /// - Parameters:
    ///   - taskId: Task ID to monitor
    ///   - startTime: When the task started
    ///   - expectedDuration: Expected duration for the task
    init(taskId: UUID, startTime: Date, expectedDuration: TimeInterval) {
        self.taskId = taskId
        self.startTime = startTime
        self.expectedDuration = expectedDuration
        self.lastUpdateTime = startTime
    }
    
    /// Update the progress
    /// - Parameters:
    ///   - status: New status message
    ///   - progress: New progress value (0.0 - 1.0)
    func updateProgress(status: String, progress: Double) {
        self.status = status
        self.progress = max(0.0, min(1.0, progress))
        self.lastUpdateTime = Date()
    }
}

/// Logger for agent operations
fileprivate struct AgentLogger {
    /// Log a debug message
    /// - Parameter message: Message to log
    func debug(_ message: String) {
        log(message, level: .debug)
    }
    
    /// Log an info message
    /// - Parameter message: Message to log
    func info(_ message: String) {
        log(message, level: .info)
    }
    
    /// Log a warning message
    /// - Parameter message: Message to log
    func warning(_ message: String) {
        log(message, level: .warning)
    }
    
    /// Log an error message
    /// - Parameter message: Message to log
    func error(_ message: String) {
        log(message, level: .error)
    }
    
    /// Log a message with a specific level
    /// - Parameters:
    ///   - message: Message to log
    ///   - level: Log level
    private func log(_ message: String, level: LogLevel) {
        let prefix: String
        switch level {
        case .debug:
            prefix = "[DEBUG]"
        case .info:
            prefix = "[INFO]"
        case .warning:
            prefix = "[WARNING]"
        case .error:
            prefix = "[ERROR]"
        }
        
        let timestamp = ISO8601DateFormatter().string(from: Date())
        print("\(timestamp) \(prefix) [Agent] \(message)")
    }
    
    /// Log levels
    enum LogLevel {
        case debug
        case info
        case warning
        case error
    }
}
