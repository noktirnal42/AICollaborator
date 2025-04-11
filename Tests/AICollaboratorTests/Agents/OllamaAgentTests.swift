//
//  OllamaAgentTests.swift
//  AICollaboratorTests
//
//  Created: 2025-04-10
//

import XCTest
@testable import AICollaboratorApp

/// Tests for the OllamaAgent implementation
final class OllamaAgentTests: XCTestCase {
    
    // MARK: - Properties
    
    /// Test Ollama service
    private var ollamaService: MockOllamaService!
    
    /// Test Ollama agent
    private var agent: OllamaAgent!
    
    /// Test task for reuse
    private var testTask: AITask!
    
    // MARK: - Setup and Teardown
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Create mock Ollama service
        ollamaService = MockOllamaService()
        
        // Create test agent with mock service
        agent = OllamaAgent(
            ollamaService: ollamaService,
            initialModel: "llama3:8b",
            configuration: AgentConfiguration(
                temperature: 0.7,
                modelId: "llama3:8b"
            )
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
        ollamaService = nil
        agent = nil
        testTask = nil
        
        try await super.tearDown()
    }
    
    // MARK: - Model Selection Tests
    
    /// Test model initialization
    func testModelInitialization() async throws {
        // Verify initial model set correctly
        XCTAssertEqual(ollamaService.selectedModel, "llama3:8b")
        
        // Verify model family detected correctly
        let modelFamily = await agent.modelFamily
        XCTAssertEqual(String(describing: modelFamily), "llama")
        
        // Verify capabilities were set from model family
        let capabilities = agent.provideCapabilities()
        XCTAssertTrue(capabilities.contains(.basicCompletion))
        XCTAssertTrue(capabilities.contains(.textAnalysis))
        XCTAssertTrue(capabilities.contains(.conversational))
        XCTAssertFalse(capabilities.contains(.codeGeneration)) // Not in llama family
    }
    
    /// Test model selection
    func testModelSelection() async throws {
        // Prepare mock service with available models
        let testModels = [
            OllamaService.OllamaModel(
                name: "codellama:7b",
                size: 4_000_000_000,
                modifiedAt: Date(),
                digest: "abc123",
                details: nil
            ),
            OllamaService.OllamaModel(
                name: "mixtral:8x7b",
                size: 12_000_000_000,
                modifiedAt: Date(),
                digest: "def456",
                details: nil
            )
        ]
        ollamaService.availableModels = testModels
        
        // Select a different model
        try await agent.selectModel("codellama:7b")
        
        // Verify model selected in service
        XCTAssertEqual(ollamaService.selectedModel, "codellama:7b")
        
        // Verify model family updated
        let modelFamily = await agent.modelFamily
        XCTAssertEqual(String(describing: modelFamily), "codellama")
        
        // Verify capabilities were updated
        let capabilities = agent.provideCapabilities()
        XCTAssertTrue(capabilities.contains(.basicCompletion))
        XCTAssertTrue(capabilities.contains(.codeGeneration)) // CodeLlama has this
        XCTAssertTrue(capabilities.contains(.codeCompletion)) // CodeLlama has this
    }
    
