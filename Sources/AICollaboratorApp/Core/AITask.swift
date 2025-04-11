import Foundation

/// Protocol representing a task that can be executed by AI agents.
///
/// AITask defines the interface for tasks that can be processed by AI agents within the 
/// AICollaborator framework. Tasks encapsulate input data, constraints, and other information
/// needed for AI agents to perform specific operations.
///
/// ## Task Lifecycle
///
/// 1. **Creation**: A task is created with a specific type, input, and optional constraints.
/// 2. **Validation**: The task is validated to ensure it contains required information.
/// 3. **Routing**: The AICollaborator routes the task to an appropriate agent.
/// 4. **Execution**: An agent processes the task and produces a result.
/// 5. **Completion**: The result is returned and optionally stored in context.
///
/// ## Creating a Custom Task
///
/// ```swift
/// struct MyCustomTask: AITask {
///     let id = UUID()
///     let type: AITaskType = .custom("my-task")
///     let sessionId = UUID()
///     let input: String
///     let constraints: [String]
///     let priority: TaskPriority = .medium
///
///     func validate() -> Bool {
///         return !input.isEmpty
///     }
///
///     func matchesCapabilities(_ capabilities: [AICapability]) -> Bool {
///         return capabilities.contains(.problemSolving)
///     }
/// }
/// ```
@available(macOS 15.0, *)
public protocol AITask {
    /// Unique identifier for the task.
    var id: UUID { get }
    
    /// The type of task, which helps determine which agent can handle it.
    var type: AITaskType { get }
    
    /// The session ID this task belongs to, used for context management.
    var sessionId: UUID { get }
    
    /// Task priority level.
    var priority: TaskPriority { get }
    
    /// Validate that the task has all required information.
    ///
    /// This method is called before the task is executed to ensure it has
    /// all the required information for successful processing.
    ///
    /// - Returns: True if the task is valid, false otherwise.
    func validate() -> Bool
    
    /// Check if the task can be handled by an agent with the given capabilities.
    ///
    /// This method is used by the AICollaborator to determine if a particular agent
    /// can handle this task based on its declared capabilities.
    ///
    /// - Parameter capabilities: The capabilities of an agent.
    /// - Returns: True if the agent can handle this task, false otherwise.
    func matchesCapabilities(_ capabilities: [AICapability]) -> Bool
    
    /// Asynchronously process the task with the given context.
    ///
    /// This method provides a default implementation that throws an error.
    /// Override this method in task types that support asynchronous execution.
    ///
    /// - Parameters:
    ///   - context: The context for the task execution.
    /// - Returns: The result of the task execution.
    /// - Throws: An error if the task execution fails.
    func process(withContext context: AIContext?) async throws -> AITaskResult
}

/// Extension providing default implementations for AITask methods.
@available(macOS 15.0, *)
public extension AITask {
    /// Default implementation for asynchronous processing.
    ///
    /// This default implementation throws an error indicating that the task doesn't
    /// support asynchronous execution. Task types that support async execution
    /// should override this method.
    func process(withContext context: AIContext?) async throws -> AITaskResult {
        throw AIError.taskDoesNotSupportAsyncExecution
    }
}

/// Enum representing the type of AI task.
@available(macOS 15.0, *)
public enum AITaskType: Equatable, Hashable {
    /// Code generation task.
    case codeGeneration
    
    /// Code analysis task.
    case codeAnalysis
    
    /// Text analysis task.
    case textAnalysis
    
    /// Problem-solving task.
    case problemSolving
    
    /// Data processing task.
    case dataProcessing
    
    /// Custom task type with a string identifier.
    case custom(String)
    
    /// Equatability implementation
    public static func == (lhs: AITaskType, rhs: AITaskType) -> Bool {
        switch (lhs, rhs) {
        case (.codeGeneration, .codeGeneration),
             (.codeAnalysis, .codeAnalysis),
             (.textAnalysis, .textAnalysis),
             (.problemSolving, .problemSolving),
             (.dataProcessing, .dataProcessing):
            return true
        case (.custom(let lhsValue), .custom(let rhsValue)):
            return lhsValue == rhsValue
        default:
            return false
        }
    }
    
