//
//  AICollaborator.swift
//  AICollaborator
//
//  Created: 2025-04-10
//

import Foundation
import AsyncAlgorithms

/// Main entry point for AI collaboration functionality.
public actor AICollaborator {

    // MARK: - Properties

    /// Active AI agents registered with this collaborator.
    private var agents: [AIAgentExchangeId: any AICollaboratorAgent] = [:]

    /// Shared context for collaboration sessions.
    private let context: AIContext

    /// Task queue for managing concurrent operations.
    private let taskQueue = TaskQueue<AITask>()

    /// Current collaboration session ID.
    private let sessionId: UUID

    /// Authentication credentials for external services.
    private var credentials: AICredentials?

    /// Ollama integration service.
    private let ollamaService: OllamaService

    /// GitHub integration service.
    private let githubService: GitHubService

    /// Selected Ollama model for AI tasks.
    public private(set) var selectedModel: String?

    /// Currently active GitHub repository.
    public private(set) var activeRepository: GitHubService.Repository?

    /// Logger for collaborator operations.
    private let logger = CollaboratorLogger()

    // MARK: - Initialization

    /// Initialize a new AI Collaborator instance.
    public init(
        context: AIContext? = nil,
        ollamaBaseURL: URL = URL(string: "http://localhost:11434")!,
        githubCliPath: String = "/usr/local/bin/gh"
    ) {
        self.context = context ?? AIContext()
        self.sessionId = UUID()
        self.ollamaService = OllamaService(baseURL: ollamaBaseURL)
        self.githubService = GitHubService(githubCliPath: githubCliPath)
    }

    // MARK: - Public Methods

    /// Connect to external AI services with the provided credentials.
    public func connect(agentType: AIAgentType, credentials: AICredentials) async -> ConnectionResult {
        self.credentials = credentials
        do {
            _ = try await validateCredentials(credentials)
            logger.info("Successfully connected to \(agentType.rawValue) service")
            return .success
        } catch {
            logger.error("Failed to connect: \(error.localizedDescription)")
            return .failure(error.localizedDescription)
        }
    }

    /// Register an AI agent with this collaborator.
    @discardableResult
    public func register(agent: any AICollaboratorAgent) -> AIAgentExchangeId {
        let id = AIAgentExchangeId()
        agents[id] = agent
        logger.info("Registered agent with capabilities: \(agent.provideCapabilities())")
        return id
    }

    /// Execute an AI task asynchronously.
    public func execute(task: AITask) async -> AITaskResult {
        logger.info("Executing task: \(task.taskId)")
        await context.recordTask(task)

        do {
            guard let agent = findAgentForTask(task) else {
                return AITaskResult(status: .failed, output: "No suitable agent found for task")
            }
            let result = try await agent.processTask(task)
            await context.recordResult(result, for: task)
            return result
        } catch {
            let result = AITaskResult(status: .failed, output: error.localizedDescription)
            await context.recordResult(result, for: task)
            return result
        }
    }

    /// Retrieve the current collaboration context.
    public func getContext() -> AIContext {
        return context
    }

    // MARK: - Private Methods

    private func validateCredentials(_ credentials: AICredentials) async throws -> Bool {
        try await Task.sleep(for: .seconds(1))
        return true
    }

    private func findAgentForTask(_ task: AITask) -> (any AICollaboratorAgent)? {
        for (_, agent) in agents {
            let capabilities = agent.provideCapabilities()
            if task.requiredCapabilities.isSubset(of: Set(capabilities)) {
                return agent
            }
        }
        return nil
    }
}

// MARK: - Supporting Types

/// Result of a connection attempt.
public enum ConnectionResult: Sendable {
    case success
    case failure(String)
}

/// Credentials for authenticating with AI services.
public struct AICredentials: Sendable {
    public let apiKey: String
    public let additionalInfo: [String: String]

    public init(apiKey: String, additionalInfo: [String: String] = [:]) {
        self.apiKey = apiKey
        self.additionalInfo = additionalInfo
    }
}

/// Simple logging utility for AICollaborator.
private struct CollaboratorLogger: Sendable {
    func info(_ message: String) { print("[AICollaborator] INFO: \(message)") }
    func error(_ message: String) { print("[AICollaborator] ERROR: \(message)") }
}

/// A queue for managing concurrent task execution.
actor TaskQueue<T: Sendable>: Sendable {
    private var tasks: [T] = []

    func enqueue(_ task: T) { tasks.append(task) }
    func dequeue() -> T? {
        guard !tasks.isEmpty else { return nil }
        return tasks.removeFirst()
    }
    var isEmpty: Bool { tasks.isEmpty }
    var count: Int { tasks.count }
}
