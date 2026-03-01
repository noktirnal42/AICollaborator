//
//  BaseAIAgent.swift
//  AICollaborator
//
//  Created: 2025-04-10
//

import Foundation

// MARK: - Task Progress Monitor

/// Tracks progress of a running task.
public struct TaskProgressMonitor: Sendable {
    public let taskId: UUID
    public let startTime: Date
    public let expectedDuration: TimeInterval

    private var _progress: Double = 0.0
    private var _status: String = "Pending"

    public var progress: Double { _progress }
    public var status: String { _status }
    public var elapsedTime: TimeInterval { Date().timeIntervalSince(startTime) }

    public init(taskId: UUID, startTime: Date = Date(), expectedDuration: TimeInterval = 30.0) {
        self.taskId = taskId
        self.startTime = startTime
        self.expectedDuration = expectedDuration
    }

    public mutating func updateProgress(status: String, progress: Double) {
        self._status = status
        self._progress = min(1.0, max(0.0, progress))
    }
}

// MARK: - Agent Logger

/// Logging utility for agents.
struct AgentLogger: Sendable {
    let category: String

    init(category: String = "Agent") {
        self.category = category
    }

    func debug(_ message: String) {
        print("[\(category)] DEBUG: \(message)")
    }

    func info(_ message: String) {
        print("[\(category)] INFO: \(message)")
    }

    func warning(_ message: String) {
        print("[\(category)] WARNING: \(message)")
    }

    func error(_ message: String) {
        print("[\(category)] ERROR: \(message)")
    }
}

// MARK: - Base AI Agent Actor

