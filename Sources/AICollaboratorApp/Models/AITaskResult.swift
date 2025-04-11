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
@available(macOS 15.0, *)
public struct AITaskResult: Identifiable, Codable {
    
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
    
    /// Creates a simple successful result with text output.
    ///
    /// - Parameters:
    ///   - status: Status of the task execution.
    ///   - output: Text output from the task execution.
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
@available(macOS 15.0, *)
public enum TaskOutput: Codable, Equatable {
    case text(String)
    case structuredData(Data)
    case fileURL(URL)
    case conversation([ConversationMessage])
    
    // MARK: - Codable Conformance
    
    private enum CodingKeys: String, CodingKey {
        case type, value, messages, data

