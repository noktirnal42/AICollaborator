//
//  AIAgent.swift
//  AICollaborator
//
//  Created: 2025-04-10
//

import Foundation
import SwiftyJSON
import Alamofire

// MARK: - Agent Protocols

/// Primary protocol that all AI agents must implement
public protocol AICollaboratorAgent: Sendable {
    /// Process an AI task and produce a result
    /// - Parameter task: The task to process
    /// - Returns: The result of processing the task
    func processTask(_ task: AITask) async throws -> AITaskResult
    
    /// Provide the capabilities that this agent supports
    /// - Returns: Array of supported capabilities
    func provideCapabilities() -> [AICapability]
    
    /// Get the current state of the agent
    /// - Returns: Current agent state
    func getState() -> AgentState
    
    /// Initialize the agent with necessary configuration
    /// - Parameter config: Agent configuration
    /// - Returns: Initialization success or failure
    func initialize(with config: AgentConfiguration) async -> AgentInitResult
    
    /// Shutdown the agent gracefully
    /// - Returns: Completion success or error
    func shutdown() async -> Result<Void, Error>
}

/// Default implementations for AICollaboratorAgent
public extension AICollaboratorAgent {
    /// Default implementation for getting agent state
    func getState() -> AgentState {
        return .idle
    }
    
    /// Default implementation for initialization
    func initialize(with config: AgentConfiguration) async -> AgentInitResult {
        return .success
    }
    
    /// Default implementation for shutdown
    func shutdown() async -> Result<Void, Error> {
        return .success(())
    }
}

/// Protocol for agents that can learn and improve over time
public protocol LearningCapable {
    /// Train the agent with provided examples
    /// - Parameter examples: Training examples
    /// - Returns: Training result
    func train(with examples: [TrainingExample]) async -> TrainingResult
    
    /// Evaluate the agent's performance
    /// - Parameter testCases: Test cases for evaluation
    /// - Returns: Evaluation metrics
    func evaluate(using testCases: [TestCase]) async -> EvaluationResult
}

/// Protocol for agents that maintain conversation history
public protocol ConversationAware {
    /// Retrieve conversation history
    /// - Parameter conversationId: ID of the conversation
    /// - Returns: Conversation history if available
    func getConversationHistory(for conversationId: String) async -> [ConversationMessage]?
    
    /// Clear conversation history
    /// - Parameter conversationId: ID of the conversation to clear
    /// - Returns: Success or failure
    func clearConversationHistory(for conversationId: String) async -> Bool
}

/// Protocol for agents that can explain their reasoning
public protocol ExplainableAgent {
    /// Explain the reasoning behind a result
    /// - Parameters:
    ///   - taskId: ID of the task
    ///   - resultId: ID of the result
    /// - Returns: Explanation of the reasoning process
    func explainReasoning(for taskId: UUID, resultId: UUID) async -> ExplanationResult
    
    /// Provide confidence level for a result
    /// - Parameter resultId: ID of the result
    /// - Returns: Confidence level between 0.0 and 1.0
    func confidenceLevel(for resultId: UUID) async -> Double?
}

// MARK: - Agent Base Class

