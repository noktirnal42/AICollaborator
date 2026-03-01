//
//  AITaskResult.swift
//  AICollaborator
//
//  Created: 2025-04-10
//

import Foundation

/// The result of an AI task execution.
///
/// `AITaskResult` contains the output and status information after an AI
/// agent has executed a task. It includes the execution status, any output
/// data, errors encountered, and metadata about the execution.
public struct AITaskResult: Identifiable, Codable, Sendable {

    // MARK: - Properties

    /// Unique identifier for the result.
    public let resultId: UUID

    /// ID of the task that produced this result.
    public let taskId: UUID

    /// Status of the task execution.
    public let status: TaskResultStatus

    /// Output data from the task execution.
    public let output: TaskOutput?

    /// Error message if the task failed.
    public let error: String?

    /// When the task execution completed.
    public let completedAt: Date

    /// Duration of task execution in seconds.
    public let executionDuration: Double?

    /// Resource usage statistics.
    public let resourceUsage: ResourceUsage?

    /// Additional metadata about the execution.
    public let metadata: [String: String]?

    // MARK: - Identifiable Conformance

    public var id: UUID { resultId }

    // MARK: - Computed Properties

    /// Whether the task completed successfully.
    public var isSuccessful: Bool {
        return status == .completed
    }

    /// Execution time in seconds (alias for executionDuration).
    public var executionTime: Double? {
        return executionDuration
    }

    /// Output as plain text, if the output is a text type.
    public var outputText: String? {
        guard case .text(let text) = output else { return nil }
        return text
    }

    // MARK: - Initialization

    /// Creates a new AI task result.
    ///
    /// - Parameters:
    ///   - resultId: Optional UUID for the result (generated if not provided).
    ///   - taskId: ID of the task that produced this result.
    ///   - status: Status of the task execution.
    ///   - output: Output data from the task execution.
    ///   - error: Error message if the task failed.
    ///   - completedAt: When the task execution completed.
    ///   - executionDuration: Duration of task execution in seconds.
    ///   - resourceUsage: Resource usage statistics.
    ///   - metadata: Additional metadata about the execution.
    public init(
        resultId: UUID = UUID(),
        taskId: UUID,
        status: TaskResultStatus,
        output: TaskOutput? = nil,
        error: String? = nil,
        completedAt: Date = Date(),
        executionDuration: Double? = nil,
        resourceUsage: ResourceUsage? = nil,
        metadata: [String: String]? = nil
    ) {
        self.resultId = resultId
        self.taskId = taskId
        self.status = status
        self.output = output
        self.error = error
        self.completedAt = completedAt
        self.executionDuration = executionDuration
        self.resourceUsage = resourceUsage
        self.metadata = metadata
    }

    /// Creates a simple result with text output.
    ///
    /// - Parameters:
    ///   - taskId: ID of the task that produced this result.
    ///   - status: Status of the task execution.
    ///   - output: Text output from the task execution.
    ///   - completedAt: When the task execution completed.
    ///   - executionTime: Duration of task execution in seconds.
    public init(
        taskId: UUID,
        status: TaskResultStatus,
        output: String,
        completedAt: Date = Date(),
        executionTime: Double? = nil
    ) {
        self.init(
            resultId: UUID(),
            taskId: taskId,
            status: status,
            output: .text(output),
            completedAt: completedAt,
            executionDuration: executionTime
        )
    }

    /// Creates a simple successful result with text output (convenience).
    ///
    /// - Parameters:
    ///   - status: Status of the task execution.
    ///   - output: Text output string.
    public init(status: TaskResultStatus, output: String) {
        self.init(
            resultId: UUID(),
            taskId: UUID(),
            status: status,
            output: .text(output)
        )
    }
}

/// Output data from a task execution.
public enum TaskOutput: Codable, Equatable, Sendable {
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
                debugDescription: "Unknown task output type: \(type)"
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
