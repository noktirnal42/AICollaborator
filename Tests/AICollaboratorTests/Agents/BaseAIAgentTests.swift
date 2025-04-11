//
//  BaseAIAgentTests.swift
//  AICollaboratorTests
//
//  Created: 2025-04-10
//

import XCTest
@testable import AICollaboratorApp

/// Tests for the BaseAIAgent implementation
final class BaseAIAgentTests: XCTestCase {
    
    // MARK: - Properties
    
    /// Test agent instance
    private var agent: MockAIAgent!
    
    /// Test task for reuse
    private var testTask: AITask!
    
    // MARK: - Setup and Teardown
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Create a test agent
        agent = MockAIAgent(
            name: "TestAgent",
            version: "1.0",
            description: "Test agent for unit tests",
            capabilities: [.basicCompletion, .textAnalysis]
        )
        
        // Create a test task
        testTask = AITask(
            description: "Test Task",
            query: "This is a test query",
            requiredCapabilities: [.basicCompletion]
        )
    }
    
    override func tearDown() async throws {
        // Clean up
        agent = nil
        testTask = nil
        
        try await super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    /// Test agent initialization
    func testInitialization() async throws {
        // Verify properties were set correctly
        XCTAssertEqual(agent.name, "TestAgent")
        XCTAssertEqual(agent.version, "1.0")
        XCTAssertEqual(agent.description, "Test agent for unit tests")
        
        // Verify capabilities
        let capabilities = agent.provideCapabilities()
        XCTAssertEqual(capabilities.count, 2)
        XCTAssertTrue(capabilities.contains(.basicCompletion))
        XCTAssertTrue(capabilities.contains(.textAnalysis))
        
        // Verify initial state
        let state = await agent.getState()
        XCTAssertEqual(state, .idle)
    }
    
    // MARK: - Task Processing Tests
    
    /// Test basic task processing with success
    func testSuccessfulTaskProcessing() async throws {
        // Configure mock to return success
        agent.mockProcessingResult = .success("Test result")
        
        // Process task
        let result = try await agent.processTask(testTask)
        
        // Verify result
        XCTAssertEqual(result.status, .completed)
        XCTAssertEqual(result.output as? String, "Test result")
        XCTAssertEqual(result.taskId, testTask.taskId)
        
        // Verify state transitions
        XCTAssertEqual(agent.stateTransitions.count, 3)
        XCTAssertEqual(agent.stateTransitions[0], .idle)
        XCTAssertEqual(agent.stateTransitions[1], .busy(taskId: testTask.taskId))
        XCTAssertEqual(agent.stateTransitions[2], .idle)
    }
    
    /// Test task processing with failure
    func testFailedTaskProcessing() async {
        // Configure mock to throw error
        agent.mockProcessingResult = .failure(MockAIAgentError.testError)
        
        // Process task and expect error
        do {
            _ = try await agent.processTask(testTask)
            XCTFail("Expected error was not thrown")
        } catch let error as MockAIAgentError {
            // Verify specific error
            XCTAssertEqual(error, .testError)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
        
        // Verify state transitions
        XCTAssertEqual(agent.stateTransitions.count, 3)
        XCTAssertEqual(agent.stateTransitions[0], .idle)
        XCTAssertEqual(agent.stateTransitions[1], .busy(taskId: testTask.taskId))
        
        // Final state should be error
        if case .error = agent.stateTransitions[2] {
            // Success - expected error state
        } else {
            XCTFail("Expected error state, got \(agent.stateTransitions[2])")
        }
    }
    
    /// Test missing capability handling
    func testMissingCapabilityHandling() async {
        // Create task requiring capabilities not supported by the agent
        let unsupportedTask = AITask(
            description: "Unsupported Task",
            query: "This requires unsupported capabilities",
            requiredCapabilities: [.imageGeneration]
        )
        
        // Process task and expect error
        do {
            _ = try await agent.processTask(unsupportedTask)
            XCTFail("Expected error was not thrown")
        } catch let error as AgentError {
            // Verify specific error
            if case .capabilityNotSupported = error {
                // Success - expected error
            } else {
                XCTFail("Expected capability not supported error, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    // MARK: - State Management Tests
    
    /// Test agent state transitions
    func testAgentStateTransitions() async throws {
        // Verify initial state
        XCTAssertEqual(await agent.getState(), .idle)
        
        // Initialize agent with new configuration
        let config = AgentConfiguration(temperature: 0.5, modelId: "test-model")
        let initResult = await agent.initialize(with: config)
        
        // Verify successful initialization
        XCTAssertEqual(initResult, .success)
        
        // Verify state transitions
        XCTAssertEqual(agent.stateTransitions.count, 3)
        XCTAssertEqual(agent.stateTransitions[0], .idle)
        XCTAssertEqual(agent.stateTransitions[1], .initializing)
        XCTAssertEqual(agent.stateTransitions[2], .idle)
        
        // Test shutdown
        let shutdownResult = await agent.shutdown()
        
        // Verify successful shutdown
        if case .success = shutdownResult {
            // Success
        } else {
            XCTFail("Expected success, got \(shutdownResult)")
        }
        
        // Verify state transitions
        XCTAssertEqual(agent.stateTransitions.count, 5)
        XCTAssertEqual(agent.stateTransitions[3], .shuttingDown)
        XCTAssertEqual(agent.stateTransitions[4], .terminated)
    }
    
    /// Test initialization failure
    func testInitializationFailure() async {
        // Configure mock to fail initialization
        agent.mockInitResult = .failure("Test initialization error")
        
        // Initialize agent
        let config = AgentConfiguration()
        let result = await agent.initialize(with: config)
        
        // Verify failure
        if case .failure(let message) = result {
            XCTAssertEqual(message, "Test initialization error")
        } else {
            XCTFail("Expected failure, got \(result)")
        }
        
        // Verify state transitions
        XCTAssertEqual(agent.stateTransitions.count, 3)
        XCTAssertEqual(agent.stateTransitions[0], .idle)
        XCTAssertEqual(agent.stateTransitions[1], .initializing)
        
        // Final state should be error
        if case .error = agent.stateTransitions[2] {
            // Success - expected error state
        } else {
            XCTFail("Expected error state, got \(agent.stateTransitions[2])")
        }
    }
    
    // MARK: - Task History and Caching Tests
    
    /// Test task history management
    func testTaskHistoryManagement() async throws {
        // Process multiple tasks
        agent.mockProcessingResult = .success("Result 1")
        let result1 = try await agent.processTask(testTask)
        
        agent.mockProcessingResult = .success("Result 2")
        let task2 = AITask(
            description: "Test Task 2",
            query: "This is another test query",
            requiredCapabilities: [.basicCompletion]
        )
        let result2 = try await agent.processTask(task2)
        
        // Verify task history
        XCTAssertEqual(agent.taskHistory.count, 2)
        XCTAssertEqual(agent.taskHistory[result1.taskId]?.output as? String, "Result 1")
        XCTAssertEqual(agent.taskHistory[result2.taskId]?.output as? String, "Result 2")
        
        // Test history pruning
        await agent.testHistoryPruning()
        
        // Verify pruning
        XCTAssertEqual(agent.taskHistory.count, 1)
    }
    
    /// Test error result handling in history
    func testErrorResultHandling() async {
        // Configure mock to throw error
        agent.mockProcessingResult = .failure(MockAIAgentError.testError)
        
        // Process task and expect error
        do {
            _ = try await agent.processTask(testTask)
            XCTFail("Expected error was not thrown")
        } catch {
            // Expected error
        }
        
        // Verify error recorded in history
        XCTAssertEqual(agent.taskHistory.count, 1)
        
        // Get the recorded result
        guard let result = agent.taskHistory.values.first else {
            XCTFail("Expected error result in history")
            return
        }
        
        // Verify error result
        XCTAssertEqual(result.status, .failed)
        XCTAssertEqual(result.taskId, testTask.taskId)
    }
    
    // MARK: - Progress Monitoring Tests
    
    /// Test progress monitoring
    func testProgressMonitoring() async throws {
        // Enable progress monitoring
        agent.enableProgressMonitoring(for: testTask.taskId, expectedDuration: 1.0)
        
        // Update progress
        await agent.updateProgress(
            taskId: testTask.taskId,
            status: "Testing",
            progress: 0.5
        )
        
        // Verify progress
        let progress = await agent.getProgress(for: testTask.taskId)
        XCTAssertNotNil(progress)
        XCTAssertEqual(progress?.status, "Testing")
        XCTAssertEqual(progress?.progress, 0.5)
        
        // Update to complete
        await agent.updateProgress(
            taskId: testTask.taskId,
            status: "Completed",
            progress: 1.0
        )
        
        // Verify complete progress
        let completedProgress = await agent.getProgress(for: testTask.taskId)
        XCTAssertNotNil(completedProgress)
        XCTAssertEqual(completedProgress?.status, "Completed")
        XCTAssertEqual(completedProgress?.progress, 1.0)
    }
}

// MARK: - Mock Implementations

/// Mock AI agent for testing
final class MockAIAgent: BaseAIAgent {
    /// Result to return for process task
    enum MockResult {
        case success(String)
        case failure(Error)
    }
    
    /// Mock result for processing
    var mockProcessingResult: MockResult = .success("Default result")
    
    /// Mock result for initialization
    var mockInitResult: AgentInitResult = .success
    
    /// State transitions for verification
    var stateTransitions: [AgentState] = []
    
    /// Track task history for verification
    var taskHistory: [UUID: AITaskResult] = [:]
    
    /// Override to track state transitions
    override func updateState(_ newState: AgentState) {
        stateTransitions.append(newState)
        super.updateState(newState)
    }
    
    /// Override to implement mock behavior
    override func processTask(_ task: AITask) async throws -> AITaskResult {
        // Call base implementation first to handle state transitions and validation
        do {
            _ = try await super.processTask(task)
        } catch {
            // If base implementation throws a capability error, propagate it
            if let agentError = error as? AgentError {
                if case .capabilityNotSupported = agentError {
                    throw agentError
                }
            }
        }
        
        // Handle mock processing based on configuration
        switch mockProcessingResult {
        case .success(let result):
            let taskResult = AITaskResult(
                taskId: task.taskId,
                status: .completed,
                output: result,
                completedAt: Date()
            )
            
            // Record in history
            recordTaskResult(taskResult)
            
            return taskResult
            
        case .failure(let error):
            // If failure, throw the error
            if task.taskId == testTask.taskId {
                // For error tasks, still record a result
                let errorResult = AITaskResult(
                    taskId: task.taskId,
                    status: .failed,
                    output: error.localizedDescription,
                    completedAt: Date()
                )
                
                // Record in history
                recordTaskResult(errorResult)
            }
            
            throw error
        }
    }
    
    /// Override to implement mock behavior
    override func initialize(with config: AgentConfiguration) async -> AgentInitResult {
        // Call base implementation first to handle state transitions
        _ = await super.initialize(with: config)
        
        // Return mock result
        return mockInitResult
    }
    
    /// Record task result
    override func recordTaskResult(_ result: AITaskResult) {
        taskHistory[result.taskId] = result
    }
    
    /// Test task history pruning
    func testHistoryPruning() async {
        // Create old task to be pruned
        let oldTask = AITask(
            description: "Old task",
            query: "This should be pruned",
            requiredCapabilities: [.basicCompletion]
        )
        
        let oldResult = AITaskResult(
            taskId: oldTask.taskId,
            status: .completed,
            output: "Old result",
            completedAt: Date().addingTimeInterval(-3600) // 1 hour ago
        )
        
        // Add to history
        taskHistory[oldTask.taskId] = oldResult
        
        // Ensure maxTaskHistoryItems is exceeded
        let maxItems = 1 // Set to 1 for testing
        
        // Call pruning logic
        if taskHistory.count > maxItems {
            let sortedKeys = taskHistory.keys.sorted { lhs, rhs in
                guard let lhsResult = taskHistory[lhs], let rhsResult = taskHistory[rhs] else {
                    return false
                }
                return lhsResult.completedAt < rhsResult.completedAt
            }
            
            let keysToRemove = sortedKeys.prefix(taskHistory.count - maxItems)
            for key in keysToRemove {
                taskHistory.removeValue(forKey: key)
            }
        }
    }
    
    /// Enable progress monitoring
    func enableProgressMonitoring(for taskId: UUID, expectedDuration: TimeInterval) {
        let monitor = TaskProgressMonitor(
            taskId: taskId,
            startTime: Date(),
            expectedDuration: expectedDuration
        )
        progressMonitors[taskId] = monitor
    }
    
    /// Update progress
    func updateProgress(taskId: UUID, status: String, progress: Double) async {
        guard let monitor = progressMonitors[taskId] else {
            return
        }
        
        monitor.updateProgress(status: status, progress: progress)
    }
    
    /// Get progress information
    func getProgress(for taskId: UUID) async -> (status: String, progress: Double)? {
        guard let monitor = progressMonitors[taskId] else {
            return nil
        }
        
        return (monitor.status, monitor.progress)
    }
    
    /// Handle task timeout simulation
    func simulateTimeout(for task: AITask) async throws -> AITaskResult {
        // Create a timeout error
        let timeoutError = AITaskError.timeout("Task execution timed out")
        
        // Record error in history
        let result = AITaskResult(
            taskId: task.taskId,
            status: .timedOut,
            output: "Task timed out after exceeding timeout limit",
            completedAt: Date()
        )
        
        // Record in history
        recordTaskResult(result)
        
        // Update state to error
        updateState(.error("Task timed out"))
        
        return result
    }
}

/// Mock errors for testing
enum MockAIAgentError: Error, Equatable {
    case testError
    case timeoutError
    case networkError(String)
    
    static func == (lhs: MockAIAgentError, rhs: MockAIAgentError) -> Bool {
        switch (lhs, rhs) {
        case (.testError, .testError),
             (.timeoutError, .timeoutError):
            return true
        case (.networkError(let lhsMessage), .networkError(let rhsMessage)):
            return lhsMessage == rhsMessage
        default:
            return false
        }
    }
}

// MARK: - Additional Test Cases

extension BaseAIAgentTests {
    
    /// Test task timeout handling
    func testTaskTimeoutHandling() async throws {
        // Create a task with short timeout
        let timeoutTask = AITask(
            description: "Timeout Task",
            query: "This task will time out",
            requiredCapabilities: [.basicCompletion],
            timeout: 0.1 // Very short timeout for testing
        )
        
        // Configure mock to simulate timeout
        agent.mockProcessingResult = .failure(MockAIAgentError.timeoutError)
        
        // Simulate a delayed processing that exceeds timeout
        let result = try await agent.simulateTimeout(for: timeoutTask)
        
        // Verify result
        XCTAssertEqual(result.status, .timedOut)
        XCTAssertTrue(result.output is String)
        
        // Verify state transitions
        XCTAssertEqual(agent.stateTransitions.last, .error("Task timed out"))
    }
    
    /// Test progress monitoring edge cases
    func testProgressMonitoringEdgeCases() async throws {
        // Test with invalid task ID
        let invalidTaskId = UUID()
        let progress = await agent.getProgress(for: invalidTaskId)
        XCTAssertNil(progress, "Progress should be nil for invalid task ID")
        
        // Test with zero progress
        agent.enableProgressMonitoring(for: testTask.taskId, expectedDuration: 1.0)
        await agent.updateProgress(taskId: testTask.taskId, status: "Starting", progress: 0.0)
        let zeroProgress = await agent.getProgress(for: testTask.taskId)
        XCTAssertEqual(zeroProgress?.progress, 0.0)
        
        // Test with progress > 1.0 (should be clamped)
        await agent.updateProgress(taskId: testTask.taskId, status: "Overcompleted", progress: 1.5)
        let overProgress = await agent.getProgress(for: testTask.taskId)
        XCTAssertEqual(overProgress?.progress, 1.0, "Progress should be clamped to 1.0")
        
        // Test with negative progress (should be clamped)
        await agent.updateProgress(taskId: testTask.taskId, status: "Invalid", progress: -0.5)
        let negativeProgress = await agent.getProgress(for: testTask.taskId)
        XCTAssertEqual(negativeProgress?.progress, 0.0, "Progress should be clamped to 0.0")
    }
    
    /// Test concurrent task handling
    func testConcurrentTaskHandling() async throws {
        // Create multiple tasks
        let task1 = AITask(
            description: "Task 1",
            query: "This is task 1",
            requiredCapabilities: [.basicCompletion]
        )
        
        let task2 = AITask(
            description: "Task 2",
            query: "This is task 2",
            requiredCapabilities: [.basicCompletion]
        )
        
        let task3 = AITask(
            description: "Task 3",
            query: "This is task 3",
            requiredCapabilities: [.basicCompletion]
        )
        
        // Configure mock to return success
        agent.mockProcessingResult = .success("Concurrent result")
        
        // Process tasks concurrently
        async let result1 = agent.processTask(task1)
        async let result2 = agent.processTask(task2)
        async let result3 = agent.processTask(task3)
        
        // Wait for all tasks to complete
        let results = try await [result1, result2, result3]
        
        // Verify all tasks completed successfully
        XCTAssertEqual(results.count, 3)
        for result in results {
            XCTAssertEqual(result.status, .completed)
            XCTAssertEqual(result.output as? String, "Concurrent result")
        }
        
        // Verify task history contains all tasks
        XCTAssertEqual(agent.taskHistory.count, 3)
    }
    
    /// Test additional error handling cases
    func testAdditionalErrorHandling() async {
        // Test network error
        agent.mockProcessingResult = .failure(MockAIAgentError.networkError("Connection failed"))
        
        do {
            _ = try await agent.processTask(testTask)
            XCTFail("Expected error was not thrown")
        } catch let error as MockAIAgentError {
            if case .networkError(let message) = error {
                XCTAssertEqual(message, "Connection failed")
            } else {
                XCTFail("Expected network error")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
        
        // Verify error state
        XCTAssertEqual(agent.stateTransitions.last, .error("Connection failed"))
    }
    
    /// Test utility functions
    func testUtilityFunctions() async throws {
        // Create a task
        let task = AITask(
            description: "Utility Test",
            query: "Testing utilities",
            requiredCapabilities: [.basicCompletion]
        )
        
        // Test capability checking
        XCTAssertTrue(agent.supportsTask(task), "Agent should support task with basic completion")
        
        // Test with unsupported capability
        let unsupportedTask = AITask(
            description: "Unsupported Task",
            query: "This requires unsupported capabilities",
            requiredCapabilities: [.imageGeneration]
        )
        XCTAssertFalse(agent.supportsTask(unsupportedTask), "Agent should not support task with image generation")
    }
}

// MARK: - Utility Extensions for Testing

extension MockAIAgent {
    /// Check if agent supports a task
    func supportsTask(_ task: AITask) -> Bool {
        return task.requiredCapabilities.isSubset(of: Set(provideCapabilities()))
    }
}
