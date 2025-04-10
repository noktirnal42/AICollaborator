//
//  AITask.swift
//  AICollaborator
//
//  Created: 2025-04-10
//

import Foundation

/// Represents a task that can be executed by an AI agent
public struct AITask: Identifiable, Sendable {
    // MARK: - Properties
    
    /// Unique identifier for the task
    public let taskId: UUID
    
    /// Short description of the task
    public let description: String
    
    /// Detailed query or instruction for the task
    public let query: String
    
    /// Additional context for task execution
    public let context: [String: Any]
    
    /// Required capabilities to execute this task
    public let requiredCapabilities: Set<AICapability>
    
    /// Priority level for this task
    public let priority: TaskPriority
    
    /// Current state of the task
    private(set) public var state: TaskState
    
    /// Creation timestamp
    public let createdAt: Date
    
    /// Last update timestamp
    private(set) public var updatedAt: Date
    
    /// Task timeout duration
    public let timeout: TimeInterval
    
    /// User who created the task (if applicable)
    public let createdBy: String?
    
    // MARK: - Initialization
    
    /// Create a new AI task
    /// - Parameters:
    ///   - description: Short description of the task
    ///   - query: Detailed query or instruction
    ///   - context: Additional context data
    ///   - requiredCapabilities: Capabilities required for execution
    ///   - priority: Task priority level
    ///   - timeout: Timeout duration in seconds
    ///   - createdBy: User who created the task
    public init(
        description: String,
        query: String,
        context: [String: Any] = [:],
        requiredCapabilities: Set<AICapability> = [.basicCompletion],
        priority: TaskPriority = .normal,
        timeout: TimeInterval = 60.0,
        createdBy: String? = nil
    ) {
        self.taskId = UUID()
        self.description = description
        self.query = query
        self.context = context
        self.requiredCapabilities = requiredCapabilities
        self.priority = priority
        self.state = .created
        self.createdAt = Date()
        self.updatedAt = self.createdAt
        self.timeout = timeout
        self.createdBy = createdBy
    }
    
    // MARK: - Identifiable Conformance
    
    public var id: UUID {
        return taskId
    }
    
    // MARK: - Methods
    
    /// Update the state of the task
    /// - Parameter newState: The new state
    /// - Returns: Updated task
    public mutating func updateState(_ newState: TaskState) -> AITask {
        self.state = newState
        self.updatedAt = Date()
        return self
    }
    
    /// Check if the task has exceeded its timeout
    /// - Returns: True if the task has timed out
    public func hasTimedOut() -> Bool {
        return Date().timeIntervalSince(createdAt) > timeout
    }
    
    /// Create a result for this task with the specified status and output
    /// - Parameters:
    ///   - status: Result status
    ///   - output: Result output data
    /// - Returns: New task result
    public func createResult(status: TaskResultStatus, output: Any) -> AITaskResult {
        return AITaskResult(
            taskId: taskId,
            status: status,
            output: output,
            completedAt: Date()
        )
    }
    
    /// Parse a task from user input
    /// - Parameter input: User input string
    /// - Returns: Parsed task if successful
    public static func parseFromInput(_ input: String) throws -> AITask {
        // This would contain more sophisticated parsing logic in a real implementation
        let components = input.components(separatedBy: ":")
        guard components.count >= 2 else {
            throw AITaskError.invalidInput("Input must contain a description and query separated by ':'")
        }
        
        let description = components[0].trimmingCharacters(in: .whitespacesAndNewlines)
        let query = components[1].trimmingCharacters(in: .whitespacesAndNewlines)
        
        return AITask(
            description: description,
            query: query
        )
    }
}

// MARK: - Supporting Types

/// Status of a task result
public enum TaskResultStatus: String, Codable {
    case completed
    case partiallyCompleted
    case failed
    case timedOut
    case cancelled
}

