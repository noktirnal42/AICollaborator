//
//  AIContext.swift
//  AICollaborator
//
//  Created: 2025-04-10
//

import Foundation
import AsyncAlgorithms

/// Manages context for AI collaboration sessions.
public actor AIContext {

    // MARK: - Properties

    public let contextId: UUID
    public let createdAt: Date
    private(set) public var lastAccessedAt: Date
    private(set) public var maxHistorySize: Int

    private var taskHistory: [UUID: AITask] = [:]
    private var resultHistory: [UUID: AITaskResult] = [:]
    private var conversationHistory: [String: [ConversationMessage]] = [:]
    private var globalContext: [String: String] = [:]
    private var metrics: ContextMetrics = ContextMetrics()

    // MARK: - Initialization

    public init(contextId: UUID? = nil, maxHistorySize: Int = 100) {
        self.contextId = contextId ?? UUID()
        self.createdAt = Date()
        self.lastAccessedAt = Date()
        self.maxHistorySize = maxHistorySize
    }

    // MARK: - Task Management

    public func recordTask(_ task: AITask) {
        updateLastAccessed()
        taskHistory[task.taskId] = task
        metrics.incrementTaskCount()
        enforceHistorySizeLimit()
    }

    public func recordResult(_ result: AITaskResult, for task: AITask) {
        updateLastAccessed()
        resultHistory[result.resultId] = result
        metrics.incrementResultCount()
        enforceHistorySizeLimit()
    }

    public func getTask(with taskId: UUID) -> AITask? {
        updateLastAccessed()
        return taskHistory[taskId]
    }

    public func getResult(with resultId: UUID) -> AITaskResult? {
        updateLastAccessed()
        return resultHistory[resultId]
    }

    public func getAllTasks() -> [AITask] {
        updateLastAccessed()
        return Array(taskHistory.values)
    }

    public func getTasks(where predicate: (AITask) -> Bool) -> [AITask] {
        updateLastAccessed()
        return taskHistory.values.filter(predicate)
    }

    public func clearTaskHistory() {
        updateLastAccessed()
        taskHistory.removeAll()
        resultHistory.removeAll()
    }

    // MARK: - Conversation Management

    public func addMessage(_ message: ConversationMessage, to conversationId: String) {
        updateLastAccessed()
        var messages = conversationHistory[conversationId] ?? []
        messages.append(message)
        conversationHistory[conversationId] = messages
        metrics.incrementMessageCount()
    }

    public func getMessages(for conversationId: String) -> [ConversationMessage] {
        updateLastAccessed()
        return conversationHistory[conversationId] ?? []
    }

    public func getRecentMessages(for conversationId: String, limit: Int) -> [ConversationMessage] {
        updateLastAccessed()
        let messages = conversationHistory[conversationId] ?? []
        if messages.count <= limit { return messages }
        return Array(messages.suffix(limit))
    }

    public func clearConversation(for conversationId: String) {
        updateLastAccessed()
        conversationHistory.removeValue(forKey: conversationId)
    }

    // MARK: - Context Value Management

    public func setGlobalValue(_ value: String, for key: String) {
        updateLastAccessed()
        globalContext[key] = value
    }

    public func getGlobalValue(for key: String) -> String? {
        updateLastAccessed()
        return globalContext[key]
    }

    public func removeGlobalValue(for key: String) {
        updateLastAccessed()
        globalContext.removeValue(forKey: key)
    }

    // MARK: - Serialization

    public func export() throws -> Data {
        updateLastAccessed()
        let export = ContextExport(
            contextId: contextId,
            createdAt: createdAt,
            lastAccessedAt: lastAccessedAt,
            maxHistorySize: maxHistorySize,
            conversationHistory: conversationHistory,
            globalContext: globalContext,
            metrics: metrics
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(export)
    }

    public static func `import`(from data: Data) async throws -> AIContext {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let imported = try decoder.decode(ContextExport.self, from: data)

        let context = AIContext(
            contextId: imported.contextId,
            maxHistorySize: imported.maxHistorySize
        )
        await context.setImportedProperties(imported)
        return context
    }

    private func setImportedProperties(_ imported: ContextExport) {
        self.conversationHistory = imported.conversationHistory
        self.metrics = imported.metrics
        self.globalContext = imported.globalContext
    }

    // MARK: - Memory Management

    public func setMaxHistorySize(_ size: Int) {
        self.maxHistorySize = size
        enforceHistorySizeLimit()
    }

    private func enforceHistorySizeLimit() {
        if taskHistory.count > maxHistorySize {
            let sortedTasks = taskHistory.values.sorted { $0.createdAt < $1.createdAt }
            let excessCount = taskHistory.count - maxHistorySize
            for i in 0..<excessCount {
                taskHistory.removeValue(forKey: sortedTasks[i].taskId)
            }
        }

        if resultHistory.count > maxHistorySize {
            let sortedResults = resultHistory.values.sorted { $0.completedAt < $1.completedAt }
            let excessCount = resultHistory.count - maxHistorySize
            for i in 0..<excessCount {
                resultHistory.removeValue(forKey: sortedResults[i].resultId)
            }
        }

        for (conversationId, messages) in conversationHistory {
            if messages.count > maxHistorySize {
                conversationHistory[conversationId] = Array(messages.suffix(maxHistorySize))
            }
        }
    }

    public func clear() {
        taskHistory.removeAll()
        resultHistory.removeAll()
        conversationHistory.removeAll()
        globalContext.removeAll()
        metrics = ContextMetrics()
    }

    private func updateLastAccessed() {
        lastAccessedAt = Date()
    }

    public func getMetrics() -> ContextMetrics {
        updateLastAccessed()
        return metrics
    }
}

// MARK: - Supporting Types

public struct ContextMetrics: Codable, Sendable {
    public private(set) var taskCount: Int = 0
    public private(set) var resultCount: Int = 0
    public private(set) var messageCount: Int = 0
    public private(set) var creationTime: Date = Date()

    mutating func incrementTaskCount() { taskCount += 1 }
    mutating func incrementResultCount() { resultCount += 1 }
    mutating func incrementMessageCount() { messageCount += 1 }
}

private struct ContextExport: Codable {
    let contextId: UUID
    let createdAt: Date
    let lastAccessedAt: Date
    let maxHistorySize: Int
    let conversationHistory: [String: [ConversationMessage]]
    let globalContext: [String: String]
    let metrics: ContextMetrics
}
