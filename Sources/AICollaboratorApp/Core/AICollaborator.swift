import Foundation

/// The main entry point for the AICollaborator framework.
///
/// AICollaborator manages AI agents, routes tasks, and maintains context.
///
/// ## Overview
///
/// The `AICollaborator` class serves as the orchestrator for the entire framework,
/// enabling registration and management of AI agents, routing tasks to appropriate agents,
/// and maintaining context across interactions.
///
/// ## Example Usage
///
/// ```swift
/// // Initialize the collaborator
/// let collaborator = AICollaborator()
///
/// // Connect an AI agent with credentials
/// collaborator.connect(agentType: .llm, credentials: AICredentials(apiKey: "YOUR_API_KEY"))
///
/// // Register a custom agent
/// let myAgent = MyAIAgent()
/// let agentId = collaborator.register(agent: myAgent)
///
/// // Execute a task
/// let task = CodeGenerationTask(
///     description: "Create a Swift function to calculate factorial",
///     constraints: ["Must be recursive", "Must handle negative numbers"]
/// )
/// let result = collaborator.execute(task: task)
/// ```
///
/// - Note: For more details on creating custom agents, see ``AICollaboratorAgent`` protocol.
public class AICollaborator {
    
    /// Configuration for the AICollaborator instance
    public struct Configuration {
        /// Default timeout for task execution in seconds
        public var defaultTaskTimeout: TimeInterval
        
        /// Whether to enable automatic context management
        public var enableAutoContextManagement: Bool
        
        /// Maximum number of concurrent tasks
        public var maxConcurrentTasks: Int
        
        /// Default logging level
        public var logLevel: LogLevel
        
        /// Creates a default configuration
        public static var `default`: Configuration {
            return Configuration(
                defaultTaskTimeout: 30.0,
                enableAutoContextManagement: true,
                maxConcurrentTasks: 5,
                logLevel: .info
            )
        }
        
        /// Initialize a new configuration
        public init(
            defaultTaskTimeout: TimeInterval = 30.0,
            enableAutoContextManagement: Bool = true,
            maxConcurrentTasks: Int = 5,
            logLevel: LogLevel = .info
        ) {
            self.defaultTaskTimeout = defaultTaskTimeout
            self.enableAutoContextManagement = enableAutoContextManagement
            self.maxConcurrentTasks = maxConcurrentTasks
            self.logLevel = logLevel
        }
    }
    
    /// Available logging levels
    public enum LogLevel: Int, Comparable {
        case debug = 0
        case info = 1
        case warning = 2
        case error = 3
        
        public static func < (lhs: AICollaborator.LogLevel, rhs: AICollaborator.LogLevel) -> Bool {
            return lhs.rawValue < rhs.rawValue
        }
    }
    
    // MARK: - Properties
    
    /// The configuration for this collaborator instance
    public let configuration: Configuration
    
    /// Dictionary mapping agent IDs to registered agents
    private var agents: [UUID: AICollaboratorAgent] = [:]
    
    /// Dictionary mapping session IDs to contexts
    private var contexts: [UUID: AIContext] = [:]
    
    /// Service for network operations
    private let networkService: NetworkServiceProtocol
    
    /// Service for GitHub operations
    private let githubService: GitHubServiceProtocol
    
    /// Queue for task execution
    private let taskQueue = DispatchQueue(label: "ai.collaborator.taskQueue", attributes: .concurrent)
    
    /// Queue for context operations to ensure thread safety
    private let contextQueue = DispatchQueue(label: "ai.collaborator.contextQueue")
    
    // MARK: - Initialization
    
    /// Initialize a new AICollaborator instance with the specified configuration and services
    ///
    /// - Parameters:
    ///   - configuration: The configuration for this collaborator instance
    ///   - networkService: Service for network operations
    ///   - githubService: Service for GitHub operations
    public init(
        configuration: Configuration = .default,
        networkService: NetworkServiceProtocol = NetworkService(),
        githubService: GitHubServiceProtocol = GitHubService()
    ) {
        self.configuration = configuration
        self.networkService = networkService
        self.githubService = githubService
        
        log(.info, message: "AICollaborator initialized with configuration: \(configuration)")
    }
    
    // MARK: - Agent Management
    
    /// Connect an AI agent with the specified credentials
    ///
    /// - Parameters:
    ///   - agentType: The type of AI agent to connect
    ///   - credentials: The credentials for the AI agent
    ///
    /// - Returns: Boolean indicating success or failure
    public func connect(agentType: AIAgentType, credentials: AICredentials) -> Bool {
        log(.info, message: "Connecting agent of type: \(agentType)")
        
        // Implementation would validate credentials and establish connection
        // For now, this is a placeholder that returns true
        
        return true
    }
    
    /// Register an agent with the collaborator
    ///
    /// - Parameter agent: The agent to register
    /// - Returns: The unique identifier for the registered agent
    @discardableResult
    public func register(agent: AICollaboratorAgent) -> UUID {
        let id = UUID()
        agents[id] = agent
        
        log(.info, message: "Registered agent with ID: \(id)")
        
        return id
    }
    
