import Foundation

/// A class that manages contextual information for AI agent interactions.
/// 
/// `AIContext` provides storage and retrieval capabilities for conversation history,
/// metadata, variables, and other contextual information needed during AI agent interactions.
@available(macOS 15.0, *)
public class AIContext {
    
    // MARK: - Properties
    
    /// History of messages in the conversation.
    internal var conversationHistory: [AIMessage] = []
    
    /// Maximum number of messages to keep in the conversation history.
    /// If nil, the history size is unlimited.
    internal var maxHistorySize: Int?
    
    /// Metadata associated with this context.
    private var metadata: [String: Any] = [:]
    
    /// Variables that can be referenced during interactions.
    private var variables: [String: Any] = [:]
    
    /// Additional contextual information.
    private var contextualInfo: [String: Any] = [:]
    
    // MARK: - Initialization
    
    /// Creates a new AI context.
    ///
    /// - Parameters:
    ///   - maxHistorySize: Optional maximum number of messages to keep in history.
    public init(maxHistorySize: Int? = nil) {
        self.maxHistorySize = maxHistorySize
    }
    
    // MARK: - Metadata Methods
    
    /// Set metadata for the context.
    ///
    /// - Parameters:
    ///   - key: The key for the metadata.
    ///   - value: The value to store.
    public func setMetadata(_ value: Any, forKey key: String) {
        metadata[key] = value
    }
    
    /// Get metadata from the context.
    ///
    /// - Parameter key: The key for the metadata.
    /// - Returns: The metadata value, or nil if not found.
    public func getMetadata(forKey key: String) -> Any? {
        return metadata[key]
    }
    
    /// Remove metadata for the specified key.
    ///
    /// - Parameter key: The key for the metadata to remove.
    /// - Returns: The removed value, or nil if the key wasn't found.
    @discardableResult
    public func removeMetadata(forKey key: String) -> Any? {
        return metadata.removeValue(forKey: key)
    }
    
    // MARK: - Variable Methods
    
    /// Set a variable in the context.
    ///
    /// - Parameters:
    ///   - name: The name of the variable.
    ///   - value: The value to store.
    public func setVariable(_ name: String, value: Any) {
        variables[name] = value
    }
    
    /// Get a variable from the context.
    ///
    /// - Parameter name: The name of the variable.
    /// - Returns: The variable value, or nil if not found.
    public func getVariable(_ name: String) -> Any? {
        return variables[name]
    }
    
    /// Remove a variable from the context.
    ///
    /// - Parameter name: The name of the variable to remove.
    /// - Returns: The removed value, or nil if the name wasn't found.
    @discardableResult
    public func removeVariable(_ name: String) -> Any? {
        return variables.removeValue(forKey: name)
    }
    
    // MARK: - Contextual Information Methods
    
    /// Add contextual information.
    ///
    /// - Parameters:
    ///   - info: The information to add.
    ///   - key: The key for the information.
    public func addContextualInfo(_ info: Any, forKey key: String) {
        contextualInfo[key] = info
    }
    
    /// Get contextual information.
    ///
    /// - Parameter key: The key for the information.
    /// - Returns: The contextual information, or nil if not found.
    public func getContextualInfo(forKey key: String) -> Any? {
        return contextualInfo[key]
    }
    
    /// Remove contextual information.
    ///
    /// - Parameter key: The key for the information to remove.
    /// - Returns: The removed information, or nil if the key wasn't found.
    @discardableResult
    public func removeContextualInfo(forKey key: String) -> Any? {
        return contextualInfo.removeValue(forKey: key)
    }
    
    // MARK: - Context Management
    
    /// Clear all information in the context.
    ///
    /// - Parameter keepHistory: Whether to keep the conversation history.
    /// - Returns: `true` if the context was cleared successfully.
    @discardableResult
    public func clearContext(keepHistory: Bool = false) async -> Bool {
        metadata.removeAll()
        variables.removeAll()
        contextualInfo.removeAll()
        
        if !keepHistory {
            conversationHistory.removeAll()
        }
        
        return true
    }
    
    /// Save the current context state to a dictionary.
    ///
    /// - Returns: Dictionary representation of the context.
    /// - Throws: An error if the context cannot be serialized.
    public func save() async throws -> [String: Any] {
        var contextState: [String: Any] = [:]
        
        // Convert conversation history to Data
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let historyData = try encoder.encode(conversationHistory)
        
        contextState["conversationHistory"] = historyData
        contextState["maxHistorySize"] = maxHistorySize
        contextState["metadata"] = metadata
        contextState["variables"] = variables
        contextState["contextualInfo"] = contextualInfo
        
        return contextState
    }
    