/// Base actor class for implementing AI agents
public actor BaseAIAgent: AICollaboratorAgent {
    // MARK: - Properties
    
    /// Name of the agent
    public let name: String
    
    /// Version of the agent
    public let version: String
    
    /// Description of the agent's purpose
    public let description: String
    
    /// Agent capabilities
    private let capabilities: [AICapability]
    
    /// Current state of the agent
    private var state: AgentState = .initializing
    
    /// Configuration for the agent
    private var configuration: AgentConfiguration
    
    /// Internal logger
    private let logger = Logger()
    
    // MARK: - Initialization
    
    /// Initialize a new base AI agent
    /// - Parameters:
    ///   - name: Agent name
    ///   - version: Agent version
    ///   - description: Agent description
    ///   - capabilities: Supported capabilities
    ///   - configuration: Initial configuration
    public init(
        name: String,
        version: String,
        description: String,
        capabilities: [AICapability],
        configuration: AgentConfiguration = AgentConfiguration()
    ) {
        self.name = name
        self.version = version
        self.description = description
        self.capabilities = capabilities
        self.configuration = configuration
    }
    
    // MARK: - AICollaboratorAgent Protocol Implementation
    
    /// Process an AI task (must be overridden by subclasses)
    public func processTask(_ task: AITask) async throws -> AITaskResult {
        // Base implementation just returns an error
        // Concrete subclasses should override this method
        throw AgentError.notImplemented("processTask must be overridden by a concrete agent implementation")
    }
    
    /// Provide the capabilities of this agent
    public func provideCapabilities() -> [AICapability] {
        return capabilities
    }
    
    /// Get the current state of the agent
    public func getState() -> AgentState {
        return state
    }
    
    /// Initialize the agent with the provided configuration
    public func initialize(with config: AgentConfiguration) async -> AgentInitResult {
        state = .initializing
        
        // Apply configuration
        self.configuration = config
        
        // Perform initialization logic
        do {
            // Simulate initialization delay
            try await Task.sleep(for: .seconds(0.5))
            
            state = .idle
            return .success
        } catch {
            state = .error(error.localizedDescription)
            return .failure(error.localizedDescription)
        }
    }
    
    /// Shutdown the agent gracefully
    public func shutdown() async -> Result<Void, Error> {
        state = .shuttingDown
        
        do {
            // Perform cleanup operations
            try await Task.sleep(for: .seconds(0.5))
            
            state = .terminated
            return .success(())
        } catch {
            state = .error(error.localizedDescription)
            return .failure(error)
        }
    }
    
    // MARK: - Helper Methods
    
    /// Update the agent's state
    /// - Parameter newState: The new state
    protected func updateState(_ newState: AgentState) {
        state = newState
        logger.info("Agent \(name) state changed to \(state)")
    }
    
    /// Check if the agent supports a required capability
    /// - Parameter capability: Capability to check
    /// - Returns: True if supported
    protected func supportsCapability(_ capability: AICapability) -> Bool {
        return capabilities.contains(capability)
    }
    
    /// Check if all required capabilities are supported
    /// - Parameter requiredCapabilities: Set of required capabilities
    /// - Returns: True if all are supported
    protected func supportsAllCapabilities(_ requiredCapabilities: Set<AICapability>) -> Bool {
        return requiredCapabilities.isSubset(of: Set(capabilities))
    }
    
    /// Log agent activity
    /// - Parameters:
    ///   - message: Log message
    ///   - level: Log level
    protected func log(_ message: String, level: LogLevel = .info) {
        logger.log(message, level: level)
    }
}

// MARK: - Supporting Types

/// Current state of an AI agent
public enum AgentState: Equatable {
    case initializing
    case idle
    case busy(taskId: UUID)
    case paused
    case shuttingDown
    case terminated
    case error(String)
    
    // Equatable conformance for associated value types
    public static func == (lhs: AgentState, rhs: AgentState) -> Bool {
        switch (lhs, rhs) {
        case (.initializing, .initializing),
             (.idle, .idle),
             (.paused, .paused),
             (.shuttingDown, .shuttingDown),
             (.terminated, .terminated):
            return true
        case (.busy(let lhsTaskId), .busy(let rhsTaskId)):
            return lhsTaskId == rhsTaskId
        case (.error(let lhsError), .error(let rhsError)):
            return lhsError == rhsError
        default:
            return false
        }
    }
}

/// Result of agent initialization
public enum AgentInitResult {
    case success
    case failure(String)
}

/// Result of an agent explanation
public struct ExplanationResult {
    /// Explanation text
    public let explanation: String
    
    /// Confidence level (0.0 to 1.0)
    public let confidence: Double
    
    /// Factors considered in making the decision
    public let factors: [String: Double]?
    
    /// Alternative decisions that were considered
    public let alternatives: [String]?
}

/// Configuration for an AI agent
public struct AgentConfiguration: Codable {
    /// Rate limit in requests per minute
    public var rateLimit: Int
    
    /// Maximum tokens per request
    public var maxTokens: Int
    
    /// Temperature for randomness (0.0 to 1.0)
    public var temperature: Double
    
    /// Model identifier
    public var modelId: String?
    