    /// Hashability implementation
    public func hash(into hasher: inout Hasher) {
        switch self {
        case .codeGeneration:
            hasher.combine(0)
        case .codeAnalysis:
            hasher.combine(1)
        case .textAnalysis:
            hasher.combine(2)
        case .problemSolving:
            hasher.combine(3)
        case .dataProcessing:
            hasher.combine(4)
        case .custom(let value):
            hasher.combine(5)
            hasher.combine(value)
        }
    }
}

/// Enum representing the priority level of a task.
@available(macOS 15.0, *)
public enum TaskPriority: Int, Comparable {
    /// Low priority task.
    case low = 0
    
    /// Medium priority task.
    case medium = 1
    
    /// High priority task.
    case high = 2
    
    /// Critical priority task.
    case critical = 3
    
    /// Comparability implementation
    public static func < (lhs: TaskPriority, rhs: TaskPriority) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

/// Struct representing the result of a task execution.
@available(macOS 15.0, *)
public struct AITaskResult {
    /// Unique identifier for the result, typically matching the task ID.
    public let id: UUID
    
    /// The status of the task execution.
    public let status: TaskStatus
    
    /// The output of the task execution.
    public let output: String
    
    /// Optional error that occurred during task execution.
    public let error: Error?
    
    /// Optional metadata about the task execution.
    public let metadata: [String: Any]?
    
    /// Timestamp when the result was created.
    public let timestamp: Date
    
    /// Initialize a new task result.
    ///
    /// - Parameters:
    ///   - id: Unique identifier for the result, typically matching the task ID.
    ///   - status: The status of the task execution.
    ///   - output: The output of the task execution.
    ///   - error: Optional error that occurred during task execution.
    ///   - metadata: Optional metadata about the task execution.
    ///   - timestamp: Timestamp when the result was created (defaults to now).
    public init(
        id: UUID,
        status: TaskStatus,
        output: String,
        error: Error? = nil,
        metadata: [String: Any]? = nil,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.status = status
        self.output = output
        self.error = error
        self.metadata = metadata
        self.timestamp = timestamp
    }
}

/// Enum representing the status of a task execution.
@available(macOS 15.0, *)
public enum TaskStatus: String, Codable {
    /// Task was completed successfully.
    case completed
    
    /// Task failed to complete.
    case failed
    
    /// Task completed partially.
    case partiallyCompleted
    
    /// Task is still in progress.
    case inProgress
}

// MARK: - Common Task Implementations

/// A task for generating code.
@available(macOS 15.0, *)
public struct CodeGenerationTask: AITask {
    /// Unique identifier for the task.
    public let id: UUID
    
    /// The session ID this task belongs to.
    public let sessionId: UUID
    
    /// The type of task (always .codeGeneration for this struct).
    public let type: AITaskType = .codeGeneration
    
    /// Description of the code to generate.
    public let description: String
    
    /// Target programming language.
    public let language: String
    
    /// Optional constraints on the generated code.
    public let constraints: [String]
    
    /// Task priority level.
    public let priority: TaskPriority
    
    /// Initialize a new code generation task.
    ///
    /// - Parameters:
    ///   - id: Unique identifier for the task (defaults to a new UUID).
    ///   - sessionId: The session ID this task belongs to (defaults to a new UUID).
    ///   - description: Description of the code to generate.
    ///   - language: Target programming language.
    ///   - constraints: Optional constraints on the generated code.
    ///   - priority: Task priority level (defaults to .medium).
    public init(
        id: UUID = UUID(),
        sessionId: UUID = UUID(),
        description: String,
        language: String,
        constraints: [String] = [],
        priority: TaskPriority = .medium
    ) {
        self.id = id
        self.sessionId = sessionId
        self.description = description
        self.language = language
        self.constraints = constraints
        self.priority = priority
    }
    
    /// Validate that the task has all required information.
    public func validate() -> Bool {
        return !description.isEmpty && !language.isEmpty
    }
    
    /// Check if the task can be handled by an agent with the given capabilities.
    public func matchesCapabilities(_ capabilities: [AICapability]) -> Bool {
        return capabilities.contains(.codeGeneration)
    }
}

/// A task for analyzing code.
@available(macOS 15.0, *)
public struct CodeAnalysisTask: AITask {
    /// Unique identifier for the task.
    public let id: UUID
    