    /// Load context state from a dictionary.
    ///
    /// - Parameter state: Dictionary containing the context state.
    /// - Returns: `true` if the context was loaded successfully.
    /// - Throws: An error if the context cannot be deserialized.
    @discardableResult
    public func load(from state: [String: Any]) async throws -> Bool {
        // Load conversation history
        if let historyData = state["conversationHistory"] as? Data {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            conversationHistory = try decoder.decode([AIMessage].self, from: historyData)
        }
        
        // Load other properties
        maxHistorySize = state["maxHistorySize"] as? Int
        
        if let loadedMetadata = state["metadata"] as? [String: Any] {
            metadata = loadedMetadata
        }
        
        if let loadedVariables = state["variables"] as? [String: Any] {
            variables = loadedVariables
        }
        
        if let loadedContextualInfo = state["contextualInfo"] as? [String: Any] {
            contextualInfo = loadedContextualInfo
        }
        
        return true
    }
}

//
//  AIContext.swift
//  AICollaborator
//
//  Created: 2025-04-10
//

import Foundation
import AsyncAlgorithms

/// Manages context for AI collaboration sessions
public actor AIContext {
    // MARK: - Properties
    
    /// Unique identifier for this context
    public let contextId: UUID
    
    /// When this context was created
    public let createdAt: Date
    
    /// When this context was last accessed
    private(set) public var lastAccessedAt: Date
    
    /// Maximum size of history (number of items)
    private(set) public var maxHistorySize: Int
    
    /// Task history
    private var taskHistory: [UUID: AITask] = [:]
    
    /// Result history
    private var resultHistory: [UUID: AITaskResult] = [:]
    
    /// Conversation history indexed by conversation ID
    private var conversationHistory: [String: [ConversationMessage]] = [:]
    
    /// Global context values available to all tasks
    private var globalContext: [String: Any] = [:]
    
    /// Task-specific context values
    private var taskContext: [UUID: [String: Any]] = [:]
    
    /// Usage metrics
    private var metrics: ContextMetrics = ContextMetrics()
    
    // MARK: - Initialization
    
    /// Initialize a new context
    /// - Parameters:
    ///   - contextId: Optional context ID, will generate a new one if nil
    ///   - maxHistorySize: Maximum history size before pruning
    public init(contextId: UUID? = nil, maxHistorySize: Int = 100) {
        self.contextId = contextId ?? UUID()
        self.createdAt = Date()
        self.lastAccessedAt = self.createdAt
        self.maxHistorySize = maxHistorySize
    }
    
    // MARK: - Task Management
    
    /// Record a task in the context
    /// - Parameter task: The task to record
    public func recordTask(_ task: AITask) {
        updateLastAccessed()
        taskHistory[task.taskId] = task
        metrics.incrementTaskCount()
        enforceHistorySizeLimit()
    }
    
    /// Record a result for a task
    /// - Parameters:
    ///   - result: The result to record
    ///   - task: The associated task
    public func recordResult(_ result: AITaskResult, for task: AITask) {
        updateLastAccessed()
        resultHistory[result.resultId] = result
        metrics.incrementResultCount()
        enforceHistorySizeLimit()
    }
    
    /// Get a task by ID
    /// - Parameter taskId: The task ID to retrieve
    /// - Returns: The task if found
    public func getTask(with taskId: UUID) -> AITask? {
        updateLastAccessed()
        return taskHistory[taskId]
    }
    
    /// Get a result by ID
    /// - Parameter resultId: The result ID to retrieve
    /// - Returns: The result if found
    public func getResult(with resultId: UUID) -> AITaskResult? {
        updateLastAccessed()
        return resultHistory[resultId]
    }
    
    /// Get all tasks
    /// - Returns: Array of all tasks
    public func getAllTasks() -> [AITask] {
        updateLastAccessed()
        return Array(taskHistory.values)
    }
    
    /// Get tasks filtered by a predicate
    /// - Parameter predicate: The filter predicate
    /// - Returns: Filtered tasks
    public func getTasks(where predicate: (AITask) -> Bool) -> [AITask] {
        updateLastAccessed()
        return taskHistory.values.filter(predicate)
    }
    
    /// Clear task history
    public func clearTaskHistory() {
        updateLastAccessed()
        taskHistory.removeAll()
        resultHistory.removeAll()
    }
    
    // MARK: - Conversation Management
    
    /// Add a message to a conversation
    /// - Parameters:
    ///   - message: The message to add
    ///   - conversationId: The conversation ID
    public func addMessage(_ message: ConversationMessage, to conversationId: String) {
        updateLastAccessed()
        var messages = conversationHistory[conversationId] ?? []
        messages.append(message)
        conversationHistory[conversationId] = messages
        metrics.incrementMessageCount()
    }
    
    /// Get all messages for a conversation
    /// - Parameter conversationId: The conversation ID
    /// - Returns: Array of messages
    public func getMessages(for conversationId: String) -> [ConversationMessage] {
        updateLastAccessed()
        return conversationHistory[conversationId] ?? []
    }
    
    /// Get recent messages for a conversation
    /// - Parameters:
    ///   - conversationId: The conversation ID
    ///   - limit: Maximum number of messages to return
    /// - Returns: Array of recent messages
    public func getRecentMessages(for conversationId: String, limit: Int) -> [ConversationMessage] {
        updateLastAccessed()
        let messages = conversationHistory[conversationId] ?? []
        if messages.count <= limit {
            return messages
        }
        return Array(messages.suffix(limit))
    }
    
    /// Clear conversation history
    /// - Parameter conversationId: The conversation ID to clear
    public func clearConversation(for conversationId: String) {
        updateLastAccessed()
        conversationHistory.removeValue(forKey: conversationId)
    }
    
    // MARK: - Context Value Management
    
    /// Set a global context value
    /// - Parameters:
    ///   - value: The value to set
    ///   - key: The key to associate with the value
    public func setGlobalValue(_ value: Any, for key: String) {
        updateLastAccessed()
        globalContext[key] = value
    }
    
    /// Get a global context value
    /// - Parameter key: The key to retrieve
    /// - Returns: The value if found
    public func getGlobalValue(for key: String) -> Any? {
        updateLastAccessed()
        return globalContext[key]
    }
    
    /// Set a task-specific context value
    /// - Parameters:
    ///   - value: The value to set
    ///   - key: The key to associate with the value
    ///   - taskId: The associated task ID
    public func setTaskValue(_ value: Any, for key: String, taskId: UUID) {
        updateLastAccessed()
        var context = taskContext[taskId] ?? [:]
        context[key] = value
        taskContext[taskId] = context
    }
    
    /// Get a task-specific context value
    /// - Parameters:
    ///   - key: The key to retrieve
    ///   - taskId: The associated task ID
    /// - Returns: The value if found
    public func getTaskValue(for key: String, taskId: UUID) -> Any? {
        updateLastAccessed()
        return taskContext[taskId]?[key]
    }
    
    /// Remove a global context value
    /// - Parameter key: The key to remove
    public func removeGlobalValue(for key: String) {
        updateLastAccessed()
        globalContext.removeValue(forKey: key)
    }
    
    /// Remove a task-specific context value
    /// - Parameters:
    ///   - key: The key to remove
    ///   - taskId: The associated task ID
    public func removeTaskValue(for key: String, taskId: UUID) {
        updateLastAccessed()
        taskContext[taskId]?.removeValue(forKey: key)
    }
    
    // MARK: - Serialization
    
    /// Export the context to a portable format
    /// - Returns: Serialized context data
    public func export() throws -> Data {
        updateLastAccessed()
        
        // Create serializable representation
        let export = ContextExport(
            contextId: contextId,
            createdAt: createdAt,
            lastAccessedAt: lastAccessedAt,
            maxHistorySize: maxHistorySize,
            taskHistory: taskHistory.mapValues { SerializableTask(from: $0) },
            resultHistory: resultHistory.mapValues { SerializableTaskResult(from: $0) },
            conversationHistory: conversationHistory,
            globalContext: globalContext.compactMapValues { value in
                if let data = value as? Data { return data }
                if let string = value as? String { return string }
                if let number = value as? NSNumber { return number }
                if let date = value as? Date { return date }
                if let codable = value as? AnyEncodable { return codable }
                return nil
            },
            metrics: metrics
        )
        
        // Encode to JSON
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(export)
    }
    
    /// Import context from serialized data
    /// - Parameter data: Serialized context data
    /// - Returns: New context instance
    public static func `import`(from data: Data) throws -> AIContext {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let imported = try decoder.decode(ContextExport.self, from: data)
        
        let context = AIContext(
            contextId: imported.contextId,
            maxHistorySize: imported.maxHistorySize
        )
        
        // Set properties from import
        await context.setImportedProperties(imported)
        
        return context
    }
    
    /// Set properties from an imported context
    /// - Parameter imported: The imported context data
    private func setImportedProperties(_ imported: ContextExport) {
        // This would deserialize the task history, result history, etc.
        // For simplicity, just importing the conversation history as an example
        self.conversationHistory = imported.conversationHistory
        self.metrics = imported.metrics
        self.lastAccessedAt = imported.lastAccessedAt
    }
    
    // MARK: - Memory Management
    
    /// Set the maximum history size
    /// - Parameter size: New maximum size
    public func setMaxHistorySize(_ size: Int) {
        self.maxHistorySize = size
        enforceHistorySizeLimit()
    }
    
    /// Enforce the history size limit by removing oldest entries
    private func enforceHistorySizeLimit() {
        // Enforce task history limit
        if taskHistory.count > maxHistorySize {
            let sortedTasks = taskHistory.values.sorted { $0.createdAt < $1.createdAt }
            let excessCount = taskHistory.count - maxHistorySize
            
            for i in 0..<excessCount {
                let taskToRemove = sortedTasks[i]
                taskHistory.removeValue(forKey: taskToRemove.taskId)
                
                // Also clean up associated task context
                taskContext.removeValue(forKey: taskToRemove.taskId)
            }
        }
        
        // Enforce result history limit
        if resultHistory.count > maxHistorySize {
            let sortedResults = resultHistory.values.sorted { $0.completedAt < $1.completedAt }
            let excessCount = resultHistory.count - maxHistorySize
            
            for i in 0..<excessCount {
                let resultToRemove = sortedResults[i]
                resultHistory.removeValue(forKey: resultToRemove.resultId)
            }
        }
        
        // Enforce conversation history limits
        for (conversationId, messages) in conversationHistory {
            if messages.count > maxHistorySize {
                let trimmedMessages = Array(messages.suffix(maxHistorySize))
                conversationHistory[conversationId] = trimmedMessages
            }
        }
    }
    
    /// Clear all data in the context
    public func clear() {
        taskHistory.removeAll()
        resultHistory.removeAll()
        conversationHistory.removeAll()
        globalContext.removeAll()
        taskContext.removeAll()
        metrics = ContextMetrics()
    }
    
    // MARK: - Utilities
    
    /// Update the last accessed timestamp
    private func updateLastAccessed() {
        lastAccessedAt = Date()
    }
    
    /// Get usage metrics for this context
    public func getMetrics() -> ContextMetrics {
        updateLastAccessed()
        return metrics
    }
}