    /// Timeout for requests in seconds
    public var timeout: TimeInterval
    
    /// Retry configuration
    public var retryPolicy: RetryPolicy
    
    /// Additional parameters
    public var additionalParams: [String: String]
    
    /// Initialize with default values
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

/// Retry policy for failed requests
public struct RetryPolicy: Codable {
    /// Maximum number of retries
    public var maxRetries: Int
    
    /// Initial delay before first retry (seconds)
    public var initialDelay: TimeInterval
    
    /// Backoff factor for subsequent retries
    public var backoffFactor: Double
    
    /// Default retry policy
    public static let `default` = RetryPolicy(maxRetries: 3, initialDelay: 1.0, backoffFactor: 2.0)
    
    /// No retries policy
    public static let noRetry = RetryPolicy(maxRetries: 0, initialDelay: 0, backoffFactor: 0)
}

/// Message in a conversation
public struct ConversationMessage: Identifiable, Codable {
    /// Message ID
    public let id: UUID
    
    /// Sender (user or agent)
    public let sender: MessageSender
    
    /// Message content
    public let content: String
    
    /// Timestamp
    public let timestamp: Date
    
    /// Metadata
    public let metadata: [String: String]?
    
    /// Initialize a new conversation message
    public init(
        id: UUID = UUID(),
        sender: MessageSender,
        content: String,
        timestamp: Date = Date(),
        metadata: [String: String]? = nil
    ) {
        self.id = id
        self.sender = sender
        self.content = content
        self.timestamp = timestamp
        self.metadata = metadata
    }
}

/// Sender of a message
public enum MessageSender: String, Codable {
    case user
    case agent
    case system
}

/// Example for training an agent
public struct TrainingExample {
    /// Input data
    public let input: String
    
    /// Expected output
    public let expectedOutput: String
    
    /// Additional context
    public let context: [String: Any]?
    
    /// Weight for this example
    public let weight: Double
}

/// Result of agent training
public struct TrainingResult {
    /// Success indicator
    public let success: Bool
    
    /// Number of examples processed
    public let examplesProcessed: Int
    
    /// Metrics from training
    public let metrics: [String: Double]
    
    /// Error message if training failed
    public let error: String?
}

/// Test case for agent evaluation
public struct TestCase {
    /// Input to test
    public let input: String
    
    /// Expected output
    public let expectedOutput: String
    
    /// Evaluation criteria
    public let criteria: [EvaluationCriterion]
}

/// Criterion for evaluating agent performance
public struct EvaluationCriterion {
    /// Name of the criterion
    public let name: String
    
    /// Weight in overall score
    public let weight: Double
    
    /// Function to evaluate performance
    public let evaluator: (String, String) -> Double
}

/// Result of agent evaluation
public struct EvaluationResult {
    /// Overall score (0.0 to 1.0)
    public let overallScore: Double
    
    /// Detailed scores by criterion
    public let criteriaScores: [String: Double]
    
    /// Number of test cases evaluated
    public let testCasesEvaluated: Int
    
    /// Failures encountered
    public let failures: [String]?
}

/// Errors related to agents
public enum AgentError: Error {
    case notImplemented(String)
    case invalidConfiguration(String)
    case rateLimitExceeded
    case authenticationFailed
    case capabilityNotSupported(AICapability)
    case networkError(String)
    case processingError(String)
    case unknownError(String)
}

/// Logging levels
fileprivate enum LogLevel {
    case debug
    case info
    case warning
    case error
}

/// Simple logger implementation
fileprivate struct Logger {
    func log(_ message: String, level: LogLevel) {
        let prefix: String
        switch level {
        case .debug: prefix = "[DEBUG]"
        case .info: prefix = "[INFO]"
        case .warning: prefix = "[WARNING]"
        case .error: prefix = "[ERROR]"
        }
        
        print("\(prefix) \(message)")
    }
    
    func debug(_ message: String) {
        log(message, level: .debug)
    }
    
    func info(_ message: String) {
        log(message, level: .info)
    }
    
    func warning(_ message: String) {
        log(message, level: .warning)
    }
    
    func error(_ message: String) {
        log(message, level: .error)
    }
}

