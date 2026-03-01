//
//  GitHubAgent.swift
//  AICollaborator
//
//  Created: 2025-04-10
//

import Foundation

/// Specialized agent for GitHub interactions
public actor GitHubAgent: @preconcurrency AICollaboratorAgent {

    // MARK: - Types

    /// Types of GitHub analysis tasks
    public enum AnalysisType: Sendable {
        case repository
        case pullRequest
        case issue
        case codeReview
        case documentation
        case trends
        case custom(String)
    }

    /// GitHub operation error types
    public enum GitHubAgentError: Error, LocalizedError, Sendable {
        case noActiveRepository
        case operationFailed(String)
        case invalidInput(String)

        public var errorDescription: String? {
            switch self {
            case .noActiveRepository:
                return "No active repository is set"
            case .operationFailed(let message):
                return "Operation failed: \(message)"
            case .invalidInput(let message):
                return "Invalid input: \(message)"
            }
        }
    }

    // MARK: - Properties

    /// GitHub service for API interactions
    private let githubService: GitHubService

    /// Currently active repository
    private var activeRepository: GitHubService.Repository?

    /// Current agent state
    private var state: AgentState = .idle

    // MARK: - Initialization

    /// Initialize a GitHub agent
    /// - Parameters:
    ///   - githubService: GitHub service instance
    ///   - initialRepository: Initial repository to work with
    public init(
        githubService: GitHubService = GitHubService(),
        initialRepository: GitHubService.Repository? = nil
    ) {
        self.githubService = githubService
        self.activeRepository = initialRepository
    }

    // MARK: - AICollaboratorAgent Protocol

    public func processTask(_ task: AITask) async throws -> AITaskResult {
        state = .busy(taskId: task.taskId)
        defer { state = .idle }

        // Determine what kind of GitHub task this is based on query keywords
        let query = task.query.lowercased()

        do {
            let response: String
            if query.contains("list issue") || query.contains("show issue") {
                let issues = try await listIssues()
                response = formatIssueList(issues)
            } else if query.contains("list pr") || query.contains("list pull") {
                let prs = try await listPullRequests()
                response = formatPRList(prs)
            } else if query.contains("repo") || query.contains("repository") {
                if let repo = activeRepository {
                    response = formatRepositoryInfo(repo)
                } else {
                    response = "No active repository set. Use setActiveRepository() first."
                }
            } else {
                response = """
                GitHub Agent is ready. I can help with:
                - Listing issues (include 'list issues' in your query)
                - Listing pull requests (include 'list PRs' or 'list pull requests')
                - Repository information (include 'repository' or 'repo')
                
                Active repository: \(activeRepository.map { $0.fullName } ?? "None")
                """
            }

            return AITaskResult(
                taskId: task.taskId,
                status: .completed,
                output: response
            )
        } catch {
            return AITaskResult(
                taskId: task.taskId,
                status: .failed,
                output: error.localizedDescription
            )
        }
    }

    nonisolated public func provideCapabilities() -> [AICapability] {
        return [.textAnalysis, .dataAnalysis, .summarization, .planning]
    }

    public func getState() -> AgentState {
        return state
    }

    public func initialize(with config: AgentConfiguration) async -> AgentInitResult {
        state = .idle
        return .success
    }

    public func shutdown() async -> Result<Void, Error> {
        state = .terminated
        return .success(())
    }

    // MARK: - Repository Management

    /// Set the active repository
    public func setActiveRepository(_ repository: GitHubService.Repository) async {
        self.activeRepository = repository
        await githubService.setActiveRepository(repository)
    }

    /// Search for GitHub repositories
    public func searchRepositories(query: String, limit: Int = 10) async throws -> [GitHubService.Repository] {
        return try await githubService.searchRepositories(query: query, limit: limit)
    }

    /// Clone the active repository
    public func cloneActiveRepository(options: GitHubService.CloneOptions = .default) async throws -> String {
        guard let repository = activeRepository else {
            throw GitHubAgentError.noActiveRepository
        }
        return try await githubService.cloneRepository(repository, options: options)
    }

    /// Get repository details
    public func getRepositoryDetails(fullName: String) async throws -> GitHubService.Repository {
        let repo = try await githubService.getRepositoryDetails(repoFullName: fullName)
        self.activeRepository = repo
        await githubService.setActiveRepository(repo)
        return repo
    }

    // MARK: - Issue Management

    /// List issues in the active repository
    public func listIssues(
        state issueState: GitHubService.IssueState = .open,
        limit: Int = 30
    ) async throws -> [GitHubService.Issue] {
        guard let repository = activeRepository else {
            throw GitHubAgentError.noActiveRepository
        }
        return try await githubService.listIssues(repository: repository, state: issueState, limit: limit)
    }

    // MARK: - Pull Request Management

    /// List pull requests in the active repository
    public func listPullRequests(
        state prState: GitHubService.PRState = .open,
        limit: Int = 30
    ) async throws -> [GitHubService.PullRequest] {
        guard let repository = activeRepository else {
            throw GitHubAgentError.noActiveRepository
        }
        return try await githubService.listPullRequests(repository: repository, state: prState, limit: limit)
    }

    // MARK: - Analysis

    /// Analyze a repository
    public func analyzeRepository(
        _ repository: GitHubService.Repository,
        type: AnalysisType = .repository
    ) async -> String {
        var analysis = "# Repository Analysis: \(repository.fullName)\n\n"
        analysis += "- **URL:** \(repository.webUrl)\n"
        analysis += "- **Default Branch:** \(repository.defaultBranch)\n"
        analysis += "- **Private:** \(repository.isPrivate ? "Yes" : "No")\n"
        analysis += "- **Has Issues:** \(repository.hasIssues ? "Yes" : "No")\n"
        analysis += "- **Fork:** \(repository.isFork ? "Yes" : "No")\n"
        if let desc = repository.description {
            analysis += "- **Description:** \(desc)\n"
        }

        do {
            let issues = try await githubService.listIssues(repository: repository, limit: 10)
            analysis += "\n## Open Issues (showing up to 10)\n\n"
            if issues.isEmpty {
                analysis += "No open issues.\n"
            } else {
                for issue in issues {
                    analysis += "- **#\(issue.number):** \(issue.title) (by \(issue.creator))\n"
                }
            }
        } catch {
            analysis += "\n## Issues\n\nCould not fetch issues: \(error.localizedDescription)\n"
        }

        do {
            let prs = try await githubService.listPullRequests(repository: repository, limit: 10)
            analysis += "\n## Open Pull Requests (showing up to 10)\n\n"
            if prs.isEmpty {
                analysis += "No open pull requests.\n"
            } else {
                for pr in prs {
                    analysis += "- **#\(pr.number):** \(pr.title) (by \(pr.creator))\n"
                }
            }
        } catch {
            analysis += "\n## Pull Requests\n\nCould not fetch PRs: \(error.localizedDescription)\n"
        }

        return analysis
    }

    // MARK: - Private Helpers

    private func formatIssueList(_ issues: [GitHubService.Issue]) -> String {
        if issues.isEmpty { return "No issues found." }
        var output = "## Open Issues\n\n"
        for issue in issues {
            output += "- **#\(issue.number):** \(issue.title)\n"
            output += "  - Author: \(issue.creator)\n"
            output += "  - Labels: \(issue.labels.isEmpty ? "none" : issue.labels.joined(separator: ", "))\n"
            output += "  - URL: \(issue.webUrl)\n\n"
        }
        return output
    }

    private func formatPRList(_ prs: [GitHubService.PullRequest]) -> String {
        if prs.isEmpty { return "No pull requests found." }
        var output = "## Open Pull Requests\n\n"
        for pr in prs {
            output += "- **#\(pr.number):** \(pr.title)\n"
            output += "  - Author: \(pr.creator)\n"
            output += "  - Branch: \(pr.sourceBranch) → \(pr.targetBranch)\n"
            output += "  - URL: \(pr.webUrl)\n\n"
        }
        return output
    }

    private func formatRepositoryInfo(_ repo: GitHubService.Repository) -> String {
        var output = "## Repository: \(repo.fullName)\n\n"
        output += "- **URL:** \(repo.webUrl)\n"
        output += "- **Default Branch:** \(repo.defaultBranch)\n"
        output += "- **Private:** \(repo.isPrivate ? "Yes" : "No")\n"
        if let desc = repo.description { output += "- **Description:** \(desc)\n" }
        return output
    }
}
