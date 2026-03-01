//
//  main.swift
//  AICollaboratorCLI
//
//  Created: 2025-04-10
//

import Foundation
import ArgumentParser
import AICollaboratorApp

// MARK: - Root Command

@main
struct AICollaboratorCommand: AsyncParsableCommand {
    nonisolated(unsafe) static var configuration = CommandConfiguration(
        commandName: "ai-collaborator",
        abstract: "Command-line interface for AI Collaborator",
        discussion: """
        AI Collaborator CLI provides a command-line interface for interacting with the
        AI Collaborator framework, executing tasks, managing agents, and working with context.

        Both human users and AI agents can use this interface to collaborate on various tasks.
        """,
        version: "0.1.0",
        subcommands: [
            TaskCommand.self,
            AgentCommand.self,
            ContextCommand.self,
            ExecuteCommand.self
        ],
        defaultSubcommand: ExecuteCommand.self
    )

    @Flag(name: .long, help: "Enable detailed logging.")
    var verbose: Bool = false

    @Flag(name: [.customShort("a"), .long], help: "Format output for AI agent consumption.")
    var aiFormat: Bool = false

    @Option(name: .shortAndLong, help: "API key for authentication.")
    var apiKey: String?

    nonisolated(unsafe) static var shared = SharedOptions()

    func validate() throws {
        AICollaboratorCommand.shared.verbose = verbose
        AICollaboratorCommand.shared.aiFormat = aiFormat
        AICollaboratorCommand.shared.apiKey = apiKey ?? ProcessInfo.processInfo.environment["GEMINI_API_KEY"]
        CLILogger.shared.logLevel = verbose ? .debug : .info
    }
}

// MARK: - Shared Options

final class SharedOptions: @unchecked Sendable {
    var verbose: Bool = false
    var aiFormat: Bool = false
    var apiKey: String?
}

// MARK: - Execute Command (Default)

struct ExecuteCommand: AsyncParsableCommand {
    nonisolated(unsafe) static var configuration = CommandConfiguration(
        commandName: "execute",
        abstract: "Execute an AI task",
        discussion: "Process a query using AI capabilities and return results."
    )

    @Argument(help: "Task query to process.")
    var query: String

    @Option(name: .shortAndLong, help: "Task description.")
    var description: String?

    @Option(name: .shortAndLong, help: "Required agent capabilities (comma-separated).")
    var capabilities: String?

    @Option(name: .shortAndLong, help: "Task priority (low, normal, high, critical).")
    var priority: String?

    @Option(name: .shortAndLong, help: "Timeout in seconds.")
    var timeout: Double?

    @Option(name: .shortAndLong, help: "Model to use (if applicable).")
    var model: String?

    @Option(name: .shortAndLong, help: "Temperature (0.0-1.0).")
    var temperature: Double?

    @Option(name: .shortAndLong, help: "Maximum output tokens.")
    var maxTokens: Int?

    @Flag(name: .shortAndLong, help: "Return explanation with results.")
    var explain: Bool = false

    mutating func run() async throws {
        CLILogger.shared.info("Executing task: \(query)")

        // Determine priority
        let taskPriority: TaskPriority
        if let priorityStr = priority?.lowercased() {
            switch priorityStr {
            case "low": taskPriority = .low
            case "high": taskPriority = .high
            case "critical": taskPriority = .critical
            default: taskPriority = .normal
            }
        } else {
            taskPriority = .normal
        }

        // Parse capabilities
        var reqCapabilities: Set<AICapability> = [.basicCompletion]
        if let capabilitiesStr = capabilities {
            let capList = capabilitiesStr.split(separator: ",").map {
                String($0).trimmingCharacters(in: .whitespaces)
            }
            let parsed = Set(capList.compactMap { capStr in
                AICapability.allCases.first { $0.rawValue == capStr }
            })
            if !parsed.isEmpty { reqCapabilities = parsed }
        }

        // Build parameters dict
        var params: [String: String] = [:]
        if let m = model { params["model"] = m }
        if let t = temperature { params["temperature"] = "\(t)" }
        if let mt = maxTokens { params["maxTokens"] = "\(mt)" }
        params["fromCLI"] = "true"

        // Create task
        let task = AITask(
            description: description ?? "CLI Task",
            query: query,
            input: .text(query),
            requiredCapabilities: reqCapabilities,
            priority: taskPriority,
            parameters: params,
            timeoutSeconds: timeout ?? 60.0
        )

        // Initialize collaborator
        let collaborator = AICollaborator()

        // Register default agent
        let defaultAgent = await setupDefaultAgent()
        await collaborator.register(agent: defaultAgent)

        // Connect to API if key is available
        if let apiKey = AICollaboratorCommand.shared.apiKey {
            let credentials = AICredentials(apiKey: apiKey)
            let _ = await collaborator.connect(agentType: .llm, credentials: credentials)
            CLILogger.shared.info("Connected to AI service with API key")
        } else {
            CLILogger.shared.warning("No API key provided. Using simulated responses only.")
        }

        // Execute task
        let result = await collaborator.execute(task: task)

        // Format output based on format flag
        outputResult(result, explain: explain)
    }

