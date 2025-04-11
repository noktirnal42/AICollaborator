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
    internal struct ContextEntry {
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
    
    /// Configuration options for the context.
    public struct Configuration {
        /// The maximum number of messages to keep in history.
        public let maxHistorySize: Int?
        
        /// Whether to enable automatic state persistence.
        public let enableAutoPersistence: Bool
        
        /// How often to automatically persist state (in seconds).
        public let autoPersistenceInterval: TimeInterval?
        
        /// Initialize a new configuration.
        ///
        /// - Parameters:
        ///   - maxHistorySize: The maximum number of messages to keep in history.
        ///   - enableAutoPersistence: Whether to enable automatic state persistence.
        ///   - autoPersistenceInterval: How often to automatically persist state.
        public init(
            maxHistorySize: Int? = 100,
            enableAutoPersistence: Bool = false,
            autoPersistenceInterval: TimeInterval? = 300 // 5 minutes
        ) {
            self.maxHistorySize = maxHistorySize
            self.enableAutoPersistence = enableAutoPersistence
            self.autoPersistenceInterval = autoPersistenceInterval
        }
        
        /// Default configuration.
        public static let `default` = Configuration()
    }
    
    // MARK: - Properties
    
    /// Unique identifier for the session this context belongs to.
    public let sessionId: UUID
    
    /// Dictionary storing the context entries.
    internal var storage: [String: ContextEntry] = [:]
    
    /// Conversation history as an array of messages.
    internal var conversationHistory: [AIMessage] = []
    
    /// Optional maximum number of messages to keep in history.
    internal var maxHistorySize: Int?
    
    /// Set of delegates to notify on context changes.
    internal var delegates: [ObjectIdentifier: () -> ContextChangeDelegate?] = [:]
    
    /// Configuration for the context.
    public let configuration: Configuration
    
    // MARK: - Initialization
    
    /// Initialize a new context for a session.
    ///
    /// - Parameters:
    ///   - sessionId: Unique identifier for the session (defaults to a new UUID).
    ///   - configuration: Configuration options for the context.
    public init(
        sessionId: UUID = UUID(),
        configuration: Configuration = .default
    ) {
        self.sessionId = sessionId
        self.configuration = configuration
        self.maxHistorySize = configuration.maxHistorySize
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
    internal func notifyDelegates(key: String, oldValue: Any?, newValue: Any) {
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
}

