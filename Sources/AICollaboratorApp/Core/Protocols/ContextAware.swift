import Foundation

/// Protocol defining the interface for context-aware components in the AICollaborator framework.
public protocol ContextAware {
    /// Access the context associated with this component
    /// - Returns: The current context
    func getContext() -> AIContext
    
    /// Update the context with new information
    /// - Parameters:
    ///   - key: The key to store the information under
    ///   - value: The information to store
    func updateContext(key: String, value: Any)
    
    /// Clear specific information from the context
    /// - Parameter key: The key to clear
    func clearContextValue(key: String)
    
    /// Determine if this component should process based on the current context
    /// - Returns: Boolean indicating whether this component should proceed with processing
    func shouldProcessWithCurrentContext() -> Bool
}