    /// The session ID this task belongs to.
    public let sessionId: UUID
    
    /// The type of task (always .codeAnalysis for this struct).
    public let type: AITaskType = .codeAnalysis
    
    /// The code to analyze.
    public let code: String
    
    /// The language of the code.
    public let language: String
    
    /// The type of analysis to perform.
    public let analysisType: AnalysisType
    
    /// Task priority level.
    public let priority: TaskPriority
    
    /// Types of code analysis that can be performed.
    public enum AnalysisType: String, Codable {
        /// Analyze code for security vulnerabilities.
        case security
        
        /// Analyze code for performance issues.
        case performance
        
        /// Analyze code for style and consistency issues.
        case style
        
        /// Analyze code for bugs and logical errors.
        case bugs
        
        /// Comprehensive analysis covering multiple aspects.
        case comprehensive
    }
    
    /// Initialize a new code analysis task.
    ///
    /// - Parameters:
    ///   - id: Unique identifier for the task (defaults to a new UUID).
    ///   - sessionId: The session ID this task belongs to (defaults to a new UUID).
    ///   - code: The code to analyze.
    ///   - language: The language of the code.
    ///   - analysisType: The type of analysis to perform.
    ///   - priority: Task priority level (defaults to .medium).
    public init(
        id: UUID = UUID(),
        sessionId: UUID = UUID(),
        code: String,
        language: String,
        analysisType: AnalysisType,
        priority: TaskPriority = .medium
    ) {
        self.id = id
        self.sessionId = sessionId
        self.code = code
        self.language = language
        self.analysisType = analysisType
        self.priority = priority
    }
    
    /// Validate that the task has all required information.
    public func validate() -> Bool {
        return !code.isEmpty && !language.isEmpty
    }
    
    /// Check if the task can be handled by an agent with the given capabilities.
    public func matchesCapabilities(_ capabilities: [AICapability]) -> Bool {
        return capabilities.contains(.codeAnalysis)
    }
}

/// A task for analyzing text.
@available(macOS 15.0, *)
public struct TextAnalysisTask: AITask {
    /// Unique identifier for the task.
    public let id: UUID
    
    /// The session ID this task belongs to.
    public let sessionId: UUID
    
    /// The type of task (always .textAnalysis for this struct).
    public let type: AITaskType = .textAnalysis
    
    /// The text to analyze.
    public let text: String
    
    /// The type of analysis to perform.
    public let analysisType: AnalysisType
    
    /// Task priority level.
    public let priority: TaskPriority
    
    /// Types of text analysis that can be performed.
    public enum AnalysisType: String, Codable {
        /// Analyze text sentiment.
        case sentiment
        
        /// Extract entities from text.
        case entityExtraction
        
        /// Summarize text.
        case summarization
        
        /// Classify text into categories.
        case classification
        
        /// Extract key information from text.
        case informationExtraction
    }
    
    /// Initialize a new text analysis task.
    ///
    /// - Parameters:
    ///   - id: Unique identifier for the task (defaults to a new UUID).
    ///   - sessionId: The session ID this task belongs to (defaults to a new UUID).
    ///   - text: The text to analyze.
    ///   - analysisType: The type of analysis to perform.
    ///   - priority: Task priority level (defaults to .medium).
    public init(
        id: UUID = UUID(),
        sessionId: UUID = UUID(),
        text: String,
        analysisType: AnalysisType,
        priority: TaskPriority = .medium
    ) {
        self.id = id
        self.sessionId = sessionId
        self.text = text
        self.analysisType = analysisType
        self.priority = priority
    }
    
    /// Validate that the task has all required information.
    public func validate() -> Bool {
        return !text.isEmpty
    }
    
    /// Check if the task can be handled by an agent with the given capabilities.
    public func matchesCapabilities(_ capabilities: [AICapability]) -> Bool {
        return capabilities.contains(.textAnalysis)
    }
}

/// A task for solving problems.
@available(macOS 15.0, *)
public struct ProblemSolvingTask: AITask {
    /// Unique identifier for the task.
    public let id: UUID
    
