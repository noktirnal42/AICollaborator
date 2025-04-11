import Foundation

/// Protocol defining the interface for AI agents in the AICollaborator framework.
public protocol AICollaboratorAgent {
    /// Process a task and return the result
    /// - Parameter task: The task to be processed
    /// - Returns: The result of the task execution
    func processTask(_ task: AITask) -> AITaskResult
    
    /// Provide the capabilities supported by this agent
    /// - Returns: Array of capabilities supported by this agent
    func provideCapabilities() -> [AICapability]
}

