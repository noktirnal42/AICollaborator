//
//  ConversationMessage.swift
//  AICollaborator
//
//  Created: 2025-04-10
//

import Foundation

/// A message in a conversation between a human and an AI.
///
/// `ConversationMessage` represents a single message in a conversation,
/// containing the sender's role, content, and metadata.
@available(macOS 15.0, *)
public struct ConversationMessage: Codable, Identifiable, Equatable {
    
    // MARK: - Properties
    
    /// Unique identifier for the message.
    public let id: UUID
    
    /// The role of the sender (e.g., "user", "assistant", "system").
    public let role: String
    
    /// The content of the message.
    public let content: String
    
    /// When the message was created.
    public let timestamp: Date
    
    /// Additional metadata associated with this message.
    public let metadata: [String: String]?
    
    // MARK: - Initialization
    
    /// Creates a new conversation message.
    ///
    /// - Parameters:
    ///   - id: Optional UUID for the message (generated if not provided).
    ///   - role: The role of the sender.
    ///   - content: The content of the message.
    ///   - timestamp: Optional timestamp (defaults to current time).
    ///   - metadata: Optional additional metadata.
    public init(
        id: UUID = UUID(),
        role: String,
        content: String,
        timestamp: Date = Date(),
        metadata: [String: String]? = nil
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.metadata = metadata
    }
    
    // MARK: - Factory Methods
    
    /// Creates a new user message.
    ///
    /// - Parameter content: The content of the message.
    /// - Returns: A new message with the "user" role.
    public static func user(_ content: String, metadata: [String: String]? = nil) -> ConversationMessage {
        return ConversationMessage(role: "user", content: content, metadata: metadata)
    }
    
    /// Creates a new assistant message.
    ///
    /// - Parameter content: The content of the message.
    /// - Returns: A new message with the "assistant" role.
    public static func assistant(_ content: String, metadata: [String: String]? = nil) -> ConversationMessage {
        return ConversationMessage(role: "assistant", content: content, metadata: metadata)
    }
    
    /// Creates a new system message.
    ///
    /// - Parameter content: The content of the message.
    /// - Returns: A new message with the "system" role.
    public static func system(_ content: String, metadata: [String: String]? = nil) -> ConversationMessage {
        return ConversationMessage(role: "system", content: content, metadata: metadata)
    }
    
    // MARK: - Equatable
    
    public static func == (lhs: ConversationMessage, rhs: ConversationMessage) -> Bool {
        return lhs.id == rhs.id &&
               lhs.role == rhs.role &&
               lhs.content == rhs.content &&
               lhs.timestamp == rhs.timestamp &&
               lhs.metadata == rhs.metadata
    }
}

