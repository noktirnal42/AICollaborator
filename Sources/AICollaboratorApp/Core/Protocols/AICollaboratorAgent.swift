import Foundation

/// Protocol defining the interface for AI agents to integrate with the collaborator framework.
///
/// The `AICollaboratorAgent` protocol is the primary means by which AI agents
/// connect to and interact with the AICollaborator framework. It defines methods
/// for processing tasks and providing capabilities.
///
/// ## Implementation Example
///
/// ```swift
/// struct MyAIAgent: AICollaboratorAgent {
///     func processTask(_ task: AITask) -> AITaskResult {
///         // Process the task and generate a result
///         return AITaskResult(
///             id: task.id,
///             status: .completed,
///             output: "Task completed successfully!",
///             timestamp: Date()
///         )
///     }
///
///     func provideCapabilities() -> [AICapability] {
///         return [.codeGeneration, .textAnalysis]
///     }
///
///     func provideMetadata() -> AIAgentMetadata {
///         return AIAgentMetadata(
///             name: "My Custom Agent",
///             version: "1.0.0",
///             description: "A custom agent for code generation and text analysis"
///         )
///     }
/// }
/// ```
public protocol AICollaboratorAgent {
    
    /// Process a task and return a result.
    ///
    /// This method is called by the AICollaborator when a task is assigned to this agent.
    /// The agent should process the task according to its capabilities and return a result.
    ///
    /// - Parameter task: The task to process
    /// - Returns: The result of processing the task
    func processTask(_ task: AITask) -> AITaskResult
    
    /// Provide a list of the agent's capabilities.
    ///
    /// This method is used by the AICollaborator to determine which agents can handle
    /// specific tasks. The agent should return a list of its capabilities.
    ///
    /// - Returns: A list of the agent's capabilities
    func provideCapabilities() -> [AICapability]
    
    /// Provide metadata about the agent.
    ///
    /// This method is optional and provides additional information about the agent,
    /// such as its name, version, and description.
    ///
    /// - Returns: Metadata about the agent
    func provideMetadata() -> AIAgentMetadata
    
    /// Handle an update to the context.
    ///
    /// This method is optional and is called when there are updates to the context
    /// that the agent might need to be aware of. Implementing this method allows
    /// the agent to receive context updates even if it doesn't directly conform
    /// to the `ContextAware` protocol.
    ///
    /// - Parameter context: The updated context
    func handleContextUpdate(_ context: AIContext)
}

// Default implementations for optional methods
public extension AICollaboratorAgent {
    
    /// Default implementation for providing metadata.
    ///
    /// By default, this returns a generic metadata object with minimal information.
    /// Agents should override this to provide more specific information.
    func provideMetadata() -> AIAgentMetadata {
        return AIAgentMet

