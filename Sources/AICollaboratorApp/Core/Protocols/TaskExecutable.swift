import Foundation

/// Protocol defining the interface for executable tasks in the AICollaborator framework.
public protocol TaskExecutable {
    /// Unique identifier for the task
    var id: UUID { get }
    
    /// Description of the task
    var description: String { get }
    
    /// Current status of the task
    var status: TaskStatus { get set }
    
    /// Execute the task using the provided agent
    /// - Parameter agent: The agent that will execute the task
    /// - Returns: The result of the task execution
    func execute(using agent: AICollaboratorAgent) -> AITaskResult
    
    /// Validate the result of the task execution
    /// - Parameter result: The result to validate
    /// - Returns: Boolean indicating whether the result is valid
    func validateResult(_ result: AITaskResult) -> Bool
}

/// Represents the current status of a task
public enum TaskStatus {
    case pending
    case inProgress
    case completed
    case failed(Error)
    case cancelled
}

