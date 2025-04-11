//
//  GitHubService.swift
//  AICollaborator
//
//  Created: 2025-04-10
//

import Foundation
import Alamofire
import SwiftyJSON

/// Service for interacting with GitHub repositories and the GitHub CLI
public actor GitHubService {
    // MARK: - Types
    
    /// Repository information
    public struct Repository: Identifiable, Equatable, Codable {
        /// Owner/organization name
        public let owner: String
        
        /// Repository name
        public let name: String
        
        /// Full repository path (owner/name)
        public var fullName: String {
            return "\(owner)/\(name)"
        }
        
        /// Repository URL (SSH format)
        public var sshUrl: String {
            return "git@github.com:\(fullName).git"
        }
        
        /// Repository URL (HTTPS format)
        public var httpsUrl: String {
            return "https://github.com/\(fullName).git"
        }
        
        /// Web URL
        public var webUrl: String {
            return "https://github.com/\(fullName)"
        }
        
        /// Clone URL (defaults to SSH per user preference)
        public var cloneUrl: String {
            return sshUrl
        }
        
        /// Default branch name
        public var defaultBranch: String = "main"
        
        /// Repository description
        public var description: String?
        
        /// Whether the repository is private
        public var isPrivate: Bool = false
        
        /// Whether issues are enabled
        public var hasIssues: Bool = true
        
        /// Whether the repository is a fork
        public var isFork: Bool = false
        
        /// Unique identifier for Identifiable conformance
        public var id: String {
            return fullName
        }
    }
    
    /// Issue information
    public struct Issue: Identifiable, Equatable, Codable {
        /// Issue number
        public let number: Int
        
        /// Issue title
        public let title: String
        
        /// Issue body/description
        public let body: String?
        
        /// Issue state (open, closed)
        public let state: IssueState
        
        /// Creator username
        public let creator: String
        
        /// Assignees
        public let assignees: [String]
        
        /// Labels
        public let labels: [String]
        
        /// Creation date
        public let createdAt: Date
        
        /// Update date
        public let updatedAt: Date
        
        /// Closed date (if applicable)
        public let closedAt: Date?
        
        /// Repository the issue belongs to
        public let repository: Repository
        
        /// Web URL
        public var webUrl: String {
            return "https://github.com/\(repository.fullName)/issues/\(number)"
        }
        
        /// Unique identifier for Identifiable conformance
        public var id: String {
            return "\(repository.fullName)#\(number)"
        }
    }
    
    /// Pull request information
    public struct PullRequest: Identifiable, Equatable, Codable {
        /// PR number
        public let number: Int
        
        /// PR title
        public let title: String
        
        /// PR body/description
        public let body: String?
        
        /// PR state
        public let state: PRState
        
        /// Creator username
        public let creator: String
        
        /// Assignees
        public let assignees: [String]
        
        /// Labels
        public let labels: [String]
        
        /// Creation date
        public let createdAt: Date
        
        /// Update date
        public let updatedAt: Date
        
        /// Closed date (if applicable)
        public let closedAt: Date?
        
        /// Merged date (if applicable)
        public let mergedAt: Date?
        
        /// Source branch
        public let sourceBranch: String
        
        /// Target branch
        public let targetBranch: String
        
        /// Repository the PR belongs to
        public let repository: Repository
        
        /// Web URL
        public var webUrl: String {
            return "https://github.com/\(repository.fullName)/pull/\(number)"
        }
        
        /// Whether the PR is merged
        public var isMerged: Bool {
            return mergedAt != nil
        }
        
        /// Unique identifier for Identifiable conformance
        public var id: String {
            return "\(repository.fullName)#\(number)"
        }
    }
    
    /// Repository clone options
    public struct CloneOptions {
        /// Clone directory (if nil, uses repo name in current directory)
        public var directory: String?
        
        /// Branch to checkout after cloning
        public var branch: String?
        
        /// Whether to use shallow clone (--depth 1)
        public var shallow: Bool = false
        
        /// Whether to recurse submodules
        public var recurseSubmodules: Bool = true
        
        /// Default options
        public static let `default` = CloneOptions()
        
        /// Initialize with custom options
        public init(directory: String? = nil, branch: String? = nil, shallow: Bool = false, recurseSubmodules: Bool = true) {
            self.directory = directory
            self.branch = branch
            self.shallow = shallow
            self.recurseSubmodules = recurseSubmodules
        }
    }
    
    /// Issue state
    public enum IssueState: String, Codable {
        case open
        case closed
    }
    
    /// Pull request state
    public enum PRState: String, Codable {
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
    
    /// Currently active repository
    private(set) public var activeRepository: Repository?
    
    /// Recently used repositories
    private(set) public var recentRepositories: [Repository] = []
    
    /// Maximum number of recent repositories to track
    private let maxRecentRepositories = 10
    
    /// Path to GitHub CLI executable
    private let githubCliPath: String
    
    /// Logger
    private let logger = Logger()
    
    /// Working directory for repository operations
    private var workingDirectory: URL?
    
    // MARK: - Initialization
    
    /// Initialize GitHubService
    /// - Parameter githubCliPath: Path to GitHub CLI executable
    public init(githubCliPath: String = "/usr/local/bin/gh") {
        self.githubCliPath = githubCliPath
    }
    
    // MARK: - Repository Operations
    
    /// Check if GitHub CLI is available
    /// - Returns: True if GitHub CLI is available and authenticated
    public func checkGitHubCliAvailability() async -> Bool {
        do {
            let (output, _) = try await runCommand(["auth", "status", "--show-token"])
            return output.contains("Logged in")
        } catch {
            logger.error("GitHub CLI not available: \(error.localizedDescription)")
            return false
        }
    }
    
    /// Set the active repository for operations
    /// - Parameter repository: Repository to set as active
    public func setActiveRepository(_ repository: Repository) {
        self.activeRepository = repository
        
        // Add to recent repositories
        if let index = recentRepositories.firstIndex(where: { $0.fullName == repository.fullName }) {
            recentRepositories.remove(at: index)
        }
        recentRepositories.insert(repository, at: 0)
        
        // Trim to maximum size
        if recentRepositories.count > maxRecentRepositories {
            recentRepositories = Array(recentRepositories.prefix(maxRecentRepositories))
        }
        
        logger.info("Active repository set to: \(repository.fullName)")
    }
    
    /// Search for repositories matching a query
    /// - Parameters:
    ///   - query: Search query
    ///   - limit: Maximum number of results
    /// - Returns: Array of matching repositories
    public func searchRepositories(query: String, limit: Int = 10) async throws -> [Repository] {
        var args = [
            "repo", "list",
            "--json", "owner,name,description,defaultBranchRef,isPrivate,hasIssuesEnabled,isFork",
            "--limit", "\(limit)"
        ]
        
        if !query.isEmpty {
            args.append(contentsOf: ["--search", query])
        }
        
        let (output, _) = try await runCommand(args)
        
        do {
            let json = try JSON(data: output.data(using: .utf8)!)
            
            var repositories: [Repository] = []
            
            for (_, repoJson) in json {
                let owner = repoJson["owner"]["login"].stringValue
                let name = repoJson["name"].stringValue
                let description = repoJson["description"].string
                let defaultBranch = repoJson["defaultBranchRef"]["name"].stringValue
                let isPrivate = repoJson["isPrivate"].boolValue
                let hasIssues = repoJson["hasIssuesEnabled"].boolValue
                let isFork = repoJson["isFork"].boolValue
                
                var repo = Repository(owner: owner, name: name)
                repo.description = description
                repo.defaultBranch = defaultBranch.isEmpty ? "main" : defaultBranch
                repo.isPrivate = isPrivate
                repo.hasIssues = hasIssues
                repo.isFork = isFork
                
                repositories.append(repo)
            }
            
            return repositories
        } catch {
            throw GitHubServiceError.parseError("Failed to parse repository list: \(error.localizedDescription)")
        }
    }
    
    /// Clone a repository
    /// - Parameters:
    ///   - repository: Repository to clone
    ///   - options: Clone options
    /// - Returns: Path to cloned repository
    public func cloneRepository(_ repository: Repository, options: CloneOptions = .default) async throws -> String {
        var args = ["repo", "clone", repository.fullName]
        
        if let directory = options.directory {
            args.append(directory)
        }
        
        if options.shallow {
            args.append("--depth")
            args.append("1")
        }
        
        if !options.recurseSubmodules {
            args.append("--no-recurse-submodules")
        }
        
        let (output, _) = try await runCommand(args)
        
        // Extract the cloned directory path from output
        let path: String
        if let directory = options.directory {
            path = directory
        } else {
            // Try to extract from output, otherwise use repository name
            if let pathMatch = output.range(of: "Cloned to (.+)", options: .regularExpression) {
                path = String(output[pathMatch])
                    .replacingOccurrences(of: "Cloned to ", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                path = repository.name
            }
        }
        
        // Checkout specific branch if requested
        if let branch = options.branch {
            // Change to the repository directory
            workingDirectory = URL(fileURLWithPath: path)
            try await runCommand(["git", "checkout", branch], useGit: true)
            workingDirectory = nil
        }
        
        // Add to recent repositories
        setActiveRepository(repository)
        
        return path
    }
    
    /// Get repository details
    /// - Parameter repoFullName: Full repository name (owner/name)
    /// - Returns: Repository details
    public func getRepositoryDetails(repoFullName: String) async throws -> Repository {
        let (owner, name) = parseRepositoryFullName(repoFullName)
        
        let args = [
            "repo", "view", repoFullName,
            "--json", "owner,name,description,defaultBranchRef,isPrivate,hasIssuesEnabled,isFork"
        ]
        
        let (output, _) = try await runCommand(args)
        
        do {
            let json = try JSON(data: output.data(using: .utf8)!)
            
            let description = json["description"].string
            let defaultBranch = json["defaultBranchRef"]["name"].stringValue
            let isPrivate = json["isPrivate"].boolValue
            let hasIssues = json["hasIssuesEnabled"].boolValue
            let isFork = json["isFork"].boolValue
            
            var repo = Repository(owner: owner, name: name)
            repo.description = description
            repo.defaultBranch = defaultBranch.isEmpty ? "main" : defaultBranch
            repo.isPrivate = isPrivate
            repo.hasIssues = hasIssues
            repo.isFork = isFork
            
            return repo
        } catch {
            throw GitHubServiceError.parseError("Failed to parse repository details: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Issue Operations
    
    /// List issues for the active repository
    /// - Parameters:
    ///   - state: Issue state filter (open, closed, all)
    ///   - limit: Maximum number of issues to return
    /// - Returns: Array of issues
    public func listIssues(state: IssueState = .open, limit: Int = 30) async throws -> [Issue] {
        guard let repository = activeRepository else {
            throw GitHubServiceError.invalidRepository("No active repository")
        }
        
        return try await listIssues(repository: repository, state: state, limit: limit)
    }
    
    /// List issues for a specific repository
    /// - Parameters:
    ///   - repository: Repository to list issues for
    ///   - state: Issue state filter (open, closed, all)
    ///   - limit: Maximum number of issues to return
    /// - Returns: Array of issues
    public func listIssues(repository: Repository, state: IssueState = .open, limit: Int = 30) async throws -> [Issue] {
        let args = [
            "issue", "list",
            "--repo", repository.fullName,
            "--state", state.rawValue,
            "--limit", "\(limit)",
            "--json", "number,title,body,state,author,assignees,labels,createdAt,updatedAt,closedAt"
        ]
        
        let (output, _) = try await runCommand(args

