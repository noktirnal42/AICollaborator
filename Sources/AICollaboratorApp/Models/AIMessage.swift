import Foundation

/// A message in an AI conversation.
///
/// `AIMessage` represents a single message in a conversation, with information
/// about who sent it, the content, and when it was sent.
@available(macOS 15.0, *)
public struct AIMessage: Codable, Identifiable, Equatable {
    
    // MARK: - Properties
    
    /// Unique identifier for the message.
    public let id: UUID
    
    /// The role of the message sender (e.g., "user", "assistant", "system").
    public let role: String
    
    /// The content of the message.
    public let content: String
    
    /// The timestamp when the message was created.
    public let timestamp: Date
    
    // MARK: - Initialization
    
    /// Creates a new AI message.
    ///
    /// - Parameters:
    ///   - id: Optional UUID for the message (generated if not provided).
    ///   - role: The role of the sender.
    ///   - content: The content of the message.
    ///   - timestamp: Optional timestamp (defaults to current time).
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
    
    // MARK: - Factory Methods
    
    /// Creates a new user message.
    ///
    /// - Parameter content: The content of the message.
    /// - Returns: A new message with the "user" role.
    public static func user(_ content: String) -> AIMessage {
        return AIMessage(role: "user", content: content)
    }
    
    /// Creates a new assistant message.
    ///
    /// - Parameter content: The content of the message.
    /// - Returns: A new message with the "assistant" role.
    public static func assistant(_ content: String) -> AIMessage {
        return AIMessage(role: "assistant", content: content)
    }
    
    /// Creates a new system message.
    ///
    /// - Parameter content: The content of the message.
    /// - Returns: A new message with the "system" role.
    public static func system(_ content: String) -> AIMessage {
        return AIMessage(role: "system", content: content)
    }
    
    // MARK: - Equatable
    
    public static func == (lhs: AIMessage, rhs: AIMessage) -> Bool {
        return lhs.id == rhs.id &&
               lhs.role == rhs.role &&
               lhs.content == rhs.content &&
               lhs.timestamp == rhs.timestamp
    }
}

