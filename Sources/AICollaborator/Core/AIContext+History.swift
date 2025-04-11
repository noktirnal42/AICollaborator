import Foundation

/// Extension providing history management methods for AIContext.
@available(macOS 15.0, *)
extension AIContext {
    
    // MARK: - Conversation History Methods
    
    /// Add a message to the conversation history.
    ///
    /// - Parameter message: The message to add.
    /// - Returns: `true` if the message was added successfully.
    @discardableResult
    public func addMessage(_ message: AIMessage) async -> Bool {
        conversationHistory.append(message)
        
        if let maxSize = maxHistorySize, conversationHistory.count > maxSize {
            conversationHistory.removeFirst(conversationHistory.count - maxSize)
        }
        
        return true
    }
    
    /// Add a message to the conversation history with the given role and content.
    ///
    /// - Parameters:
    ///   - role: The role of the message sender.
    ///   - content: The content of the message.
    ///
    /// - Returns: `true` if the message was added successfully.
    @discardableResult
    public func addMessage(role: String, content: String) async -> Bool {
        let message = AIMessage(role: role, content: content)
        return await addMessage(message)
    }
    
    /// Get the conversation history.
    ///
    /// - Parameter limit: Optional maximum number of messages to return.
    /// - Returns: Array of messages in the conversation history.
    public func getConversationHistory(limit: Int? = nil) async -> [AIMessage] {
        if let limit = limit, limit < conversationHistory.count {
            return Array(conversationHistory.suffix(limit))
        }
        
        return conversationHistory
    }
    
    /// Clear the conversation history.
    ///
    /// - Returns: `true` if the history was cleared successfully.
    @discardableResult
    public func clearConversationHistory() async -> Bool {
        conversationHistory.removeAll()
        return true
    }
}