    /// Unregister an agent from the collaborator
    ///
    /// - Parameter id: The ID of the agent to unregister
    /// - Returns: Boolean indicating success or failure
    @discardableResult
    public func unregister(agentId: UUID) -> Bool {
        guard agents[agentId] != nil else {
            log(.warning, message: "Attempted to unregister non-existent agent: \(agentId)")
            return false
        }
        
        agents.removeValue(forKey: agentId)
        log(.info, message: "Unregistered agent with ID: \(agentId)")
        
        return true
    }
    
    /// Get all registered agents
    ///
    /// - Returns: Dictionary mapping agent IDs to registered agents
    public func getRegisteredAgents() -> [UUID: AICollaboratorAgent] {
        return agents
    }
    
    // MARK: - Task Execution
    
    /// Execute a task using available agents
    ///
    /// - Parameters:
    ///   - task: The task to execute
    ///   - timeout: Optional timeout for the task execution
    ///
    /// - Returns: The result of the task execution
    public func execute(task: AITask, timeout: TimeInterval? = nil) -> AITaskResult {
        log(.info, message: "Executing task: \(task.id)")
        
        // Validate the task
        guard task.validate() else {
            log(.error, message: "Task validation failed for task: \(task.id)")
            return AITaskResult(
                id: task.id,
                status: .failed,
                output: "",
                error: AIError.invalidTaskParameters,
                timestamp: Date()
            )
        }
        
        // Find suitable agent
        guard let agent = findSuitableAgent(for: task) else {
            log(.error, message: "No suitable agent found for task: \(task.id)")
            return AITaskResult(
                id: task.id,
                status: .failed,
                output: "",
                error: AIError.noSuitableAgentFound,
                timestamp: Date()
            )
        }
        
        // Get or create context for the task
        let context = getOrCreateContext(for: task.sessionId)
        
        // Update context with task
        if configuration.enableAutoContextManagement {
            contextQueue.sync {
                context.store(key: "current_task", value: task)
                context.store(key: "last_task_timestamp", value: Date())
            }
        }
        
        // If agent supports context, provide it
        if var contextAwareAgent = agent as? ContextAware {
            contextAwareAgent.updateContext(context)
        }
        
        // Execute the task
        let result = agent.processTask(task)
        
        // Update context with result
        if configuration.enableAutoContextManagement {
            contextQueue.sync {
                context.store(key: "last_task_result", value: result)
                context.store(key: "last_task_completion_timestamp", value: Date())
            }
        }
        
        log(.info, message: "Task \(task.id) completed with status: \(result.status)")
        
        return result
    }
    
    /// Execute a task asynchronously
    ///
    /// - Parameters:
    ///   - task: The task to execute
    ///   - timeout: Optional timeout for the task execution
    ///   - completion: Closure to call with the result
    public func executeAsync(task: AITask, timeout: TimeInterval? = nil, completion: @escaping (AITaskResult) -> Void) {
        taskQueue.async {
            let result = self.execute(task: task, timeout: timeout)
            completion(result)
        }
    }
    
    /// Find a suitable agent for a task
    ///
    /// - Parameter task: The task to find an agent for
    /// - Returns: The most suitable agent, or nil if none found
    private func findSuitableAgent(for task: AITask) -> AICollaboratorAgent? {
        // Find agents that can handle the task
        let suitableAgents = agents.values.filter { agent in
            let capabilities = agent.provideCapabilities()
            return task.matchesCapabilities(capabilities)
        }
        
        // Return the first suitable agent
        // In a real implementation, this would have more sophisticated logic
        return suitableAgents.first
    }
    
    // MARK: - Context Management
    
    /// Get the context for a session, creating it if it doesn't exist
    ///
    /// - Parameter sessionId: The session ID to get context for
    /// - Returns: The context for the session
    private func getOrCreateContext(for sessionId: UUID) -> AIContext {
        return contextQueue.sync {
            if let context = contexts[sessionId] {
                return context
            } else {
                let context = AIContext(sessionId: sessionId)
                contexts[sessionId] = context
                return context
            }
        }
    }
    
    /// Get the context for a session
    ///
    /// - Parameter sessionId: The session ID to get context for
    /// - Returns: The context for the session, or nil if it doesn't exist
    public func getContext(sessionId: UUID) -> AIContext? {
        return contextQueue.sync {
            return contexts[sessionId]
        }
    }
    
    /// Clear the context for a session
    ///
    /// - Parameter sessionId: The session ID to clear context for
    /// - Returns: Boolean indicating success or failure
    @discardableResult
    public func clearContext(for sessionId: UUID) -> Bool {
        return contextQueue.sync {
            guard contexts[sessionId] != nil else {
                return false
            }
            
            contexts.removeValue(forKey: sessionId)
            return true
        }
    }
    
    // MARK: - Utility Methods
    
    /// Log a message at the specified level
    ///
    /// - Parameters:
    ///   - level: The log level
    ///   - message: The message to log
    private func log(_ level: LogLevel, message: String) {
        guard level >= configuration.logLevel else { return }
        
        let levelString: String
        switch level {
        case .debug:
            levelString = "DEBUG"
        case .info:
            levelString = "INFO"
        case .warning:
            levelString = "WARNING"
        case .error:
            levelString = "ERROR"
        }
        
        print("[\(levelString)] AICollaborator: \(message)")
    }
}

