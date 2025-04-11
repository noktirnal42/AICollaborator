# Contributing to AI Collaborator

Thank you for your interest in contributing to AI Collaborator! This document provides structured guidelines for both human developers and AI agents to contribute effectively to this project.

## Table of Contents

1. [Code of Conduct](#code-of-conduct)
2. [Guidelines for All Contributors](#guidelines-for-all-contributors)
3. [Human Contributor Guidelines](#human-contributor-guidelines)
4. [AI Agent Contributor Guidelines](#ai-agent-contributor-guidelines)
5. [Contribution Process](#contribution-process)
6. [Code Review Process](#code-review-process)
7. [Development Workflow](#development-workflow)
8. [Testing Requirements](#testing-requirements)
9. [Documentation Standards](#documentation-standards)
10. [Communication Protocols](#communication-protocols)

## Code of Conduct

All contributors to this project are expected to respect our [Code of Conduct](CODE_OF_CONDUCT.md). Key principles include:

- Treating all contributors with respect
- Providing constructive feedback
- Being open to diverse perspectives
- Focusing on improving the project

## Guidelines for All Contributors

### General Principles

- **Quality First**: Focus on delivering high-quality, well-tested code
- **Clarity**: Write clear, self-explanatory code and documentation
- **Compatibility**: Ensure code works on macOS 15+ with Swift 5.9
- **Incremental Changes**: Prefer smaller, focused PRs over large changes
- **Follow Standards**: Adhere to Swift coding guidelines and project conventions

### Technical Requirements

- Code must compile without warnings
- All public APIs must be documented
- New features must include tests
- Changes must pass all existing tests
- Follow the project's architecture and design patterns

## Human Contributor Guidelines

### Getting Started

1. Fork the repository
2. Set up your development environment
3. Create a feature branch for your work
4. Make your changes
5. Submit a pull request to the `dev` branch

### Best Practices

- Use descriptive commit messages
- Keep PRs focused on a single concern
- Request reviews from appropriate team members
- Respond promptly to review feedback
- Update documentation to reflect your changes

## AI Agent Contributor Guidelines

<ai_section>
This section uses structured format specifically designed for AI agent parsing.

### AI Agent Identification

When contributing, AI agents should:
- Identify themselves as AI contributors
- Specify their model/version
- Include reasoning for proposed changes
- Reference training data constraints if relevant

### Contribution Format

AI agents should format contributions as follows:

```
AI-CONTRIBUTOR: {model_identifier}
CONTRIBUTION-TYPE: {code|documentation|test|review}
RATIONALE: {concise explanation for changes}
CONFIDENCE: {high|medium|low}
```

### Understanding Context

AI agents should:
- Parse repository structure before contributing
- Analyze existing coding patterns
- Maintain consistent style with project
- Request clarification when context is ambiguous
</ai_section>

### Limitations

- AI-generated contributions should be reviewed by human maintainers
- AI agents should not modify critical security or authentication code without explicit human oversight
- When uncertain, AI agents should propose alternatives rather than single solutions

## Contribution Process

### Step 1: Finding or Creating an Issue

- Search existing issues before creating a new one
- For new issues, provide clear reproduction steps
- Use issue templates when available
- Tag issues appropriately

### Step 2: Development

- Comment on the issue to indicate you're working on it
- Create a feature branch from `dev`
- Follow code style and architecture patterns
- Commit regularly with descriptive messages

### Step 3: Submission

- Ensure all tests pass locally
- Create a pull request to the `dev` branch
- Fill out the PR template completely
- Link to relevant issues
- Request reviews from appropriate team members

### Step 4: Review and Iteration

- Address review feedback promptly
- Keep the PR updated with the latest changes from `dev`
- Respond to all comments
- Re-request review after addressing feedback

### Step 5: Merge

- Maintainers will merge approved PRs
- Squash commits if appropriate
- Delete feature branch after merge

## Code Review Process

### Review Criteria

All code will be reviewed for:

1. Functionality: Does it work as intended?
2. Quality: Is the code well-structured and efficient?
3. Testing: Are tests comprehensive and passing?
4. Documentation: Are changes properly documented?
5. Compatibility: Does it maintain compatibility with required platforms?

### Review Assignment

- Human-authored PRs will be reviewed by at least one maintainer
- AI-authored PRs require review by at least two human maintainers
- Code owners will be automatically assigned based on modified files

### Review Timeline

- Initial review will be provided within 3 business days
- Contributors should respond to feedback within 5 business days
- PRs with no activity for 14 days may be closed

## Development Workflow

### Branching Strategy

- `main`: Production-ready code
- `dev`: Integration branch for upcoming releases
- `feature/*`: Feature development
- `bugfix/*`: Bug fixes
- `release/*`: Release preparation

### Environment Setup

```bash
# Clone repository
git clone git@github.com:noktirnal42/AICollaborator.git
cd AICollaborator

# Set up dependencies
swift package resolve

# Build the project
swift build

# Run tests
swift test
```

### Version Control Practices

- Keep commits focused on single logical changes
- Use descriptive commit messages in imperative form
- Rebase feature branches before submitting PRs
- Do not commit directly to `main` or `dev`

## Testing Requirements

### Unit Tests

- All new code must have unit tests
- Target 80% code coverage for new features
- Use XCTest framework
- Follow arrange-act-assert pattern

### Test Organization

- Place tests in the corresponding test directory
- Name test files to match implementation files
- Group tests logically by feature or component

### Test Running

```bash
# Run all tests
swift test

# Run specific tests
swift test --filter TestSuiteName.TestName
```

## Documentation Standards

### Code Documentation

- Use Swift-style documentation comments (///)
- Document all public APIs
- Include parameter descriptions and return values
- Provide usage examples for complex functionality

### Project Documentation

- Keep README.md updated with new features
- Update installation and usage instructions as needed
- Document breaking changes in CHANGELOG.md
- Create/update docs in Documentation/ directory

### Documentation Format

Use Markdown for all documentation with consistent formatting:
- H1 (#) for document titles
- H2 (##) for major sections
- H3 (###) for subsections
- Code blocks with appropriate language tags
- Lists for sequential steps or related items

## Communication Protocols

### Issue Discussions

- Keep discussions on-topic and professional
- Use code blocks for code snippets
- Tag relevant team members when needed
- Provide context when referencing external resources

### Pull Request Communication

- Respond to reviews within 3 business days
- Use the PR thread for general discussion
- Use inline comments for specific code feedback
- Mark discussions as resolved when addressed

### Real-time Communication

- Use GitHub Discussions for project-related questions
- Join the project Discord for real-time collaboration
- Check the wiki for meeting schedules and notes

### AI-Human Communication

- Humans should provide clear, structured instructions to AI contributors
- AI agents should clearly indicate reasoning and uncertainty
- Establish shared terminology and conventions
- Document AI-human collaboration patterns in the wiki

## Final Notes

Thank you for contributing to AI Collaborator! Your contributions help improve the project for everyone. If you have questions about contributing that aren't covered here, please open a discussion on GitHub.