/// Base actor implementation of the AICollaboratorAgent protocol.
/// Provides core functionality for AI agents in the system.
public actor BaseAIAgent: @preconcurrency AICollaboratorAgent {

    // MARK: - Properties

    /// Agent unique identifier
    public let agentId: AIAgentExchangeId

    /// Agent name
    public let name: String

    /// Agent version
    public let version: String

    /// Agent description
    public let agentDescription: String

    /// Supported capabilities
    private let agentCapabilities: [AICapability]

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
    private let logger = AgentLogger(category: "BaseAIAgent")

    /// Progress monitoring for long-running tasks
    private var progressMonitors: [UUID: TaskProgressMonitor] = [:]

    // MARK: - Initialization

    /// Initialize a new base AI agent.
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
        self.agentDescription = description
        self.agentCapabilities = capabilities
        self.configuration = configuration
        self.ollamaService = ollamaService
        self.state = .idle
    }

    // MARK: - AICollaboratorAgent Protocol Implementation

    /// Process an AI task.
    public func processTask(_ task: AITask) async throws -> AITaskResult {
        guard supportsAllCapabilities(task.requiredCapabilities) else {
            let missingCapabilities = task.requiredCapabilities.filter { !agentCapabilities.contains($0) }
            throw AgentError.capabilityNotSupported(missingCapabilities.first ?? .basicCompletion)
        }

        state = .busy(taskId: task.taskId)

        var progressMonitor = TaskProgressMonitor(
            taskId: task.taskId,
            expectedDuration: calculateExpectedDuration(for: task)
        )
        progressMonitors[task.taskId] = progressMonitor

        do {
            let processedTask = try await preprocessTask(task)
            let result: AITaskResult

            if task.requiredCapabilities.contains(.codeGeneration) {
                result = try await processCodeGenerationTask(processedTask)
            } else if task.requiredCapabilities.contains(.textAnalysis) {
                result = try await processTextAnalysisTask(processedTask)
            } else if task.requiredCapabilities.contains(.conversational) {
                result = try await processConversationalTask(processedTask)
            } else {
                result = try await processBasicTask(processedTask)
            }

            state = .idle
            progressMonitors.removeValue(forKey: task.taskId)
            recordTaskResult(result)
            return result
        } catch {
            state = .error(error.localizedDescription)
            progressMonitors.removeValue(forKey: task.taskId)

            let errorResult = AITaskResult(
                taskId: task.taskId,
                status: .failed,
                output: error.localizedDescription
            )
            recordTaskResult(errorResult)
            throw error
        }
    }

    /// Provide the capabilities supported by this agent.
    public func provideCapabilities() -> [AICapability] {
        return agentCapabilities
    }

    /// Get the current state of the agent.
    public func getState() -> AgentState {
        return state
    }

    /// Initialize the agent with the provided configuration.
    public func initialize(with config: AgentConfiguration) async -> AgentInitResult {
        state = .initializing
        self.configuration = config

        do {
            if let ollamaService = ollamaService, let modelId = config.modelId {
                let isAvailable = await ollamaService.checkAvailability()
                if isAvailable {
                    try await ollamaService.selectModel(modelId)
                    logger.info("Selected Ollama model: \(modelId)")
                } else {
                    logger.warning("Ollama service unavailable, proceeding without model integration")
                }
            }

            state = .idle
            return .success
        } catch {
            state = .error(error.localizedDescription)
            return .failure(error.localizedDescription)
        }
    }

    /// Gracefully shutdown the agent.
    public func shutdown() async -> Result<Void, Error> {
        state = .shuttingDown
        taskHistory.removeAll()
        progressMonitors.removeAll()
        state = .terminated
        return .success(())
    }

    // MARK: - Task Processing Methods

    private func processBasicTask(_ task: AITask) async throws -> AITaskResult {
        logger.info("Processing basic task: \(task.description)")

        let selectedModel = await ollamaService?.selectedModel
        if let ollamaService = ollamaService, selectedModel != nil {
            return try await processWithOllama(task, options: OllamaService.GenerationOptions(
                temperature: configuration.temperature,
                topP: 0.9,
                numPredict: 512
            ), service: ollamaService)
        } else {
            return try await fallbackProcessing(task)
        }
    }

    private func processCodeGenerationTask(_ task: AITask) async throws -> AITaskResult {
        logger.info("Processing code generation task: \(task.description)")

        var prompt = task.query
        if !prompt.lowercased().contains("generate code") && !prompt.lowercased().contains("write code") {
            prompt = "Generate code for the following task: \(prompt)"
        }

        if let language = task.parameters?["language"] {
            prompt = "Generate \(language) code for: \(task.query)"
        }

        let selectedModel = await ollamaService?.selectedModel
        if let ollamaService = ollamaService, selectedModel != nil {
            let options = OllamaService.GenerationOptions(
                temperature: max(0.1, configuration.temperature - 0.2),
                topP: 0.95,
                numPredict: 1024
            )
            let enhancedTask = AITask(
                taskId: task.taskId,
                description: task.description,
                query: prompt,
                input: task.input,
                requiredCapabilities: task.requiredCapabilities,
                priority: task.priority,
                parameters: task.parameters,
                timeoutSeconds: task.timeoutSeconds
            )
            return try await processWithOllama(enhancedTask, options: options, service: ollamaService)
        } else {
            return try await fallbackProcessing(task)
        }
    }

    private func processTextAnalysisTask(_ task: AITask) async throws -> AITaskResult {
        logger.info("Processing text analysis task: \(task.description)")

        var textToAnalyze: String
        if case .text(let text) = task.input {
            textToAnalyze = text
        } else {
            textToAnalyze = task.query
        }

        let language = detectLanguage(textToAnalyze)
        let sentiment = analyzeSentiment(textToAnalyze)

        var params = task.parameters ?? [:]
        params["detectedLanguage"] = language
        params["sentimentScore"] = String(sentiment)

        let selectedModel = await ollamaService?.selectedModel
        if let ollamaService = ollamaService, selectedModel != nil {
            return try await processWithOllama(task, options: OllamaService.GenerationOptions(
                temperature: configuration.temperature,
                topP: 0.9,
                numPredict: 768
            ), service: ollamaService)
        } else {
            return try await fallbackProcessing(task)
        }
    }

    private func processConversationalTask(_ task: AITask) async throws -> AITaskResult {
        logger.info("Processing conversational task: \(task.description)")

        let conversationPrompt = "Respond to this user query:\n\nUser: \(task.query)\n\nAssistant:"

        let selectedModel = await ollamaService?.selectedModel
        if let ollamaService = ollamaService, selectedModel != nil {
            let conversationalTask = AITask(
                taskId: task.taskId,
                description: task.description,
                query: conversationPrompt,
                input: task.input,
                requiredCapabilities: task.requiredCapabilities,
                priority: task.priority,
                parameters: task.parameters,
                timeoutSeconds: task.timeoutSeconds
            )
            return try await processWithOllama(conversationalTask, options: OllamaService.GenerationOptions(
                temperature: min(1.0, configuration.temperature + 0.1),
                topP: 0.95,
                numPredict: 1024
            ), service: ollamaService)
        } else {
            return try await fallbackProcessing(task)
        }
    }

    private func processWithOllama(
        _ task: AITask,
        options: OllamaService.GenerationOptions,
        service: OllamaService
    ) async throws -> AITaskResult {
        var responseText = ""
        let stream = try await service.generateText(prompt: task.query, options: options)

        for try await chunk in stream {
            responseText += chunk
        }

        let processedResponse = postprocessResponse(responseText, for: task)
        return AITaskResult(
            taskId: task.taskId,
            status: .completed,
            output: processedResponse,
            completedAt: Date(),
            executionTime: progressMonitors[task.taskId]?.elapsedTime
        )
    }

    private func fallbackProcessing(_ task: AITask) async throws -> AITaskResult {
        logger.info("Using fallback processing for task: \(task.description)")

        let processingTime = calculateProcessingTime(for: task)
        try await Task.sleep(for: .seconds(processingTime))

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

        return AITaskResult(
            taskId: task.taskId,
            status: .completed,
            output: response,
            completedAt: Date(),
            executionTime: progressMonitors[task.taskId]?.elapsedTime
        )
    }

    // MARK: - Helper Methods

    private func preprocessTask(_ task: AITask) async throws -> AITask {
        var enhancedQuery = task.query
        if task.requiredCapabilities.contains(.codeGeneration) &&
           !enhancedQuery.lowercased().contains("code") {
            enhancedQuery = "Generate code for: \(enhancedQuery)"
        }

        return AITask(
            taskId: task.taskId,
            description: task.description,
            query: enhancedQuery,
            input: task.input,
            requiredCapabilities: task.requiredCapabilities,
            priority: task.priority,
            parameters: task.parameters,
            timeoutSeconds: task.timeoutSeconds
        )
    }

    private func postprocessResponse(_ response: String, for task: AITask) -> String {
        var processedResponse = response
        if processedResponse.hasPrefix("Assistant: ") {
            processedResponse = String(processedResponse.dropFirst(11))
        }
        processedResponse = processedResponse.trimmingCharacters(in: .whitespacesAndNewlines)

        if task.requiredCapabilities.contains(.codeGeneration) && !processedResponse.contains("```") {
            let language = task.parameters?["language"] ?? "swift"
            processedResponse = "```\(language)\n\(processedResponse)\n```"
        }
        return processedResponse
    }

    private func generateFallbackCodeResponse(for task: AITask) -> String {
        let language = task.parameters?["language"] ?? "swift"
        return """
        ```\(language)
        // Example implementation for: \(task.description)
        // This is a fallback response. Please provide an AI model for full functionality.
        func example() {
            print("Implement: \(task.query)")
        }
        ```
        """
    }

    private func generateFallbackAnalysisResponse(for task: AITask) -> String {
        var textToAnalyze: String
        if case .text(let text) = task.input {
            textToAnalyze = text
        } else {
            textToAnalyze = task.query
        }
        let language = detectLanguage(textToAnalyze)
        let sentiment = analyzeSentiment(textToAnalyze)
        let wordCount = textToAnalyze.split(separator: " ").count

        return """
        ## Text Analysis Results
        
        **Basic Metrics:**
        - Word count: \(wordCount)
        - Detected language: \(language)
        - Sentiment score: \(String(format: "%.2f", sentiment))
        
        Note: This is a fallback analysis. For comprehensive analysis, provide an AI model.
        """
    }

    private func generateFallbackConversationResponse(for task: AITask) -> String {
        let query = task.query
        if query.lowercased().contains("hello") || query.lowercased().contains("hi") {
            return "Hello! I'm an AI assistant. How can I help you today?"
        } else if query.lowercased().contains("help") {
            return "I can help with questions, code generation, and text analysis."
        } else {
            return "I've received your message. This is a fallback response. For full capabilities, please configure an Ollama model."
        }
    }

    private func calculateExpectedDuration(for task: AITask) -> TimeInterval {
        var baseDuration: TimeInterval
        switch task.priority {
        case .critical: baseDuration = 5.0
        case .high: baseDuration = 10.0
        case .normal: baseDuration = 15.0
        case .low: baseDuration = 20.0
        }
        if task.requiredCapabilities.contains(.codeGeneration) { baseDuration *= 1.5 }
        if task.requiredCapabilities.contains(.textAnalysis) { baseDuration *= 1.2 }
        return baseDuration
    }

    private func calculateProcessingTime(for task: AITask) -> TimeInterval {
        var baseTime: TimeInterval = 1.0
        if task.requiredCapabilities.contains(.codeGeneration) { baseTime += 1.5 }
        else if task.requiredCapabilities.contains(.textAnalysis) { baseTime += 1.0 }
        baseTime += Double.random(in: 0.5...1.5)
        return baseTime
    }

    private func detectLanguage(_ text: String) -> String {
        // Simple heuristic-based language detection without NaturalLanguage framework
        // (NaturalLanguage is not available on all platforms)
        let sample = text.prefix(200).lowercased()
        if sample.unicodeScalars.contains(where: { $0.value >= 0x4E00 && $0.value <= 0x9FFF }) { return "Chinese" }
        if sample.unicodeScalars.contains(where: { $0.value >= 0x3040 && $0.value <= 0x309F }) { return "Japanese" }
        if sample.unicodeScalars.contains(where: { $0.value >= 0xAC00 && $0.value <= 0xD7A3 }) { return "Korean" }
        if sample.unicodeScalars.contains(where: { $0.value >= 0x0600 && $0.value <= 0x06FF }) { return "Arabic" }
        if sample.unicodeScalars.contains(where: { $0.value >= 0x0400 && $0.value <= 0x04FF }) { return "Russian" }
        // Default to English for Latin-script text
        return "English"
    }

    private func analyzeSentiment(_ text: String) -> Double {
        let positiveWords = ["good", "great", "excellent", "amazing", "wonderful", "best", "love", "happy", "positive"]
        let negativeWords = ["bad", "awful", "terrible", "horrible", "worst", "hate", "sad", "negative", "broken"]
        let words = text.lowercased().split(separator: " ").map { String($0) }
        var score = 0.0
        for word in words {
            let clean = word.trimmingCharacters(in: .punctuationCharacters)
            if positiveWords.contains(clean) { score += 0.1 }
            if negativeWords.contains(clean) { score -= 0.1 }
        }
        return max(-1.0, min(1.0, score))
    }

    private func supportsAllCapabilities(_ requiredCapabilities: Set<AICapability>) -> Bool {
        return requiredCapabilities.isSubset(of: Set(agentCapabilities))
    }

    private func recordTaskResult(_ result: AITaskResult) {
        taskHistory[result.taskId] = result
        if taskHistory.count > maxTaskHistoryItems {
            let oldest = taskHistory.keys.first
            if let key = oldest { taskHistory.removeValue(forKey: key) }
        }
    }
}