    private func setupDefaultAgent() async -> any AICollaboratorAgent {
        let simulationAgent = SimulationAgent()
        _ = await simulationAgent.initialize(with: AgentConfiguration())
        return simulationAgent
    }

    private func outputResult(_ result: AITaskResult, explain: Bool) {
        let outputText = result.outputText ?? "(no output)"
        if AICollaboratorCommand.shared.aiFormat {
            print("RESULT_STATUS: \(result.status.rawValue)")
            print("RESULT_IS_SUCCESS: \(result.isSuccessful)")
            print("RESULT_OUTPUT_BEGIN")
            print(outputText)
            print("RESULT_OUTPUT_END")
            print("TASK_ID: \(result.taskId)")
            print("RESULT_ID: \(result.resultId)")
            print("COMPLETED_AT: \(ISO8601DateFormatter().string(from: result.completedAt))")
            if let executionTime = result.executionTime {
                print("EXECUTION_TIME: \(executionTime)")
            }
        } else {
            print("── Result ───────────────────────────────────")
            print("Status: \(result.status.rawValue) (\(result.isSuccessful ? "Success" : "Failure"))")
            print("")
            print(outputText)
            print("")
            print("────────────────────────────────────────────")
            if let executionTime = result.executionTime {
                print("Execution time: \(String(format: "%.2f", executionTime))s")
            }
        }
    }
}

// MARK: - Task Command

struct TaskCommand: ParsableCommand {
    nonisolated(unsafe) static var configuration = CommandConfiguration(
        commandName: "task",
        abstract: "Manage AI tasks",
        subcommands: [
            TaskListCommand.self,
            TaskShowCommand.self,
            TaskCreateCommand.self
        ],
        defaultSubcommand: TaskListCommand.self
    )
}

struct TaskListCommand: ParsableCommand {
    nonisolated(unsafe) static var configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List recent tasks"
    )

    @Option(name: .shortAndLong, help: "Maximum number of tasks to show.")
    var limit: Int = 10

    func run() throws {
        print("Listing recent tasks (not implemented)")
    }
}

struct TaskShowCommand: ParsableCommand {
    nonisolated(unsafe) static var configuration = CommandConfiguration(
        commandName: "show",
        abstract: "Show details for a specific task"
    )

    @Argument(help: "Task ID to show.")
    var taskId: String

    func run() throws {
        print("Showing task \(taskId) (not implemented)")
    }
}

struct TaskCreateCommand: AsyncParsableCommand {
    nonisolated(unsafe) static var configuration = CommandConfiguration(
        commandName: "create",
        abstract: "Create a new task"
    )

    @Argument(help: "Task query.")
    var query: String

    @Option(name: .shortAndLong, help: "Task description.")
    var description: String?

    mutating func run() async throws {
        var executeCommand = ExecuteCommand()
        executeCommand.query = query
        executeCommand.description = description
        try await executeCommand.run()
    }
}

// MARK: - Agent Command

struct AgentCommand: ParsableCommand {
    nonisolated(unsafe) static var configuration = CommandConfiguration(
        commandName: "agent",
        abstract: "Manage AI agents",
        subcommands: [
            AgentListCommand.self,
            AgentInfoCommand.self
        ],
        defaultSubcommand: AgentListCommand.self
    )
}

struct AgentListCommand: ParsableCommand {
    nonisolated(unsafe) static var configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List available agents"
    )

    func run() throws {
        print("Available agent types:")
        print("- LLM (Large Language Model)")
        print("- TextToImage")
        print("- TextToSpeech")
        print("- SpeechToText")
        print("- Multimodal")
    }
}