// MARK: - Supporting Types

/// Metrics about context usage
public struct ContextMetrics: Codable {
    /// Number of tasks recorded
    public private(set) var taskCount: Int = 0
    
    /// Number of results recorded
    public private(set) var resultCount: Int = 0
    
    /// Number of conversation messages
    public private(set) var messageCount: Int = 0
    
    /// Context creation time
    public private(set) var creationTime: Date = Date()
    
    /// Increment task count
    mutating func incrementTaskCount() {
        taskCount += 1
    }
    
    /// Increment result count
    mutating func incrementResultCount() {
        resultCount += 1
    }
    
    /// Increment message count
    mutating func incrementMessageCount() {
        messageCount += 1
    }
}

/// Exportable representation of context
private struct ContextExport: Codable {
    let contextId: UUID
    let createdAt: Date
    let lastAccessedAt: Date
    let maxHistorySize: Int
    let taskHistory: [UUID: SerializableTask]
    let resultHistory: [UUID: SerializableTaskResult]
    let conversationHistory: [String: [ConversationMessage]]
    let globalContext: [String: Any]
    let metrics: ContextMetrics
    
    // Custom coding keys to handle types that aren't directly Codable
    private enum CodingKeys: String, CodingKey {
        case contextId, createdAt, lastAccessedAt, maxHistorySize
        case taskHistory, resultHistory, conversationHistory
        case globalContext, metrics
    }
    
    // Custom encoding for Any values
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(contextId, forKey: .contextId)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(lastAccessedAt, forKey: .lastAccessedAt)
        try container.encode(maxHistorySize, forKey: .maxHistorySize)
        try container.encode(taskHistory, forKey: .taskHistory)
        try container.encode(resultHistory, forKey: .resultHistory)
        try container.encode(conversationHistory, forKey: .conversationHistory)
        try container.encode(metrics, forKey: .metrics)
        
        // Handle the globalContext specially since it contains Any values
        let encodableContext = globalContext.compactMapValues { $0 as? Encodable }
        try container.encode(encodableContext, forKey: .globalContext)
    }
}

/// Serializable representation of a task
private struct SerializableTask: Codable {
    let taskId: UUID
    let description: String
    let query: String
    let createdAt: Date
    let updatedAt: Date
    
    init(from task: AITask) {
        self.taskId = task.taskId
        self.description = task.description
        self.query = task.query
        self.createdAt = task.createdAt
        self.updatedAt = task.updatedAt
    }
}

/// Serializable representation of a task result
private struct SerializableTaskResult: Codable {
    let resultId: UUID
    let taskId: UUID
    let status: TaskResultStatus
    let completedAt: Date
    
    init(from result: AITaskResult) {

