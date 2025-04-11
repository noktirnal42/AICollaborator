import Foundation

/// Manages contextual information for AI agent interactions.
///
/// `AIContext` provides a thread-safe storage mechanism for maintaining state
/// across multiple task executions. It includes features for tracking conversation
/// history, managing session data, and persisting context between interactions.
///
/// ## Overview
///
/// Context management is critical for maintaining continuity in AI agent interactions.
/// `AIContext` provides a structured way to store and retrieve information, with support
/// for type safety, versioning, and change tracking.
///
/// ## Example Usage
///
/// ```swift
/// // Create a context for a session
/// let context = AIContext(sessionId: UUID())
///
/// // Store values with type safety
/// try await context.store("username", value: "user123")
/// try await context.store("isAdmin", value: true)
/// try await context.store("loginCount", value: 5)
///
/// // Retrieve values with type casting
/// if let username = try await context.retrieve("username") as? String {
///     print("Hello, \(username)!")
/// }
///
/// // Update values
/// try await context.update("loginCount", value: 6)
///
/// // Get conversation history
/// let history = try await context.getConversationHistory()
/// ```
///
/// - Note: AIContext uses Swift's actor system to ensure thread safety.
@available(macOS 15.0, *)
public actor AIContext {
    
    /// A message in the conversation history.
    public struct AIMessage: Codable, Identifiable, Equatable {
        /// Unique identifier for the message.
        public let id: UUID
        
        /// The role of the message sender (e.g., "user", "assistant").
        public let role: String
        
        /// The content of the message.
        public let content: String
        
        /// Timestamp when the message was created.
        public let timestamp: Date
        
        /// Initialize a new message.
        ///
        /// - Parameters:
        ///   - id: Unique identifier (defaults to a new UUID).
        ///   - role: Role of the message sender.
        ///   - content: Content of the message.
        ///   - timestamp: Timestamp when the message was created (defaults to now).
        public init(
            id: UUID = UUID(),
            role: String,
            content: String,
            timestamp: Date = Date()
        ) {
            self.id = id
            self.role = role
            self.content = content
            self.timestamp = timestamp
        }
        
        public static func == (lhs: AIContext.AIMessage, rhs: AIContext.AIMessage) -> Bool {
            return lhs.id == rhs.id
        }
    }
    
    /// Entry representing a value stored in the context.
    private struct ContextEntry {
        /// The stored value.
        let value: Any
        
        /// The type of the stored value.
        let type: Any.Type
        
        /// Timestamp when the value was last updated.
        let timestamp: Date
        
        /// Version number, incremented on each update.
        let version: Int
    }
    
    /// Notification that can be sent when the context changes.
    public struct ContextChangeNotification {
        /// The key that changed.
        public let key: String
        
        /// The old value, if any.
        public let oldValue: Any?
        
        /// The new value.
        public let newValue: Any
        
        /// Timestamp when the change occurred.
        public let timestamp: Date
        
        /// The session ID for the context.
        public let sessionId: UUID
    }
    
    /// Delegate protocol for receiving context change notifications.
    public protocol ContextChangeDelegate: AnyObject {
        /// Called when a value in the context changes.
        ///
        /// - Parameter notification: Information about the change.
        func contextDidChange(_ notification: ContextChangeNotification)
    }
    
    /// Unique identifier for the session this context belongs to.
    public let sessionId: UUID
    
    /// Dictionary storing the context entries.
    private var storage: [String: ContextEntry] = [:]
    
    /// Conversation history as an array of messages.
    private var conversationHistory: [AIMessage] = []
    
    /// Optional maximum number of messages to keep in history.
    private var maxHistorySize: Int?
    
    /// Set of delegates to notify on context changes.
    private var delegates: [ObjectIdentifier: () -> ContextChangeDelegate?] = [:]
    
    /// Initialize a new context for a session.
    ///
    /// - Parameters:
    ///   - sessionId: Unique identifier for the session (defaults to a new UUID).
    ///   - maxHistorySize: Optional maximum number of messages to keep in history.
    public init(sessionId: UUID = UUID(), maxHistorySize: Int? = nil) {
        self.sessionId = sessionId
        self.maxHistorySize = maxHistorySize
    }
    
    // MARK: - Storage Methods
    
    /// Store a value in the context.
    ///
    /// This method stores a value with the given key. If a value already exists
    /// for the key, a `valueAlreadyExists` error is thrown.
    ///
    /// - Parameters:
    ///   - key: The key to store the value under.
    ///   - value: The value to store.
    ///
    /// - Returns: `true` if the value was stored successfully.
    /// - Throws: `AIError.valueAlreadyExists` if a value already exists for the key.
    @discardableResult
    public func store<T>(_ key: String, value: T) async throws -> Bool {
        guard storage[key] == nil else {
            throw AIError.valueAlreadyExists
        }
        
        let entry = ContextEntry(
            value: value,
            type: T.self,
            timestamp: Date(),
            version: 1
        )
        
        storage[key] = entry
        notifyDelegates(key: key, oldValue: nil, newValue: value)
        
        return true
    }
    
    /// Retrieve a value from the context.
    ///
    /// This method retrieves a value for the given key. If the value doesn't exist,
    /// a `valueNotFound` error is thrown.
    ///
    /// - Parameter key: The key to retrieve the value for.
    /// - Returns: The stored value.
    /// - Throws: `AIError.valueNotFound` if no value exists for the key.
    public func retrieve(_ key: String) async throws -> Any {
        guard let entry = storage[key] else {
            throw AIError.valueNotFound
        }
        
        return entry.value
    }
    
    /// Retrieve a value with type safety.
    ///
    /// This method retrieves a value for the given key and attempts to cast it to the specified type.
    /// If the value doesn't exist or can't be cast to the specified type, an error is thrown.
    ///
    /// - Parameters:
    ///   - key: The key to retrieve the value for.
    ///   - type: The type to cast the value to.
    ///
    /// - Returns: The stored value cast to the specified type.
    /// - Throws: `AIError.valueNotFound` if no value exists for the key.
    ///           `AIError.typeMismatch` if the value can't be cast to the specified type.
    public func retrieve<T>(_ key: String, as type: T.Type) async throws -> T {
        guard let entry = storage[key] else {
            throw AIError.valueNotFound
        }
        
        guard let value = entry.value as? T else {
            throw AIError.typeMismatch
        }
        
        return value
    }
    
    /// Update an existing value in the context.
    ///
    /// This method updates a value for the given key. If the value doesn't exist,
    /// a `valueNotFound` error is thrown.
    ///
    /// - Parameters:
    ///   - key: The key to update the value for.
    ///   - value: The new value.
    ///
    /// - Returns: `true` if the value was updated successfully.
    /// - Throws: `AIError.valueNotFound` if no value exists for the key.
    ///           `AIError.typeMismatch` if the new value has a different type than the stored value.
    @discardableResult
    public func update<T>(_ key: String, value: T) async throws -> Bool {
        guard let existingEntry = storage[key] else {
            throw AIError.valueNotFound
        }
        
        guard type(of: existingEntry.value) == T.self else {
            throw AIError.typeMismatch
        }
        
        let oldValue = existingEntry.value
        
        let entry = ContextEntry(
            value: value,
            type: T.self,
            timestamp: Date(),
            version: existingEntry.version + 1
        )
        
        storage[key] = entry
        notifyDelegates(key: key, oldValue: oldValue, newValue: value)
        
        return true
    }
    
    /// Store or update a value in the context.
    ///
    /// This method stores a value if it doesn't exist, or updates it if it does exist.
    ///
    /// - Parameters:
    ///   - key: The key to store or update the value for.
    ///   - value: The value to store or update.
    ///
    /// - Returns: `true` if the value was stored or updated successfully.
    @discardableResult
    public func storeOrUpdate<T>(_ key: String, value: T) async -> Bool {
        do {
            if storage[key] != nil {
                return try await update(key, value: value)
            } else {
                return try await store(key, value: value)
            }
        } catch {
            return false
        }
    }
    
    /// Remove a value from the context.
    ///
    /// This method removes a value for the given key. If the value doesn't exist,
    /// a `valueNotFound` error is thrown.
    ///
    /// - Parameter key: The key to remove the value for.
    /// - Returns: The removed value.
    /// - Throws: `AIError.valueNotFound` if no value exists for the key.
    @discardableResult
    public func remove(_ key: String) async throws -> Any {
        guard let entry = storage[key] else {
            throw AIError.valueNotFound
        }
        
        let value = entry.value
        storage.removeValue(forKey: key)
        notifyDelegates(key: key, oldValue: value, newValue: NSNull())
        
        return value
    }
    
    /// Check if a value exists for the given key.
    ///
    /// - Parameter key: The key to check.
    /// - Returns: `true` if a value exists for the key, `false` otherwise.
    public func contains(_ key: String) async -> Bool {
        return storage[key] != nil
    }
    
    /// Get metadata for a stored value.
    ///
    /// This method retrieves metadata for a value, including its type, timestamp, and version.
    ///
    /// - Parameter key: The key to get metadata for.
    /// - Returns: A tuple containing the type, timestamp, and version.
    /// - Throws: `AIError.valueNotFound` if no value exists for the key.
    public func getMetadata(_ key: String) async throws -> (type: Any.Type, timestamp: Date, version: Int) {
        guard let entry = storage[key] else {
            throw AIError.valueNotFound
        }
        
        return (entry.type, entry.timestamp, entry.version)
    }
    
    /// Get all available keys in the context.
    ///
    /// - Returns: Array of all keys in the context.
    public func availableKeys() async -> [String] {
        return Array(storage.keys)
    }
    
    /// Clear all values from the context.
    ///
    /// - Parameter keys: Optional array of keys to clear. If `nil`, all values are cleared.
    /// - Returns: `true` if the values were cleared successfully.
    @discardableResult
    public func clear(keys: [String]? = nil) async -> Bool {
        if let keys = keys {
            for key in keys {
                storage.removeValue(forKey: key)
            }
        } else {
            storage.removeAll()
        }
        
        return true
    }
    
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
    
    // MARK: - Delegate Management
    
    /// Add a delegate to receive context change notifications.
    ///
    /// - Parameter delegate: The delegate to add.
    public func addDelegate(_ delegate: ContextChangeDelegate) async {
        let id = ObjectIdentifier(delegate as AnyObject)
        delegates[id] = { [weak delegate] in delegate }
    }
    
    /// Remove a delegate.
    ///
    /// - Parameter delegate: The delegate to remove.
    public func removeDelegate(_ delegate: ContextChangeDelegate) async {
        let id = ObjectIdentifier(delegate as AnyObject)
        delegates.removeValue(forKey: id)
    }
    
    /// Notify delegates of a context change.
    ///
    /// - Parameters:
    ///   - key: The key that changed.
    ///   - oldValue: The old value, if any.
    ///   - newValue: The new value.
    private func notifyDelegates(key: String, oldValue: Any?, newValue: Any) {
        let notification = ContextChangeNotification(
            key: key,
            oldValue: oldValue,
            newValue: newValue,
            timestamp: Date(),
            sessionId: sessionId
        )
        
        for (id, weakDelegate) in delegates {
            guard let delegate = weakDelegate() else {
                delegates.removeValue(forKey: id)
                continue
            }
            
            Task {
                delegate.contextDidChange(notification)
            }
        }
    }
    
    // MARK: - Serialization and Persistence
    
    /// Serialize the context to a dictionary for persistence.
    ///
    /// - Returns: A dictionary representation of the context.
    public func serialize() async -> [String: Any] {
        var result: [String: Any] = [
            "sessionId": sessionId.uuidString,
            "timestamp": Date()
        ]
        
        var serializableStorage: [String: [String: Any]] = [:]
        
        for (key, entry) in storage {
            if let value = entry.value as? Codable {
                do {
                    let data = try JSONEncoder().encode(value)
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        serializableStorage[key] = [
                            "value": json,
                            "type": String(describing: entry.type),
                            "timestamp": entry.timestamp,
                            "version": entry.version
                        ]
                    }
                } catch {
                    // Skip non-serializable values
                }
            }
        }
        
        result["storage"] = serializableStorage
        
        do {
            let historyData = try JSONEncoder().encode(conversationHistory)
            result["conversationHistory"] = historyData
        } catch {
            // Skip conversation history if it can't be serialized
        }
        
        return result
    }
    
    /// Load context from a serialized dictionary.
    ///
    /// - Parameter dictionary: The serialized context.
    /// - Returns: `true` if the context was loaded successfully.
    @discardableResult
    public func load(from dictionary: [String: Any]) async -> Bool {
        // Clear existing data
        storage.removeAll()
        conversationHistory.removeAll()
        
        // Load serialized storage
        if let serializableStorage = dictionary["storage"] as? [String: [String: Any]] {
            for (key, entryDict) in serializableStorage {
                if let json = entryDict["value"] as? [String: Any],
                   let typeString = entryDict["type"] as? String,
                   let timestamp = entryDict["timestamp"] as? Date,
                   let version = entryDict["version"] as? Int {
                    
                    // This is a simplified version. In a real implementation,
                    // you would need to handle deserialization based on the type.
                    storage[key] = ContextEntry(
                        value: json,
                        type: NSObject.self,
                        timestamp: timestamp,
                        version: version
                    )
                }
            }
        }
        
        // Load conversation history
        if let historyData = dictionary["conversationHistory"] as? Data {
            do {
                conversationHistory = try JSONDecoder().decode([AIMessage].self, from: historyData)
            } catch {
                // Handle error
            }
        }
        
        return true
    }
}
