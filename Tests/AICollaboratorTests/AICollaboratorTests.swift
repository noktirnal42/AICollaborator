import Testing
import Foundation
@testable import AICollaboratorApp

// MARK: - AITask Tests

@Suite("AITask Tests")
struct AITaskTests {

    @Test("AITask initializes with correct properties")
    func testAITaskInitialization() {
        let task = AITask(
            description: "Test task",
            query: "What is 2+2?",
            input: .text("What is 2+2?"),
            requiredCapabilities: [.basicCompletion]
        )

        #expect(task.description == "Test task")
        #expect(task.query == "What is 2+2?")
        #expect(task.requiredCapabilities == [.basicCompletion])
        #expect(task.priority == .normal)
    }

    @Test("AITask factory method creates text generation task")
    func testTextGenerationFactory() {
        let task = AITask.textGeneration(prompt: "Hello world", maxTokens: 100)

        #expect(task.description == "Generate text based on prompt")
        #expect(task.requiredCapabilities.contains(.textGeneration))
        #expect(task.parameters?["maxTokens"] == "100")
    }

    @Test("AICapability conforms to CaseIterable")
    func testAICapabilityCaseIterable() {
        let allCases = AICapability.allCases
        #expect(!allCases.isEmpty)
        #expect(allCases.contains(.basicCompletion))
        #expect(allCases.contains(.conversational))
        #expect(allCases.contains(.textGeneration))
    }
}

// MARK: - AITaskResult Tests

@Suite("AITaskResult Tests")
struct AITaskResultTests {

    @Test("AITaskResult convenience init with string output")
    func testConvenienceInit() {
        let result = AITaskResult(
            taskId: UUID(),
            status: .completed,
            output: "Test output"
        )

        #expect(result.isSuccessful == true)
        #expect(result.outputText == "Test output")
    }

    @Test("AITaskResult isSuccessful reflects status")
    func testIsSuccessful() {
        let successResult = AITaskResult(status: .completed, output: "ok")
        let failResult = AITaskResult(status: .failed, output: "error")

        #expect(successResult.isSuccessful == true)
        #expect(failResult.isSuccessful == false)
    }

    @Test("AITaskResult executionTime alias works")
    func testExecutionTimeAlias() {
        let result = AITaskResult(
            taskId: UUID(),
            status: .completed,
            output: "Result",
            executionTime: 1.5
        )

        #expect(result.executionTime == 1.5)
        #expect(result.executionDuration == 1.5)
    }
}

// MARK: - AgentConfiguration Tests

@Suite("AgentConfiguration Tests")
struct AgentConfigurationTests {

    @Test("AgentConfiguration default values")
    func testDefaultValues() {
        let config = AgentConfiguration()

        #expect(config.maxTokens == 4096)
        #expect(config.temperature == 0.7)
        #expect(config.rateLimit == 60)
        #expect(config.timeout == 30.0)
    }

    @Test("AgentConfiguration custom values")
    func testCustomValues() {
        let config = AgentConfiguration(
            maxTokens: 2048,
            temperature: 0.5,
            modelId: "llama3"
        )

        #expect(config.maxTokens == 2048)
        #expect(config.temperature == 0.5)
        #expect(config.modelId == "llama3")
    }
}
