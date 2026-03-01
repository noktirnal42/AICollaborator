//
//  GitHubService.swift
//  AICollaborator
//
//  Created: 2025-04-10
//

import Foundation

/// Service for interacting with GitHub repositories and the GitHub CLI
public actor GitHubService {
    // MARK: - Types

    /// Repository information
    public struct Repository: Identifiable, Equatable, Codable, Sendable {
        public let owner: String
        public let name: String

        public var fullName: String { "\(owner)/\(name)" }
        public var sshUrl: String { "git@github.com:\(fullName).git" }
        public var httpsUrl: String { "https://github.com/\(fullName).git" }
        public var webUrl: String { "https://github.com/\(fullName)" }
        public var cloneUrl: String { sshUrl }

        public var defaultBranch: String = "main"
        public var description: String?
        public var isPrivate: Bool = false
        public var hasIssues: Bool = true
        public var isFork: Bool = false

        public var id: String { fullName }
    }

    /// Issue information
    public struct Issue: Identifiable, Equatable, Codable, Sendable {
        public let number: Int
        public let title: String
        public let body: String?
        public let state: IssueState
        public let creator: String
        public let assignees: [String]
        public let labels: [String]
        public let createdAt: Date
        public let updatedAt: Date
        public let closedAt: Date?
        public let repository: Repository

        public var webUrl: String { "https://github.com/\(repository.fullName)/issues/\(number)" }
        public var id: String { "\(repository.fullName)#\(number)" }
    }

    /// Pull request information
    public struct PullRequest: Identifiable, Equatable, Codable, Sendable {
        public let number: Int
        public let title: String
        public let body: String?
        public let state: PRState
        public let creator: String
        public let assignees: [String]
        public let labels: [String]
        public let createdAt: Date
        public let updatedAt: Date
        public let closedAt: Date?
        public let mergedAt: Date?
        public let sourceBranch: String
        public let targetBranch: String
        public let repository: Repository

        public var webUrl: String { "https://github.com/\(repository.fullName)/pull/\(number)" }
        public var isMerged: Bool { mergedAt != nil }
        public var id: String { "\(repository.fullName)#\(number)" }
    }

    /// Repository clone options
    public struct CloneOptions: Sendable {
        public var directory: String?
        public var branch: String?
        public var shallow: Bool = false
        public var recurseSubmodules: Bool = true

        public static let `default` = CloneOptions()

        public init(directory: String? = nil, branch: String? = nil,
                    shallow: Bool = false, recurseSubmodules: Bool = true) {
            self.directory = directory
            self.branch = branch
            self.shallow = shallow
            self.recurseSubmodules = recurseSubmodules
        }
    }

    /// Issue state
    public enum IssueState: String, Codable, Sendable {
        case open
        case closed
    }

    /// Pull request state
    public enum PRState: String, Codable, Sendable {
        case open
        case closed
        case merged
    }

    /// GitHub service error types
    public enum GitHubServiceError: Error, LocalizedError {
        case commandFailed(String, Int)
        case parseError(String)
        case invalidRepository(String)
        case notAuthenticated
        case permissionDenied
        case networkError(String)
        case rateLimitExceeded
        case repositoryNotFound(String)

        public var errorDescription: String? {
            switch self {
            case .commandFailed(let command, let exitCode):
                return "GitHub CLI command failed: '\(command)' (exit code: \(exitCode))"
            case .parseError(let details):
                return "Failed to parse GitHub CLI output: \(details)"
            case .invalidRepository(let repo):
                return "Invalid repository: \(repo)"
            case .notAuthenticated:
                return "Not authenticated with GitHub. Run 'gh auth login' first."
            case .permissionDenied:
                return "Permission denied for repository operation"
            case .networkError(let details):
                return "Network error: \(details)"
            case .rateLimitExceeded:
                return "GitHub API rate limit exceeded"
            case .repositoryNotFound(let repo):
                return "Repository not found: \(repo)"
            }
        }
    }

    // MARK: - Properties

    private(set) public var activeRepository: Repository?
    private(set) public var recentRepositories: [Repository] = []
    private let maxRecentRepositories = 10
    private let githubCliPath: String
    private var workingDirectory: URL?

    // MARK: - Initialization

    public init(githubCliPath: String = "/usr/local/bin/gh") {
        self.githubCliPath = githubCliPath
    }

    // MARK: - Repository Operations

    public func checkGitHubCliAvailability() async -> Bool {
        do {
            let (output, _) = try await runCommand(["auth", "status"])
            return output.contains("Logged in")
        } catch {
            return false
        }
    }

    public func setActiveRepository(_ repository: Repository) {
        self.activeRepository = repository
        if let index = recentRepositories.firstIndex(where: { $0.fullName == repository.fullName }) {
            recentRepositories.remove(at: index)
        }
        recentRepositories.insert(repository, at: 0)
        if recentRepositories.count > maxRecentRepositories {
            recentRepositories = Array(recentRepositories.prefix(maxRecentRepositories))
        }
    }

    public func searchRepositories(query: String, limit: Int = 10) async throws -> [Repository] {
        var args = [
            "repo", "list",
            "--json", "owner,name,description,defaultBranchRef,isPrivate,hasIssuesEnabled,isFork",
            "--limit", "\(limit)"
        ]
        if !query.isEmpty { args.append(contentsOf: ["--search", query]) }

        let (output, _) = try await runCommand(args)
        guard let jsonData = output.data(using: .utf8),
              let jsonArray = try? JSONSerialization.jsonObject(with: jsonData) as? [[String: Any]] else {
            throw GitHubServiceError.parseError("Could not parse repository list JSON")
        }

        return jsonArray.compactMap { dict -> Repository? in
            guard let ownerDict = dict["owner"] as? [String: Any],
                  let owner = ownerDict["login"] as? String,
                  let name = dict["name"] as? String,
                  !owner.isEmpty, !name.isEmpty else { return nil }
            var repo = Repository(owner: owner, name: name)
            repo.description = dict["description"] as? String
            if let branchRef = dict["defaultBranchRef"] as? [String: Any],
               let branch = branchRef["name"] as? String, !branch.isEmpty {
                repo.defaultBranch = branch
            }
            repo.isPrivate = (dict["isPrivate"] as? Bool) ?? false
            repo.hasIssues = (dict["hasIssuesEnabled"] as? Bool) ?? true
            repo.isFork = (dict["isFork"] as? Bool) ?? false
            return repo
        }
    }

    public func cloneRepository(_ repository: Repository, options: CloneOptions = .default) async throws -> String {
        var args = ["repo", "clone", repository.fullName]
        if let directory = options.directory { args.append(directory) }
        if options.shallow { args.append(contentsOf: ["--depth", "1"]) }
        if !options.recurseSubmodules { args.append("--no-recurse-submodules") }

        let (output, _) = try await runCommand(args)

        let path: String
        if let directory = options.directory {
            path = directory
        } else if let pathMatch = output.range(of: "Cloned to (.+)", options: .regularExpression) {
            path = String(output[pathMatch])
                .replacingOccurrences(of: "Cloned to ", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            path = repository.name
        }

        if let branch = options.branch {
            workingDirectory = URL(fileURLWithPath: path)
            _ = try await runCommand(["checkout", branch], useGit: true)
            workingDirectory = nil
        }

        setActiveRepository(repository)
        return path
    }

    public func getRepositoryDetails(repoFullName: String) async throws -> Repository {
        let (owner, name) = parseRepositoryFullName(repoFullName)
        let args = ["repo", "view", repoFullName,
                    "--json", "owner,name,description,defaultBranchRef,isPrivate,hasIssuesEnabled,isFork"]
        let (output, _) = try await runCommand(args)

        guard let jsonData = output.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            throw GitHubServiceError.parseError("Could not parse repository details JSON")
        }

        var repo = Repository(owner: owner, name: name)
        repo.description = dict["description"] as? String
        if let branchRef = dict["defaultBranchRef"] as? [String: Any],
           let branch = branchRef["name"] as? String, !branch.isEmpty {
            repo.defaultBranch = branch
        }
        repo.isPrivate = (dict["isPrivate"] as? Bool) ?? false
        repo.hasIssues = (dict["hasIssuesEnabled"] as? Bool) ?? true
        repo.isFork = (dict["isFork"] as? Bool) ?? false
        return repo
    }

    // MARK: - Issue Operations

    public func listIssues(state: IssueState = .open, limit: Int = 30) async throws -> [Issue] {
        guard let repository = activeRepository else {
            throw GitHubServiceError.invalidRepository("No active repository")
        }
        return try await listIssues(repository: repository, state: state, limit: limit)
    }

    public func listIssues(repository: Repository, state: IssueState = .open, limit: Int = 30) async throws -> [Issue] {
        let args = [
            "issue", "list",
            "--repo", repository.fullName,
            "--state", state.rawValue,
            "--limit", "\(limit)",
            "--json", "number,title,body,state,author,assignees,labels,createdAt,updatedAt,closedAt"
        ]
        let (output, _) = try await runCommand(args)

        guard let jsonData = output.data(using: .utf8),
              let jsonArray = try? JSONSerialization.jsonObject(with: jsonData) as? [[String: Any]] else {
            throw GitHubServiceError.parseError("Could not parse issues JSON")
        }

        let formatter = ISO8601DateFormatter()
        return jsonArray.compactMap { dict -> Issue? in
            guard let number = dict["number"] as? Int,
                  let title = dict["title"] as? String else { return nil }

            let body = dict["body"] as? String
            let stateStr = (dict["state"] as? String ?? "").lowercased()
            let issueState: IssueState = stateStr == "closed" ? .closed : .open
            let creator = (dict["author"] as? [String: Any])?["login"] as? String ?? ""
            let assignees = (dict["assignees"] as? [[String: Any]] ?? []).compactMap { $0["login"] as? String }
            let labels = (dict["labels"] as? [[String: Any]] ?? []).compactMap { $0["name"] as? String }
            let createdAt = formatter.date(from: dict["createdAt"] as? String ?? "") ?? Date()
            let updatedAt = formatter.date(from: dict["updatedAt"] as? String ?? "") ?? Date()
            let closedAt = (dict["closedAt"] as? String).flatMap { formatter.date(from: $0) }

            return Issue(number: number, title: title, body: body, state: issueState,
                         creator: creator, assignees: assignees, labels: labels,
                         createdAt: createdAt, updatedAt: updatedAt,
                         closedAt: closedAt, repository: repository)
        }
    }

    // MARK: - Pull Request Operations

    public func listPullRequests(state: PRState = .open, limit: Int = 30) async throws -> [PullRequest] {
        guard let repository = activeRepository else {
            throw GitHubServiceError.invalidRepository("No active repository")
        }
        return try await listPullRequests(repository: repository, state: state, limit: limit)
    }

    public func listPullRequests(repository: Repository, state: PRState = .open, limit: Int = 30) async throws -> [PullRequest] {
        let stateArg: String
        switch state {
        case .open: stateArg = "open"
        case .closed: stateArg = "closed"
        case .merged: stateArg = "merged"
        }

        let args = [
            "pr", "list",
            "--repo", repository.fullName,
            "--state", stateArg,
            "--limit", "\(limit)",
            "--json", "number,title,body,state,author,assignees,labels,createdAt,updatedAt,closedAt,mergedAt,headRefName,baseRefName"
        ]
        let (output, _) = try await runCommand(args)

        guard let jsonData = output.data(using: .utf8),
              let jsonArray = try? JSONSerialization.jsonObject(with: jsonData) as? [[String: Any]] else {
            throw GitHubServiceError.parseError("Could not parse pull requests JSON")
        }

        let formatter = ISO8601DateFormatter()
        return jsonArray.compactMap { dict -> PullRequest? in
            guard let number = dict["number"] as? Int,
                  let title = dict["title"] as? String else { return nil }

            let body = dict["body"] as? String
            let stateStr = (dict["state"] as? String ?? "").lowercased()
            let prState: PRState = stateStr == "closed" ? .closed : (stateStr == "merged" ? .merged : .open)
            let creator = (dict["author"] as? [String: Any])?["login"] as? String ?? ""
            let assignees = (dict["assignees"] as? [[String: Any]] ?? []).compactMap { $0["login"] as? String }
            let labels = (dict["labels"] as? [[String: Any]] ?? []).compactMap { $0["name"] as? String }
            let createdAt = formatter.date(from: dict["createdAt"] as? String ?? "") ?? Date()
            let updatedAt = formatter.date(from: dict["updatedAt"] as? String ?? "") ?? Date()
            let closedAt = (dict["closedAt"] as? String).flatMap { formatter.date(from: $0) }
            let mergedAt = (dict["mergedAt"] as? String).flatMap { formatter.date(from: $0) }
            let sourceBranch = dict["headRefName"] as? String ?? ""
            let targetBranch = dict["baseRefName"] as? String ?? ""

            return PullRequest(number: number, title: title, body: body, state: prState,
                               creator: creator, assignees: assignees, labels: labels,
                               createdAt: createdAt, updatedAt: updatedAt,
                               closedAt: closedAt, mergedAt: mergedAt,
                               sourceBranch: sourceBranch, targetBranch: targetBranch,
                               repository: repository)
        }
    }

    // MARK: - Private Helpers

    @discardableResult
    private func runCommand(_ args: [String], useGit: Bool = false) async throws -> (String, Int) {
        let execPath = useGit ? "/usr/bin/git" : githubCliPath
        let capturedWorkDir = workingDirectory

        return try await Task<(String, Int), Error>.detached(priority: .userInitiated) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: execPath)
            process.arguments = args
            if let workDir = capturedWorkDir { process.currentDirectoryURL = workDir }

            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            do {
                try process.run()
            } catch {
                throw GitHubServiceError.commandFailed(args.joined(separator: " "), -1)
            }
            process.waitUntilExit()

            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: outputData, encoding: .utf8) ?? ""
            let exitCode = Int(process.terminationStatus)

            if exitCode != 0 {
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let errMsg = String(data: errorData, encoding: .utf8) ?? "unknown error"
                print("[GitHubService] Command failed (\(exitCode)): \(errMsg)")
                throw GitHubServiceError.commandFailed(args.joined(separator: " "), exitCode)
            }

            return (output, exitCode)
        }.value
    }

    private func parseRepositoryFullName(_ fullName: String) -> (String, String) {
        let parts = fullName.split(separator: "/", maxSplits: 1)
        return parts.count == 2 ? (String(parts[0]), String(parts[1])) : ("", fullName)
    }
}
