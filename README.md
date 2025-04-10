# AI Collaborator

[![Swift 6](https://img.shields.io/badge/Swift-6-orange.svg)](https://swift.org)
[![macOS 15+](https://img.shields.io/badge/macOS-15+-blue.svg)](https://www.apple.com/macos/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

## Overview

AI Collaborator is a Swift-based framework designed to facilitate seamless collaboration between AI agents and human users. It provides a structured environment for AI agents to contribute to software development, assist with problem-solving, and automate repetitive tasks.

### Key Features

- **AI Agent Integration**: Simple API for connecting various AI models
- **Context Preservation**: Maintains conversation and task history for improved collaboration
- **Code Analysis**: Tools for AI agents to understand, modify, and generate code
- **Multi-agent Orchestration**: Coordinate multiple specialized AI agents
- **Human-AI Collaboration Framework**: Structured protocols for effective teamwork

## Installation

### Prerequisites

- macOS 15.0+
- Xcode 16.0+
- Swift 6

### Using Swift Package Manager

Add AICollaborator as a dependency in your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/noktirnal42/AICollaborator.git", from: "0.1.0")
]
```

Then include it in your target:

```swift
.target(
    name: "YourTarget",
    dependencies: ["AICollaborator"]
)
```

### Manual Installation

1. Clone the repository:
   ```bash
   git clone git@github.com:noktirnal42/AICollaborator.git
   cd AICollaborator
   ```

2. Build the project:
   ```bash
   swift build
   ```

3. Run tests to verify installation:
   ```bash
   swift test
   ```

## Quick Start Guide for AI Agents

This section provides structured information specifically formatted for AI agents to quickly understand and interface with the AICollaborator framework.

### Initial Connection

```swift
import AICollaborator

// Initialize the collaborator instance
let collaborator = AICollaborator()

// Connect AI agent with required credentials
collaborator.connect(agentType: .llm, 
                     credentials: AICredentials(apiKey: "YOUR_API_KEY"))
```

### Task Execution Pattern

AI agents should follow this pattern when executing tasks:

1. **Parse Input**: Extract query, context, and constraints
2. **Form Plan**: Create executable steps based on the parsed input
3. **Execute**: Perform actions while maintaining context
4. **Validate**: Check results against expectations
5. **Present**: Return results in the expected format

### Sample Agent Integration

```swift
// Example of an AI agent implementing the Collaborator protocol
struct MyAIAgent: AICollaboratorAgent {
    func processTask(_ task: AITask) -> AITaskResult {
        // Task processing logic
        return AITaskResult(status: .completed, output: "Task result")
    }
    
    func provideCapabilities() -> [AICapability] {
        return [.codeGeneration, .textAnalysis]
    }
}

// Register with the collaborator
collaborator.register(agent: MyAIAgent())
```

## API Reference Overview

### Core Components

| Component | Purpose | Key Methods |
|-----------|---------|-------------|
| `AICollaborator` | Main entry point | `connect()`, `register()`, `execute()` |
| `AITask` | Task representation | `parseFromInput()`, `validate()` |
| `AIAgent` | Agent protocol | `processTask()`, `provideCapabilities()` |
| `AIContext` | Context management | `store()`, `retrieve()`, `update()` |

### Key Protocols

- `AICollaboratorAgent`: Interface for AI agents
- `TaskExecutable`: Protocol for task execution
- `ContextAware`: Protocol for context-aware components
- `HumanInteractive`: Protocol for human interaction capabilities

For detailed API documentation, see the [API Reference](Documentation/APIReference.md).

## Project Structure

```
AICollaborator/
├── Sources/
│   ├── AICollaboratorApp/        # Main application code
│   │   ├── Core/                 # Core functionality
│   │   ├── Agents/               # Agent implementations
│   │   ├── Tasks/                # Task definitions
│   │   └── Utils/                # Utility functions
│   └── Resources/                # Resource files
├── Tests/                        # Test suite
├── Documentation/                # Detailed documentation
├── Examples/                     # Example implementations
└── .github/                      # GitHub configuration
```

## Development Setup

### Environment Setup

1. Install required tools:
   ```bash
   xcode-select --install
   ```

2. Set up environment variables:
   ```bash
   export GEMINI_API_KEY="your_api_key_here"
   ```

3. Install additional dependencies:
   ```bash
   brew install gh
   ```

### Development Workflow

1. Create a feature branch:
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. Make your changes and test:
   ```bash
   swift test
   ```

3. Submit a pull request to the `dev` branch

### Coding Standards

- Follow Swift API Design Guidelines
- Include documentation comments for all public APIs
- Write unit tests for new functionality
- Format code using SwiftFormat

## Additional Documentation

- [Detailed API Reference](Documentation/APIReference.md)
- [Implementation Guide](Documentation/ImplementationGuide.md)
- [AI Agent Integration Tutorial](Documentation/AIAgentIntegration.md)
- [Contributing Guidelines](CONTRIBUTING.md)
- [Code of Conduct](CODE_OF_CONDUCT.md)
- [Wiki](https://github.com/noktirnal42/AICollaborator/wiki)

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