struct AgentInfoCommand: ParsableCommand {
    nonisolated(unsafe) static var configuration = CommandConfiguration(
        commandName: "info",
        abstract: "Show information about a specific agent"
    )

    @Argument(help: "Agent type to show information for.")
    var agentType: String

    func run() throws {
        print("Information for agent type: \(agentType) (not implemented)")
    }
}

// MARK: - Context Command

struct ContextCommand: ParsableCommand {
    nonisolated(unsafe) static var configuration = CommandConfiguration(
        commandName: "context",
        abstract: "Manage collaboration context",
        subcommands: [
            ContextShowCommand.self,
            ContextClearCommand.self,
            ContextSaveCommand.self,
            ContextLoadCommand.self
        ],
        defaultSubcommand: ContextShowCommand.self
    )
}

struct ContextShowCommand: ParsableCommand {
    nonisolated(unsafe) static var configuration = CommandConfiguration(commandName: "show", abstract: "Show current context")
    func run() throws { print("Current context metrics (not implemented)") }
}

struct ContextClearCommand: ParsableCommand {
    nonisolated(unsafe) static var configuration = CommandConfiguration(commandName: "clear", abstract: "Clear current context")
    func run() throws { print("Context cleared (not implemented)") }
}

struct ContextSaveCommand: ParsableCommand {
    nonisolated(unsafe) static var configuration = CommandConfiguration(commandName: "save", abstract: "Save context to file")
    @Argument(help: "File path to save context to.")
    var filePath: String
    func run() throws { print("Context saved to \(filePath) (not implemented)") }
}

struct ContextLoadCommand: ParsableCommand {
    nonisolated(unsafe) static var configuration = CommandConfiguration(commandName: "load", abstract: "Load context from file")
    @Argument(help: "File path to load context from.")
    var filePath: String
    func run() throws { print("Context loaded from \(filePath) (not implemented)") }
}

// MARK: - Simulation Agent for CLI Demo

/// Simple agent implementation for CLI demonstration
actor SimulationAgent: @preconcurrency AICollaboratorAgent {
    func processTask(_ task: AITask) async throws -> AITaskResult {
        try await Task.sleep(for: .seconds(0.5 + Double.random(in: 0...1)))

        let response: String
        if task.query.lowercased().contains("hello") || task.query.lowercased().contains("hi") {
            response = "Hello! I'm the AI Collaborator simulation agent. How can I assist you today?"
        } else if task.query.lowercased().contains("help") {
            response = """
            I can help you with various tasks. Here are some examples:
            - Generate code snippets
            - Answer questions
            - Summarize text
            - Provide explanations

            Just ask me what you need, and I'll do my best to assist you.
            """
        } else if task.query.lowercased().contains("version") || task.query.lowercased().contains("about") {
            response = """
            AI Collaborator v0.1.0
            A framework for AI agent collaboration.

            This is a simulation agent providing demo responses.
            """
        } else {
            response = """
            I've processed your request: "\(task.query)"

            This is a simulated response from the AI Collaborator CLI.
            In a real implementation, this would use actual AI models to generate responses.

            To use real AI capabilities, please provide an API key using --api-key or
            by setting the GEMINI_API_KEY environment variable.
            """
        }

        return AITaskResult(
            taskId: task.taskId,
            status: .completed,
            output: response,
            executionTime: Double.random(in: 0.5...2.0)
        )
    }

    func provideCapabilities() -> [AICapability] {
        return AICapability.allCases
    }
}

// MARK: - Logger

enum LogLevel: Int, Comparable {
    case debug = 0
    case info = 1
    case warning = 2
    case error = 3

    public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

struct CLILogger: @unchecked Sendable {
    nonisolated(unsafe) static var shared = CLILogger()
    var logLevel: LogLevel = .info

    func debug(_ message: String) {
        if logLevel <= .debug { print("DEBUG: \(message)") }
    }

    func info(_ message: String) {
        if logLevel <= .info { print("INFO: \(message)") }
    }

    func warning(_ message: String) {
        if logLevel <= .warning { print("WARNING: \(message)") }
    }

    func error(_ message: String) {
        print("ERROR: \(message)")
    }
}
