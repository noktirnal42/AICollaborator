import Foundation

/// Extension providing conversation history management for AIContext.
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
        
        // Apply history size limits if configured
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
    
    /// Get messages from the conversation history with the specified role.
    ///
    /// - Parameters:
    ///   - role: The role to filter by.
    ///   - limit: Optional maximum number of messages to return.
    ///
    /// - Returns: Array of messages with the specified role.
    public func getMessages(withRole role: String, limit: Int? = nil) async -> [AIMessage] {
        let filteredMessages = conversationHistory.filter { $0.role == role }
        
        if let limit = limit, limit < filteredMessages.count {
            return Array(filteredMessages.suffix(limit))
        }
        
        return filteredMessages
    }
    
    /// Search for messages in the conversation history containing the given text.
    ///
    /// - Parameters:
    ///   - searchText: The text to search for.
    ///   - inRole: Optional role to limit the search to.
    ///
    /// - Returns: Array of messages containing the search text.
    public func searchHistory(for searchText: String, inRole: String? = nil) async -> [AIMessage] {
        let filteredMessages = conversationHistory.filter { message in
            let roleMatches = inRole == nil ? true : message.role == inRole
            let contentMatches = message.content.localizedCaseInsensitiveContains(searchText)
            return roleMatches && contentMatches
        }
        
        return filteredMessages
    }
    
    /// Get messages from the conversation history within a time range.
    ///
    /// - Parameters:
    ///   - startDate: The start date of the range.
    ///   - endDate: The end date of the range (defaults to now).
    ///
    /// - Returns: Array of messages within the specified time range.
    public func getMessages(from startDate: Date, to endDate: Date = Date()) async -> [AIMessage] {
        return conversationHistory.filter { message in
            return message.timestamp >= startDate && message.timestamp <= endDate
        }
    }
    
    /// Clear the conversation history.
    ///
    /// - Returns: `true` if the history was cleared successfully.
    @discardableResult
    public func clearConversationHistory() async -> Bool {
        conversationHistory.removeAll()
        return true
    }
    
    /// Export the conversation history as JSON data.
    ///
    /// - Parameter prettyPrinted: Whether to format the JSON for readability.
    /// - Returns: The conversation history as JSON data.
    /// - Throws: Error if encoding fails.
    public func exportHistory(prettyPrinted: Bool = false) async throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        if prettyPrinted {
            encoder.outputFormatting = .prettyPrinted
        }
        
        return try encoder.encode(conversationHistory)
    }
    
    /// Import conversation history from JSON data.
    ///
    /// - Parameters:
    ///   - data: The JSON data containing conversation history.
    ///   - append: Whether to append to existing history (defaults to false).
    ///
    /// - Returns: `true` if the history was imported successfully.
    /// - Throws: Error if decoding fails.
    @discardableResult
    public func importHistory(from data: Data, append: Bool = false) async throws -> Bool {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let importedHistory = try decoder.decode([AIMessage].self, from: data)
        
        if append {
            conversationHistory.append(contentsOf: importedHistory)
        } else {
            conversationHistory = importedHistory
        }
        
        // Apply history size limits if configured
        if let maxSize = maxHistorySize, conversationHistory.count > maxSize {
            conversationHistory.removeFirst(conversationHistory.count - maxSize)
        }
        
        return true
    }
    
    /// Set the maximum number of messages to keep in history.
    ///
    /// - Parameter size: The maximum number of messages to keep, or nil for unlimited.
    /// - Returns: `true` if the history size was set successfully.
    @discardableResult
    public func setMaxHistorySize(_ size: Int?) async -> Bool {
        maxHistorySize = size
        
        // Apply the new limit if needed
        if let maxSize = size, conversationHistory.count > maxSize {
            conversationHistory.removeFirst(conversationHistory.count - maxSize)
        }
        
        return true
    }
}