/// Priority levels for tasks
public enum TaskPriority: Int, Comparable, Codable {
    case low = 0
    case normal = 50
    case high = 100
    case critical = 200
    
    public static func < (lhs: TaskPriority, rhs: TaskPriority) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

/// States that a task can be in during its lifecycle
public enum TaskState: Codable, Equatable {
    case created
    case queued
    case executing
    case completed(result: TaskResultStatus)
    case failed(error: String)
    
    // Custom Codable implementation for associated values
    private enum CodingKeys: String, CodingKey {
        case state, result, error
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let state = try container.decode(String.self, forKey: .state)
        
        switch state {
        case "created":
            self = .created
        case "queued":
            self = .queued
        case "executing":
            self = .executing
        case "completed":
            let result = try container.decode(TaskResultStatus.self, forKey: .result)
            self = .completed(result: result)
        case "failed":
            let error = try container.decode(String.self, forKey: .error)
            self = .failed(error: error)
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .state,
                in: container,
                debugDescription: "Invalid task state"
            )
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .created:
            try container.encode("created", forKey: .state)
        case .queued:
            try container.encode("queued", forKey: .state)
        case .executing:
            try container.encode("executing", forKey: .state)
        case .completed(let result):
            try container.encode("completed", forKey: .state)
            try container.encode(result, forKey: .result)
        case .failed(let error):
            try container.encode("failed", forKey: .state)
            try container.encode(error, forKey: .error)
        }
    }
}

/// Result of a task execution
public struct AITaskResult: Identifiable {
    /// Original task ID
    public let taskId: UUID
    
    /// Result ID (different from task ID)
    public let resultId: UUID
    
    /// Status of the task execution
    public let status: TaskResultStatus
    
    /// Output data produced by the task
    public let output: Any
    
    /// Timestamp when the task was completed
    public let completedAt: Date
    
    /// Duration of task execution in seconds
    public let executionTime: TimeInterval?
    
    // MARK: - Initializers
    
    /// Create a new task result
    /// - Parameters:
    ///   - taskId: ID of the associated task
    ///   - status: Result status
    ///   - output: Output data
    ///   - completedAt: Completion timestamp
    ///   - executionTime: Execution duration
    public init(
        taskId: UUID,
        status: TaskResultStatus,
        output: Any,
        completedAt: Date = Date(),
        executionTime: TimeInterval? = nil
    ) {
        self.taskId = taskId
        self.resultId = UUID()
        self.status = status
        self.output = output
        self.completedAt = completedAt
        self.executionTime = executionTime
    }
    
    /// Simplified initializer with just status and output
    /// - Parameters:
    ///   - status: Result status
    ///   - output: Output data
    public init(status: TaskResultStatus, output: Any) {
        self.init(taskId: UUID(), status: status, output: output)
    }
    
    // MARK: - Identifiable Conformance
    
    public var id: UUID {
        return resultId
    }
    
    /// Check if the result indicates a successful completion
    public var isSuccessful: Bool {
        return status == .completed || status == .partiallyCompleted
    }
}

/// Capabilities that AI agents can provide
public enum AICapability: String, Codable, CaseIterable {
    case basicCompletion
    case codeGeneration
    case codeCompletion
    case imageGeneration
    case textAnalysis
    case dataSummarization
    case contextRetrieval
    case conversational
    case multimodal
    case finetuned
}

/// Errors related to AI tasks
public enum AITaskError: Error {
    case invalidInput(String)
    case executionFailed(String)
    case timeout(String)
    case missingCapability(AICapability)
    case contextError(String)
}

/// Agent exchange identifier
public struct AIAgentExchangeId: Hashable {
    private let id: UUID
    
    public init() {
        self.id = UUID()
    }
    
    public init(id: UUID) {
        self.id = id
    }
}

/// Type of AI agent
public enum AIAgentType: String, Codable {
    case llm
    case textToImage
    case textToSpeech
    case speechToText
    case multimodal
    case custom
}

