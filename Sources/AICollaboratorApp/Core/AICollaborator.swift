//
//  AICollaborator.swift
//  AICollaborator
//
//  Created: 2025-04-10
//

import Foundation
import SwiftyJSON
import Alamofire
import AsyncAlgorithms

/// Main entry point for AI collaboration functionality
public actor AICollaborator {
    // MARK: - Properties
    
    /// Active AI agents registered with this collaborator
    private var agents: [AIAgentExchangeId: any AICollaboratorAgent] = [:]
    
    /// Shared context for collaboration sessions
    private let context: AIContext
    
    /// Task queue for managing concurrent operations
    private let taskQueue = TaskQueue<AITask>()
    
    /// Current collaboration session ID
    private let sessionId: UUID
    
    /// Authentication credentials for external services
    private var credentials: AICredentials?
    
    // MARK: - Initialization
    
    /// Initialize a new AI Collaborator instance
    /// - Parameter context: Optional pre-existing context. If nil, a new context will be created.
    public init(context: AIContext? = nil) {
        self.context = context ?? AIContext()
        self.sessionId = UUID()
        
        setupLogging()
    }
    
    // MARK: - Public Methods
    
    /// Connect to external AI services with the provided credentials
    /// - Parameters:
    ///   - agentType: Type of AI agent to connect
    ///   - credentials: Authentication credentials for the service
    /// - Returns: Connection result indicating success or failure
    public func connect(agentType: AIAgentType, credentials: AICredentials) async -> ConnectionResult {
        self.credentials = credentials
        
        do {
            let result = try await validateCredentials(credentials)
            logger.info("Successfully connected to \(agentType) service")
            return .success
        } catch {
            logger.error("Failed to connect to \(agentType) service: \(error.localizedDescription)")
            return .failure(error.localizedDescription)
        }
    }
    
    /// Register an AI agent with this collaborator
    /// - Parameter agent: The agent to register
    /// - Returns: Agent exchange ID for future reference
    @discardableResult
    public func register(agent: any AICollaboratorAgent) -> AIAgentExchangeId {
        let id = AIAgentExchangeId()
        agents[id] = agent
        logger.info("Registered agent with capabilities: \(agent.provideCapabilities())")
        return id
    }
    
    /// Execute an AI task asynchronously
    /// - Parameter task: The task to execute
    /// - Returns: Result of the task execution
    public func execute(task: AITask) async -> AITaskResult {
        logger.info("Executing task: \(task.taskId)")
        
        // Record task in context
        await context.recordTask(task)
        
        do {
            // Find appropriate agent for the task
            guard let agent = findAgentForTask(task) else {
                return AITaskResult(status: .failed, output: "No suitable agent found for task")
            }
            
            // Execute the task with the selected agent
            let result = try await agent.processTask(task)
            
            // Record the result in context
            await context.recordResult(result, for: task)
            
            return result
        } catch {
            let result = AITaskResult(status: .failed, output: error.localizedDescription)
            await context.recordResult(result, for: task)
            return result
        }
    }
    
    /// Retrieve the current collaboration context
    /// - Returns: The current context
    public func getContext() -> AIContext {
        return context
    }
    
    // MARK: - Private Methods
    
    private func setupLogging() {
        // Configure logging system
        logger.logLevel = .info
    }
    
    private func validateCredentials(_ credentials: AICredentials) async throws -> Bool {
        // Simulate credential validation
        try await Task.sleep(for: .seconds(1))
        
        // In a real implementation, this would verify with the AI service provider
        return true
    }
    
    private func findAgentForTask(_ task: AITask) -> (any AICollaboratorAgent)? {
        // Find agent with capabilities that match the task requirements
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

/// Result of a connection attempt
public enum ConnectionResult {
    case success
    case failure(String)
}

/// Credentials for authenticating with AI services
public struct AICredentials {
    public let apiKey: String
    public let additionalInfo: [String: String]
    
    public init(apiKey: String, additionalInfo: [String: String] = [:]) {
        self.apiKey = apiKey
        self.additionalInfo = additionalInfo
    }
}

/// Simple logging utility
fileprivate enum LogLevel: Int {
    case debug = 0
    case info = 1
    case warning = 2
    case error = 3
}

fileprivate struct Logger {
    var logLevel: LogLevel = .info
    
    func debug(_ message: String) {
        log(message, level: .debug)
    }
    
    func info(_ message: String) {
        log(message, level: .info)
    }
    
    func warning(_ message: String) {
        log(message, level: .warning)
    }
    
    func error(_ message: String) {
        log(message, level: .error)
    }
    
    private func log(_ message: String, level: LogLevel) {
        if level.rawValue >= logLevel.rawValue {
            let prefix: String
            switch level {
            case .debug: prefix = "[DEBUG]"
            case .info: prefix = "[INFO]"
            case .warning: prefix = "[WARNING]"
            case .error: prefix = "[ERROR]"
            }
            
            print("\(prefix) \(message)")
        }
    }
}

fileprivate let logger = Logger()

/// A queue for managing concurrent task execution
actor TaskQueue<T> {
    private var tasks: [T] = []
    
    func enqueue(_ task: T) {
        tasks.append(task)
    }
    
    func dequeue() -> T? {
        guard !tasks.isEmpty else { return nil }
        return tasks.removeFirst()
    }
    
    var isEmpty: Bool {
        return tasks.isEmpty
    }
    
    var count: Int {
        return tasks.count
    }
}