    /// The session ID this task belongs to.
    public let sessionId: UUID
    
    /// The type of task (always .problemSolving for this struct).
    public let type: AITaskType = .problemSolving
    
    /// Description of the problem to solve.
    public let problemStatement: String
    
    /// Optional context or background information.
    public let context: [String: Any]?
    
    /// Optional constraints on the solution.
    public let constraints: [String]
    
    /// Task priority level.
    public let priority: TaskPriority
    
    /// Initialize a new problem-solving task.
    ///
    /// - Parameters:
    ///   - id: Unique identifier for the task (defaults to a new UUID).
    ///   - sessionId: The session ID this task belongs to (defaults to a new UUID).
    ///   - problemStatement: Description of the problem to solve.
    ///   - context: Optional context or background information.
    ///   - constraints: Optional constraints on the solution.
    ///   - priority: Task priority level (defaults to .medium).
    public init(
        id: UUID = UUID(),
        sessionId: UUID = UUID(),
        problemStatement: String,
        context: [String: Any]? = nil,
        constraints: [String] = [],
        priority: TaskPriority = .medium
    ) {
        self.id = id
        self.sessionId = sessionId
        self.problemStatement = problemStatement
        self.context = context
        self.constraints = constraints
        self.priority = priority
    }
    
    /// Validate that the task has all required information.
    public func validate() -> Bool {
        return !problemStatement.isEmpty
    }
    
    /// Check if the task can be handled by an agent with the given capabilities.
    public func matchesCapabilities(_ capabilities: [AICapability]) -> Bool {
        return capabilities.contains(.problemSolving)
    }
}

/// A task for processing data.
@available(macOS 15.0, *)
public struct DataProcessingTask: AITask {
    /// Unique identifier for the task.
    public let id: UUID
    
    /// The session ID this task belongs to.
    public let sessionId: UUID
    
    /// The type of task (always .dataProcessing for this struct).
    public let type: AITaskType = .dataProcessing
    
    /// The data to process, stored as a dictionary.
    public let data: [String: Any]
    
    /// The type of processing to perform.
    public let processingType: ProcessingType
    
    /// The format in which to return the processed data.
    public let outputFormat: OutputFormat
    
    /// Task priority level.
    public let priority: TaskPriority
    
    /// Types of data processing that can be performed.
    public enum ProcessingType: String, Codable {
        /// Filter data based on criteria.
        case filtering
        
        /// Transform data from one format to another.
        case transformation
        
        /// Aggregate or summarize data.
        case aggregation
        
        /// Enrich data with additional information.
        case enrichment
        
        /// Clean and normalize data.
        case cleaning
    }
    
    /// Output formats for processed data.
    public enum OutputFormat: String, Codable {
        /// JSON format.
        case json
        
        /// CSV format.
        case csv
        
        /// XML format.
        case xml
        
        /// Plain text format.
        case text
        
        /// Structured dictionary format.
        case dictionary
    }
    
    /// Initialize a new data processing task.
    ///
    /// - Parameters:
    ///   - id: Unique identifier for the task (defaults to a new UUID).
    ///   - sessionId: The session ID this task belongs to (defaults to a new UUID).
    ///   - data: The data to process.
    ///   - processingType: The type of processing to perform.
    ///   - outputFormat: The format in which to return the processed data.
    ///   - priority: Task priority level (defaults to .medium).
    public init(
        id: UUID = UUID(),
        sessionId: UUID = UUID(),
        data: [String: Any],
        processingType: ProcessingType,
        outputFormat: OutputFormat,
        priority: TaskPriority = .medium
    ) {
        self.id = id
        self.sessionId = sessionId
        self.data = data
        self.processingType = processingType
        self.outputFormat = outputFormat
        self.priority = priority
    }
    
    /// Validate that the task has all required information.
    public func validate() -> Bool {
        return !data.isEmpty
    }
    
    /// Check if the task can be handled by an agent with the given capabilities.
    public func matchesCapabilities(_ capabilities: [AICapability]) -> Bool {
        return capabilities.contains(.dataProcessing)
    }
}

