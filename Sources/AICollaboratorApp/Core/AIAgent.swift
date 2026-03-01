//
//  AIAgent.swift
//  AICollaborator
//
//  Created: 2025-04-10
//

import Foundation

// MARK: - Core AIAgent Protocol

/// Protocol defining the interface for all AI agents in the AICollaborator framework.
public protocol AIAgent {

    /// Execute a task within the given context.
    func execute(task: AITask, in context: AIContext) async throws -> AITaskResult

    /// Get the agent's capabilities.
    func capabilities() -> [AICapability]

    /// Check if the agent can execute a specific task.
    func canExecute(task: AITask) -> Bool

    /// Get the agent's configuration.
    func configuration() -> AIAgentConfiguration

    /// Update the agent's configuration.
    @discardableResult
    func updateConfiguration(_ configuration: AIAgentConfiguration) -> Bool

    /// Prepare the agent for task execution.
    func prepare(for task: AITask) async -> Bool

    /// Clean up after task execution.
    func cleanup(after task: AITask, result: AITaskResult) async
}

/// Extension providing default implementations of optional methods.
public extension AIAgent {

    func configuration() -> AIAgentConfiguration {
        return AIAgentConfiguration()
    }

    @discardableResult
    func updateConfiguration(_ configuration: AIAgentConfiguration) -> Bool {
        return true
    }

    func prepare(for task: AITask) async -> Bool {
        return true
    }

    func cleanup(after task: AITask, result: AITaskResult) async {}

    func canExecute(task: AITask) -> Bool {
        let agentCapabilities = Set(capabilities())
        return task.requiredCapabilities.isSubset(of: agentCapabilities)
    }
}

/// Configuration for AI agents.
public struct AIAgentConfiguration: Codable, Sendable {

    /// Maximum number of concurrent tasks the agent can execute.
    public var maxConcurrentTasks: Int

    /// Model or version to use for the agent.
    public var model: String?

    /// API endpoint for external service if applicable.
    public var apiEndpoint: URL?

    /// Additional parameters for the agent.
    public var parameters: [String: String]

    /// Temperature parameter for controlling randomness (0.0-1.0).
    public var temperature: Double?

    /// Maximum tokens to generate.
    public var maxTokens: Int?

    /// Timeout for task execution in seconds.
    public var timeoutSeconds: Double

    public init(
        maxConcurrentTasks: Int = 1,
        model: String? = nil,
        apiEndpoint: URL? = nil,
        parameters: [String: String] = [:],
        temperature: Double? = nil,
        maxTokens: Int? = nil,
        timeoutSeconds: Double = 30.0
    ) {
        self.maxConcurrentTasks = maxConcurrentTasks
        self.model = model
        self.apiEndpoint = apiEndpoint
        self.parameters = parameters
        self.temperature = temperature
        self.maxTokens = maxTokens
        self.timeoutSeconds = timeoutSeconds
    }
}

// MARK: - AICollaboratorAgent Protocol

/// Primary protocol that all AI agents must implement.
@preconcurrency
public protocol AICollaboratorAgent: Sendable {

    /// Process an AI task and produce a result.
    func processTask(_ task: AITask) async throws -> AITaskResult

    /// Provide the capabilities that this agent supports.
    func provideCapabilities() -> [AICapability]

    /// Get the current state of the agent.
    func getState() -> AgentState

    /// Initialize the agent with necessary configuration.
    func initialize(with config: AgentConfiguration) async -> AgentInitResult

    /// Shutdown the agent gracefully.
    func shutdown() async -> Result<Void, Error>
}

/// Default implementations for AICollaboratorAgent.
public extension AICollaboratorAgent {

    func getState() -> AgentState {
        return .idle
    }

    func initialize(with config: AgentConfiguration) async -> AgentInitResult {
        return .success
    }

    func shutdown() async -> Result<Void, Error> {
        return .success(())
    }
}

// MARK: - Supplementary Agent Protocols

/// Protocol for agents that can learn and improve over time.
public protocol LearningCapable {
    func train(with examples: [TrainingExample]) async -> TrainingResult
    func evaluate(using testCases: [TestCase]) async -> EvaluationResult
}

/// Protocol for agents that maintain conversation history.
public protocol ConversationAware {
    func getConversationHistory(for conversationId: String) async -> [ConversationMessage]?
    func clearConversationHistory(for conversationId: String) async -> Bool
}

/// Protocol for agents that can explain their reasoning.
public protocol ExplainableAgent {
    func explainReasoning(for taskId: UUID, resultId: UUID) async -> ExplanationResult
    func confidenceLevel(for resultId: UUID) async -> Double?
}

// MARK: - Supporting Types

/// Identifier for registered AI agents.
public struct AIAgentExchangeId: Hashable, Codable, Sendable {

    private let id: UUID

    public init() {
        self.id = UUID()
    }

    public init(_ string: String) throws {
        guard let uuid = UUID(uuidString: string) else {
            throw AICollaboratorError.invalidAgentId
        }
        self.id = uuid
    }
}

/// Error types for the AICollaborator framework.
public enum AICollaboratorError: Error, Sendable {
    case taskExecutionFailed(String)
    case agentNotFound(name: String)
    case invalidAgentId
    case invalidTaskInput
    case invalidConfiguration
    case serviceUnavailable
    case authenticationFailed
    case timeout
    case unsupportedOperation
}

/// Status of task execution.
public enum TaskResultStatus: String, Codable, Sendable {
    case completed
    case failed
    case partial
    case cancelled
    case timeout
}

/// Resource usage statistics.
public struct ResourceUsage: Codable, Sendable {