    /// Test model selection error handling
    func testModelSelectionErrors() async {
        // Configure mock to throw error
        ollamaService.shouldFailModelSelection = true
        
        do {
            try await agent.selectModel("nonexistent-model")
            XCTFail("Expected error was not thrown")
        } catch let error as OllamaAgentError {
            if case .modelNotFound(let model) = error {
                XCTAssertEqual(model, "nonexistent-model")
            } else {
                XCTFail("Expected modelNotFound error")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    // MARK: - Model Family Detection Tests
    
    /// Test model family detection
    func testModelFamilyDetection() async {
        // Test various model names
        XCTAssertEqual(String(describing: OllamaAgent.ModelFamily.fromModelName("llama3:8b")), "llama")
        XCTAssertEqual(String(describing: OllamaAgent.ModelFamily.fromModelName("codellama:7b")), "codellama")
        XCTAssertEqual(String(describing: OllamaAgent.ModelFamily.fromModelName("mistral:7b")), "mistral")
        XCTAssertEqual(String(describing: OllamaAgent.ModelFamily.fromModelName("phi3:mini")), "phi")
        XCTAssertEqual(String(describing: OllamaAgent.ModelFamily.fromModelName("gemma:7b")), "gemma")
        XCTAssertEqual(String(describing: OllamaAgent.ModelFamily.fromModelName("mixtral:8x7b")), "mixtral")
        
        // Test unknown model
        let unknownFamily = OllamaAgent.ModelFamily.fromModelName("unknown-model")
        if case .other(let name) = unknownFamily {
            XCTAssertEqual(name, "unknown-model")
        } else {
            XCTFail("Expected other model family")
        }
    }
    
    /// Test model family capabilities
    func testModelFamilyCapabilities() async {
        // Test capabilities for different families
        let llamaCapabilities = OllamaAgent.ModelFamily.llama.defaultCapabilities
        XCTAssertTrue(llamaCapabilities.contains(.basicCompletion))
        XCTAssertTrue(llamaCapabilities.contains(.conversational))
        XCTAssertFalse(llamaCapabilities.contains(.codeGeneration))
        
        let codeCapabilities = OllamaAgent.ModelFamily.codellama.defaultCapabilities
        XCTAssertTrue(codeCapabilities.contains(.codeGeneration))
        XCTAssertTrue(codeCapabilities.contains(.codeCompletion))
        
        let otherCapabilities = OllamaAgent.ModelFamily.other("test").defaultCapabilities
        XCTAssertEqual(otherCapabilities.count, 1)
        XCTAssertTrue(otherCapabilities.contains(.basicCompletion))
    }
    
    // MARK: - Temperature Optimization Tests
    
    /// Test temperature recommendations by model family
    func testTemperatureOptimization() async {
        // Test temperature recommendations
        XCTAssertEqual(OllamaAgent.ModelFamily.codellama.recommendedTemperature, 0.3) // Lower for code
        XCTAssertEqual(OllamaAgent.ModelFamily.llama.recommendedTemperature, 0.7) // Normal for general
        XCTAssertEqual(OllamaAgent.ModelFamily.gemma.recommendedTemperature, 0.8) // Higher for creativity
        
        // Test temperature setting during model selection
        ollamaService.availableModels = [
            OllamaService.OllamaModel(
                name: "codellama:7b",
                size: 4_000_000_000,
                modifiedAt: Date(),
                digest: "abc123",
                details: nil
            )
        ]
        
        // Select code model
        try? await agent.selectModel("codellama:7b")
        
        // Verify temperature was adjusted
        XCTAssertEqual(agent.configuration.temperature, 0.3)
    }
    
    // MARK: - Prompt Optimization Tests
    
    /// Test code prompt optimization
    func testCodePromptOptimization() async throws {
        // Select code model
        ollamaService.availableModels = [
            OllamaService.OllamaModel(
                name: "codellama:7b",
                size: 4_000_000_000,
                modifiedAt: Date(),
                digest: "abc123",
                details: nil
            )
        ]
        try await agent.selectModel("codellama:7b")
        
        // Create a code task
        let codeTask = AITask(
            description: "Generate code",
            query: "Implement a factorial function",
            requiredCapabilities: [.codeGeneration],
            context: ["language": "swift"]
        )
        
        // Process task
        ollamaService.mockOutputText = "func factorial(n: Int) -> Int {\n    if n <= 1 { return 1 }\n    return n * factorial(n - 1)\n}"
        
        let result = try await agent.processTask(codeTask)
        
        // Verify prompt was optimized
        XCTAssertTrue(ollamaService.lastProcessedQuery.contains("Generate swift code"))
        XCTAssertTrue(ollamaService.lastProcessedQuery.contains("Implement a factorial function"))
        
        // Verify result
        XCTAssertEqual(result.status, .completed)
        XCTAssertTrue((result.output as? String)?.contains("func factorial") ?? false)
    }
    
    /// Test conversation prompt optimization
    func testConversationPromptOptimization() async throws {
        // Create a conversation task with history
        let conversationTask = AITask(
            description: "Chat response",
            query: "What's the weather like?",
            context: ["conversationHistory": [
                "Hi there!", 
                "Hello! How can I help you today?"
            ]],
            requiredCapabilities: [.conversational]
        )
        
        // Process task
        ollamaService.mockOutputText = "I don't have real-time weather data, but I can help you find that information."
        
        let result = try await agent.processTask(conversationTask)
        
        // Verify prompt was formatted as conversation
        XCTAssertTrue(ollamaService.lastProcessedQuery.contains("Continue this conversation"))
        XCTAssertTrue(ollamaService.lastProcessedQuery.contains("User: Hi there!"))
        XCTAssertTrue(ollamaService.lastProcessedQuery.contains("Assistant: Hello! How can I help you today?"))
        XCTAssertTrue(ollamaService.lastProcessedQuery.contains("User: What's the weather like?"))
        
        // Verify result
        XCTAssertEqual(result.status, .completed)
    }
    
    // MARK: - Response Streaming Tests
    
    /// Test response streaming
    func testResponseStreaming() async throws {
        // Configure mock for streaming
        ollamaService.streamingChunks = ["This ", "is ", "a ", "streaming ", "response."]
        
        // Create task
        let task = AITask(
            description: "Test streaming",
            query: "Generate a streaming response",
            requiredCapabilities: [.basicCompletion]
        )
        
        // Process task
        let result = try await agent.processTask(task)
        
        // Verify all chunks were collected
        XCTAssertEqual(result.output as? String, "This is a streaming response.")
        
        // Verify streaming options were passed correctly
        XCTAssertEqual(ollamaService.lastStreamingOptions?.temperature, 0.7)
        XCTAssertEqual(ollamaService.lastStreamingOptions?.numPredict, 512)
    }
    
    // MARK: - Cache Management Tests
    
    /// Test response caching
    func testResponseCaching() async throws {
        // Configure mock to return predictable response
        ollamaService.mockOutputText = "Cached response"
        
        // Process identical tasks
        let result1 = try await agent.processTask(testTask)
        XCTAssertEqual(result1.output as? String, "Cached response")
        
        // Verify task was processed by service
        XCTAssertEqual(ollamaService.processCount, 1)
        
        // Process identical task again (should use cache)
        let result2 = try await agent.processTask(testTask)
        XCTAssertEqual(result2.output as? String, "Cached response")
        
        // Verify service wasn't called again
        XCTAssertEqual(ollamaService.processCount, 1)
        
        // Process different task (should not use cache)
        let differentTask = AITask(
            description: "Different task",
            query: "This is a different query",
            requiredCapabilities: [.basicCompletion]
        )
        
        ollamaService.mockOutputText = "Different response"
        let result3 = try await agent.processTask(differentTask)
        XCTAssertEqual(result3.output as? String, "Different response")
        
        // Verify service was called again
        XCTAssertEqual(ollamaService.processCount, 2)
    }
    
    /// Test cache expiration
    func testCacheExpiration() async throws {
        // Configure mock
        ollamaService.mockOutputText = "Cached response"
        
        // Process task
        let result1 = try await agent.processTask(testTask)
        XCTAssertEqual(result1.output as? String, "Cached response")
        XCTAssertEqual(ollamaService.processCount, 1)
        
        // Modify cache expiration time to a very small value
        await agent.setCacheExpirationForTesting(0.1) // 100ms
        
        // Wait for cache to expire
        try await Task.sleep(for: .seconds(0.2))
        
        // Process same task again (should not use cache)
        ollamaService.mockOutputText = "New response"
        let result2 = try await agent.processTask(testTask)
        XCTAssertEqual(result2.output as? String, "New response")
        
        // Verify service was called again
        XCTAssertEqual(ollamaService.processCount, 2)
    }
    
    // MARK: - Error Handling Tests
    
    /// Test model not found error
    func testModelNotFoundError() async {
        ollamaService.shouldFailModelSelection = true
        ollamaService.errorToThrow = OllamaServiceError.modelNotFound("test-model")
        
        do {
            try await agent.selectModel("test-model")
            XCTFail("Expected error was not thrown")
        } catch let error as OllamaServiceError {
            if case .modelNotFound(let model) = error {
                XCTAssertEqual(model, "test-model")
            } else {
                XCTFail("Expected modelNotFound error")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    /// Test no model selected error
    func testNoModelSelectedError() async {
        // Create agent without initial model
        let noModelAgent =

