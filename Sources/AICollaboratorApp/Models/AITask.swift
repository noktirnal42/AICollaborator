//
//  AITask.swift
//  AICollaborator
//
//  Created: 2025-04-10
//

import Foundation

/// A task to be performed by an AI agent.
///
/// `AITask` represents a discrete unit of work that can be assigned to and
/// executed by an AI agent. Tasks contain a description, input data, and
/// metadata about the task's requirements and state.
@available(macOS 15.0, *)
public struct AITask: Identifiable, Codable {
    
    // MARK: - Properties
    
    /// Unique identifier for the task.
    public let taskId: UUID
    
    /// Human-readable description of the task.
    public let description: String
    
    /// The query or command that initiated this task.
    public let query: String
    
    /// Input data for the task.
    public let input: TaskInput
    
    /// Required capabilities to execute this task.
    public let requiredCapabilities: Set<AICapability>
    
    /// Priority level of the task.
    public let priority: TaskPriority
    
    /// When the task was created.
    public let createdAt: Date
    
    /// When the task was last updated.
    public let updatedAt: Date
    
    /// Additional parameters for the task.
    public let parameters: [String: String]?
    
    /// Maximum time allowed for task execution in seconds.
    public let timeoutSeconds: Double?
    
    // MARK: - Identifiable Conformance
    
    public var id: UUID { taskId }
    
    // MARK: - Initialization
    
    /// Creates a new AI task.
    ///
    /// - Parameters:
    ///   - taskId: Optional UUID for the task (generated if not provided).
    ///   - description: Human-readable description of the task.
    ///   - query: The original query or command.
    ///   - input: Input data for the task.
    ///   - requiredCapabilities: Required capabilities to execute the task.
    ///   - priority: Priority level of the task.
    ///   - parameters: Additional parameters for the task.
    ///   - timeoutSeconds: Maximum time allowed for task execution.
    public init(
        taskId: UUID = UUID(),
        description: String,
        query: String,
        input: TaskInput,
        requiredCapabilities: Set<AICapability> = [],
        priority: TaskPriority = .normal,
        parameters: [String: String]? = nil,
        timeoutSeconds: Double? = nil
    ) {
        self.taskId = taskId
        self.description = description
        self.query = query
        self.input = input
        self.requiredCapabilities = requiredCapabilities
        self.priority = priority
        self.parameters = parameters
        self.timeoutSeconds = timeoutSeconds
        
        let now = Date()
        self.createdAt = now
        self.updatedAt = now
    }
    
    // MARK: - Factory Methods
    
    /// Creates a new task for text generation.
    ///
    /// - Parameters:
    ///   - prompt: The prompt to generate text from.
    ///   - maxTokens: Maximum number of tokens to generate.
    /// - Returns: A new task configured for text generation.
    public static func textGeneration(
        prompt: String,
        maxTokens: Int = 500
    ) -> AITask {
        return AITask(
            description: "Generate text based on prompt",
            query: prompt,
            input: .text(prompt),
            requiredCapabilities: [.textGeneration],
            parameters: ["maxTokens": "\(maxTokens)"]
        )
    }
    
    /// Creates a new task for code generation.
    ///
    /// - Parameters:
    ///   - prompt: Description of the code to generate.
    ///   - language: The programming language to use.
    ///   - context: Optional existing code for context.
    /// - Returns: A new task configured for code generation.
    public static func codeGeneration(
        prompt: String,
        language: String,
        context: String? = nil
    ) -> AITask {
        var params: [String: String] = ["language": language]
        var inputText = prompt
        
        if let context = context {
            params["hasContext"] = "true"
            inputText += "\n\nCONTEXT:\n\(context)"
        }
        
        return AITask(
            description: "Generate \(language) code",
            query: prompt,
            input: .text(inputText),
            requiredCapabilities: [.codeGeneration],
            parameters: params
        )
    }
}

/// Task input data.
@available(macOS 15.0, *)
public enum TaskInput: Codable, Equatable {
    case text(String)
    case structuredData(Data)
    case fileURL(URL)
    case conversation([ConversationMessage])
    
    // MARK: - Codable Conformance
    
    private enum CodingKeys: String, CodingKey {
        case type, value, messages, data, url
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {
        case "text":
            let value = try container.decode(String.self, forKey: .value)
            self = .text(value)
        case "structuredData":
            let data = try container.decode(Data.self, forKey: .data)
            self = .structuredData(data)
        case "fileURL":
            let urlString = try container.decode(String.self, forKey: .url)
            guard let url = URL(string: urlString) else {
                throw DecodingError.dataCorruptedError(
                    forKey: .url,
                    in: container,
                    debugDescription: "Invalid URL string"
                )
            }
            self = .fileURL(url)
        case "conversation":
            let messages = try container.decode([ConversationMessage].self, forKey: .messages)
            self = .conversation(messages)
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unknown task input type: \(type)"
            )
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .text(let value):
            try container.encode("text", forKey: .type)
            try container.encode(value, forKey: .value)
        case .structuredData(let data):
            try container.encode("structuredData", forKey: .type)
            try container.encode(data, forKey: .data)
        case .fileURL(let url):
            try container.encode("fileURL", forKey: .type)
            try container.encode(url.absoluteString, forKey: .url)
        case .conversation(let messages):
            try container.encode("conversation", forKey: .type)
            try container.encode(messages, forKey: .messages)
        }
    }
}

/// Task priority levels.
public enum TaskPriority: String, Codable, Comparable {
    case low
    case normal
    case high
    case critical
    
    public static func < (lhs: TaskPriority, rhs: TaskPriority) -> Bool {
        let order: [TaskPriority] = [.low, .normal, .high, .critical]
        return order.firstIndex(of: lhs)! < order.firstIndex(of: rhs)!
    }
}

/// AI agent capabilities.
public enum AICapability: String, Codable, CaseIterable {
    case textGeneration
    case codeGeneration
    case imageGeneration
    case audioTranscription
    case dataAnalysis
    case textAnalysis
    case questionAnswering
    case summarization
    case translation
    case planning
    case reasoning
}