    public let inputTokens: Int?
    public let outputTokens: Int?
    public let totalTokens: Int?
    public let cpuUsage: Double?
    public let memoryUsageMB: Double?

    public init(
        inputTokens: Int? = nil,
        outputTokens: Int? = nil,
        totalTokens: Int? = nil,
        cpuUsage: Double? = nil,
        memoryUsageMB: Double? = nil
    ) {
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.totalTokens = totalTokens ?? (inputTokens ?? 0) + (outputTokens ?? 0)
        self.cpuUsage = cpuUsage
        self.memoryUsageMB = memoryUsageMB
    }
}

/// A type that can be encoded to any Codable type.
public struct AnyEncodable: Encodable, @unchecked Sendable {
    private let _encode: @Sendable (Encoder) throws -> Void

    public init<T: Encodable & Sendable>(_ value: T) {
        _encode = value.encode
    }

    public func encode(to encoder: Encoder) throws {
        try _encode(encoder)
    }
}

// MARK: - Agent Type Enum

/// Type of AI agent connection.
public enum AIAgentType: String, Codable, Sendable {
    case llm
    case textToImage
    case textToSpeech
    case speechToText
    case multimodal
}

// MARK: - Agent State and Configuration

/// Current state of an AI agent.
public enum AgentState: Equatable, Sendable {
    case initializing
    case idle
    case busy(taskId: UUID)
    case paused
    case shuttingDown
    case terminated
    case error(String)

    public static func == (lhs: AgentState, rhs: AgentState) -> Bool {
        switch (lhs, rhs) {
        case (.initializing, .initializing),
             (.idle, .idle),
             (.paused, .paused),
             (.shuttingDown, .shuttingDown),
             (.terminated, .terminated):
            return true
        case let (.busy(lhsTaskId), .busy(rhsTaskId)):
            return lhsTaskId == rhsTaskId
        case let (.error(lhsError), .error(rhsError)):
            return lhsError == rhsError
        default:
            return false
        }
    }
}

/// Result of agent initialization.
public enum AgentInitResult: Sendable {
    case success
    case failure(String)
}

/// Result of an agent explanation.
public struct ExplanationResult: Sendable {
    public let explanation: String
    public let confidence: Double
    public let factors: [String: Double]?
    public let alternatives: [String]?
}

/// Configuration for an AI agent.
public struct AgentConfiguration: Codable, Sendable {

    public var rateLimit: Int
    public var maxTokens: Int
    public var temperature: Double
    public var modelId: String?
    public var timeout: TimeInterval
    public var retryPolicy: RetryPolicy
    public var additionalParams: [String: String]

    public init(
        rateLimit: Int = 60,
        maxTokens: Int = 4096,
        temperature: Double = 0.7,
        modelId: String? = nil,
        timeout: TimeInterval = 30.0,
        retryPolicy: RetryPolicy = .default,
        additionalParams: [String: String] = [:]
    ) {
        self.rateLimit = rateLimit
        self.maxTokens = maxTokens
        self.temperature = temperature
        self.modelId = modelId
        self.timeout = timeout
        self.retryPolicy = retryPolicy
        self.additionalParams = additionalParams
    }
}

/// Retry policy for failed requests.
public struct RetryPolicy: Codable, Sendable {

    public var maxRetries: Int
    public var initialDelay: TimeInterval
    public var backoffFactor: Double

    public init(maxRetries: Int, initialDelay: TimeInterval, backoffFactor: Double) {
        self.maxRetries = maxRetries
        self.initialDelay = initialDelay
        self.backoffFactor = backoffFactor
    }

    public static let `default` = RetryPolicy(maxRetries: 3, initialDelay: 1.0, backoffFactor: 2.0)
    public static let noRetry = RetryPolicy(maxRetries: 0, initialDelay: 0, backoffFactor: 0)
}

/// Sender of a message.
public enum MessageSender: String, Codable, Sendable {
    case user
    case agent
    case system
}

// MARK: - Training and Evaluation Types

/// Example for training an agent.
public struct TrainingExample: Sendable {
    public let input: String
    public let expectedOutput: String
    public let context: [String: String]?
    public let weight: Double

    public init(input: String, expectedOutput: String, context: [String: String]? = nil, weight: Double = 1.0) {
        self.input = input
        self.expectedOutput = expectedOutput
        self.context = context
        self.weight = weight
    }
}

/// Result of agent training.
public struct TrainingResult: Sendable {
    public let success: Bool
    public let examplesProcessed: Int
    public let metrics: [String: Double]
    public let error: String?
}

/// Test case for agent evaluation.
public struct TestCase: Sendable {
    public let input: String
    public let expectedOutput: String
    public let criteria: [EvaluationCriterion]
}

/// Criterion for evaluating agent performance.
public struct EvaluationCriterion: @unchecked Sendable {
    public let name: String
    public let weight: Double
    public let evaluator: @Sendable (String, String) -> Double

    public init(name: String, weight: Double, evaluator: @escaping @Sendable (String, String) -> Double) {
        self.name = name
        self.weight = weight
        self.evaluator = evaluator
    }
}

/// Result of agent evaluation.
public struct EvaluationResult: Sendable {
    public let overallScore: Double
    public let criteriaScores: [String: Double]
    public let testCasesEvaluated: Int
    public let failures: [String]?
}

// MARK: - Agent Errors

/// Errors related to agents.
public enum AgentError: Error, Sendable {
    case notImplemented(String)
    case invalidConfiguration(String)
    case rateLimitExceeded
    case authenticationFailed
    case capabilityNotSupported(AICapability)
    case networkError(String)
    case processingError(String)
    case unknownError(String)
}
