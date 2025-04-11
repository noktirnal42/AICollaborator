//
//  GitHubAgent.swift
//  AICollaborator
//
//  Created: 2025-04-10
//

import Foundation
import SwiftyJSON

/// Specialized agent for GitHub interactions
public actor GitHubAgent: BaseAIAgent {
    // MARK: - Types
    
    /// Types of GitHub analysis tasks
    public enum AnalysisType {
        case repository
        case pullRequest
        case issue
        case codeReview
        case documentation
        case contributionGuidelines
        case trends
        case custom(String)
        
        /// Get required capabilities for this analysis type
        var requiredCapabilities: [AICapability] {
            switch self {
            case .codeReview:
                return [.codeGeneration, .textAnalysis]
            case .documentation:
                return [.textAnalysis, .dataSummarization]
            case .repository, .pullRequest, .issue, .contributionGuidelines, .trends, .custom:
                return [.textAnalysis]
            }
        }
    }
    
    /// GitHub operation results
    public struct OperationResult {
        /// Success indicator
        public let success: Bool
        
        /// Result message
        public let message: String
        
        /// Additional data if applicable
        public let data: Any?
        
        /// URL to view results (if applicable)
        public let url: URL?
        
        /// Static success result
        public static func success(_ message: String, data: Any? = nil, url: URL? = nil) -> OperationResult {
            return OperationResult(success: true, message: message, data: data, url: url)
        }
        
        /// Static failure result
        public static func failure(_ message: String) -> OperationResult {
            return OperationResult(success: false, message: message, data: nil, url: nil)
        }
    }
    
    // MARK: - Properties
    
    /// GitHub service for API interactions
    private let githubService: GitHubService
    
    /// Currently active repository
    private var activeRepository: GitHubService.Repository?
    
    /// AI service for enhanced analysis
    private var ollamaAgent: OllamaAgent?
    
    /// Repository analysis cache
    private var repositoryAnalysisCache: [String: (analysis: String, timestamp: Date)] = [:]
    
    /// Maximum cache items
    private let maxCacheSize = 20
    
    /// Cache expiration time (1 hour)
    private let cacheExpirationSeconds: TimeInterval = 3600
    
    // MARK: - Initialization
    
    /// Initialize a GitHub agent
    /// - Parameters:
    ///   - githubService: GitHub service instance
    ///   - ollamaAgent: Optional Ollama agent for AI-powered analysis
    ///   - initialRepository: Initial repository to work with
    public init(
        githubService: GitHubService,
        ollamaAgent: OllamaAgent? = nil,
        initialRepository: GitHubService.Repository? = nil
    ) {
        self.githubService = githubService
        self.ollamaAgent = ollamaAgent
        self.activeRepository = initialRepository
        
        // Define GitHub-specific capabilities
        let capabilities: [AICapability] = [
            .textAnalysis,
            .dataSummarization,
            .contextRetrieval
        ]
        
        super.init(
            name: "GitHubAgent",
            version: "1.0",
            description: "Specialized agent for GitHub repository management and analysis",
            capabilities: capabilities
        )
    }
    
    // MARK: - Repository Management
    
    /// Search for GitHub repositories
    /// - Parameters:
    ///   - query: Search query
    ///   - limit: Maximum results to return
    /// - Returns: Matching repositories
    public func searchRepositories(query: String, limit: Int = 10) async throws -> [GitHubService.Repository] {
        return try await githubService.searchRepositories(query: query, limit: limit)
    }
    
    /// Set the active repository
    /// - Parameter repository: Repository to set as active
    public func setActiveRepository(_ repository: GitHubService.Repository) async {
        self.activeRepository = repository
        await githubService.setActiveRepository(repository)
    }
    
    /// Clone the active repository
    /// - Parameter options: Clone options
    /// - Returns: Path to cloned repository
    public func cloneActiveRepository(options: GitHubService.CloneOptions = .default) async throws -> String {
        guard let repository = activeRepository else {
            throw GitHubAgentError.noActiveRepository
        }
        
        return try await githubService.cloneRepository(repository, options: options)
    }
    
    /// Get repository details
    /// - Parameter fullName: Repository full name (owner/name)
    /// - Returns: Repository details
    public func getRepositoryDetails(fullName: String) async throws -> GitHubService.Repository {
        let repo = try await githubService.getRepositoryDetails(repoFullName: fullName)
        
        // Update active repository
        self.activeRepository = repo
        await githubService.setActiveRepository(repo)
        
        return repo
    }
    
    // MARK: - Issue Management
    
    /// List issues in the active repository
    /// - Parameters:
    ///   - state: Issue state filter
    ///   - limit: Maximum issues to return
    /// - Returns: Array of issues
    public func listIssues(state: GitHubService.IssueState = .open, limit: Int = 30) async throws -> [GitHubService.Issue] {
        guard let repository = activeRepository else {
            throw GitHubAgentError.noActiveRepository
        }
        
        return try await githubService.listIssues(repository: repository, state: state, limit: limit)
    }
    
    /// Create a new issue
    /// - Parameters:
    ///   - title: Issue title
    ///   - body: Issue description
    ///   - labels: Labels to apply
    /// - Returns: Operation result
    public func createIssue(title: String, body: String, labels: [String] = []) async throws -> OperationResult {
        guard let repository = activeRepository else {
            throw GitHubAgentError.noActiveRepository
        }
        
        do {
            let command = ["issue", "create", 
                          "--repo", repository.fullName,
                          "--title", title,
                          "--body", body]
            
            // Add labels if provided
            let finalCommand = labels.isEmpty ? command : command + ["--label", labels.joined(separator: ",")]
            
            let (output, exitCode) = try await githubService.runCommand(finalCommand)
            
            if exitCode == 0 {
                // Extract issue URL from output
                // Example output: "https://github.com/owner/repo/issues/123"
                if let url = extractURL(from: output) {
                    return OperationResult.success("Issue created successfully", url: url)
                } else {
                    return OperationResult.success("Issue created successfully")
                }
            } else {
                return OperationResult.failure("Failed to create issue: \(output)")
            }
        } catch {
            return OperationResult.failure("Error creating issue: \(error.localizedDescription)")
        }
    }
    
    /// Get issue details
    /// - Parameter issueNumber: Issue number
    /// - Returns: Issue details and operation result
    public func getIssueDetails(issueNumber: Int) async throws -> (issue: GitHubService.Issue?, result: OperationResult) {
        guard let repository = activeRepository else {
            throw GitHubAgentError.noActiveRepository
        }
        
        do {
            let command = ["issue", "view", 
                          String(issueNumber),
                          "--repo", repository.fullName,
                          "--json", "number,title,body,state,author,assignees,labels,createdAt,updatedAt,closedAt"]
            
            let (output, exitCode) = try await githubService.runCommand(command)
            
            if exitCode == 0 {
                do {
                    // Parse JSON output into Issue struct
                    let json = try JSON(data: output.data(using: .utf8)!)
                    
                    // Build issue from JSON (simplified example)
                    // In a real implementation, this would parse all fields properly
                    let issue = GitHubService.Issue(
                        number: json["number"].intValue,
                        title: json["title"].stringValue,
                        body: json["body"].string,
                        state: GitHubService.IssueState(rawValue: json["state"].stringValue) ?? .open,
                        creator: json["author"]["login"].stringValue,
                        assignees: json["assignees"].arrayValue.map { $0["login"].stringValue },
                        labels: json["labels"].arrayValue.map { $0["name"].stringValue },
                        createdAt: ISO8601DateFormatter().date(from: json["createdAt"].stringValue) ?? Date(),
                        updatedAt: ISO8601DateFormatter().date(from: json["updatedAt"].stringValue) ?? Date(),
                        closedAt: ISO8601DateFormatter().date(from: json["closedAt"].stringValue),
                        repository: repository
                    )
                    
                    return (issue, OperationResult.success("Retrieved issue details successfully"))
                } catch {
                    return (nil, OperationResult.failure("Failed to parse issue details: \(error.localizedDescription)"))
                }
            } else {
                return (nil, OperationResult.failure("Failed to retrieve issue: \(output)"))
            }
        } catch {
            return (nil, OperationResult.failure("Error retrieving issue: \(error.localizedDescription)"))
        }
    }
    
    // MARK: - Pull Request Management
    
    /// Create a pull request
    /// - Parameters:
    ///   - title: PR title
    ///   - body: PR description
    ///   - head: Head branch
    ///   - base: Base branch
    /// - Returns: Operation result
    public func createPullRequest(title: String, body: String, head: String, base: String) async throws -> OperationResult {
        guard let repository = activeRepository else {
            throw GitHubAgentError.noActiveRepository
        }
        
        do {
            let command = ["pr", "create", 
                          "--repo", repository.fullName,
                          "--title", title,
                          "--body", body,
                          "--head", head,
                          "--base", base]
            
            let (output, exitCode) = try await githubService.runCommand(command)
            
            if exitCode == 0 {
                // Extract PR URL from output
                if let url = extractURL(from: output) {
                    return OperationResult.success("Pull request created successfully", url: url)
                } else {
                    return OperationResult.success("Pull request created successfully")
                }
            } else {
                return OperationResult.failure("Failed to create pull request: \(output)")
            }
        } catch {
            return OperationResult.failure("Error creating pull request: \(error.localizedDescription)")
        }
    }
    
    /// Review a pull request
    /// - Parameters:
    ///   - prNumber: PR number
    ///   - comment: Review comment
    ///   - action: Review action (approve, comment, request-changes)
    /// - Returns: Operation result
    public func reviewPullRequest(prNumber: Int, comment: String, action: String = "comment") async throws -> OperationResult {
        guard let repository = activeRepository else {
            throw GitHubAgentError.noActiveRepository
        }
        
        do {
            let command = ["pr", "review", 
                          String(prNumber),
                          "--repo", repository.fullName,
                          "--body", comment,
                          "--\(action)"]
            
            let (output, exitCode) = try await githubService.runCommand(command)
            
            if exitCode == 0 {
                return OperationResult.success("Pull request reviewed successfully")
            } else {
                return OperationResult.failure("Failed to review pull request: \(output)")
            }
        } catch {
            return OperationResult.failure("Error reviewing pull request: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Analysis Capabilities
    
    /// Analyze repository with AI-powered insights
    /// - Parameter analysisType: Type of analysis to perform
    /// - Returns: Analysis result
    public func analyzeRepository(analysisType: AnalysisType = .repository) async throws -> String {
        guard let repository = activeRepository else {
            throw GitHubAgentError.noActiveRepository
        }
        
        // Check cache for recent analysis
        let cacheKey = "\(repository.fullName)|\(String(describing: analysisType))"
        if let cached = repositoryAnalysisCache[cacheKey], 
           Date().timeIntervalSince(cached.timestamp) < cacheExpirationSeconds {
            // Return cached analysis
            return cached.analysis
        }
        
        // Generate base analysis from repository data
        var baseAnalysis = ""
        
        switch analysisType {
        case .repository:
            baseAnalysis = await generateRepositoryOverview(repository)
        case .pullRequest:
            baseAnalysis = await generatePullRequestsAnalysis(repository)
        case .issue:
            baseAnalysis = await generateIssuesAnalysis(repository)
        case .codeReview:
            baseAnalysis = await generateCodeReviewAnalysis(repository)
        case .documentation:
            baseAnalysis = await generateDocumentationAnalysis(repository)
        case .contributionGuidelines:
            baseAnalysis = await generateContributionGuidelinesAnalysis(repository)
        case .trends:
            baseAnalysis = await generateRepositoryTrendsAnalysis(repository)
        case .custom(let customType):
            baseAnalysis = await generateCustomAnalysis(repository, type: customType)
        }
        
        // Enhance with AI if available
        var enhancedAnalysis = baseAnalysis
        if let ollamaAgent = ollamaAgent {
            // Prepare task
            let task = AITask(
                description: "Enhance GitHub repository analysis",
                query: "Based on the following raw GitHub repository analysis, provide enhanced insights, suggestions, and patterns:\n\n\(baseAnalysis)",
                context: ["repositoryName": repository.fullName],
                requiredCapabilities: [.textAnalysis, .dataSummarization],
                priority: .normal
            )
            
            do {
                // Process through AI
                let result = try await ollamaAgent.processTask(task)
                
                // Use AI-enhanced analysis if successful
                if result.status == .completed, let output = result.output as? String {
                    enhancedAnalysis = output
                }
            } catch {
                // If AI processing fails, fall back to base analysis
                logger.warning("AI enhancement failed: \(error.localizedDescription). Using base analysis.")
            }
        }
        
        // Cache the result
        repositoryAnalysisCache[cacheKey] = (analysis: enhancedAnalysis, timestamp: Date())
        
        // Prune cache if needed
        if repositoryAnalysisCache.count > maxCacheSize {
            // Remove oldest entries
            let sortedKeys = repositoryAnalysisCache.keys.sorted { lhs, rhs in
                return repositoryAnalysisCache[lhs]!.timestamp < repositoryAnalysisCache[rhs]!.timestamp
            }
            
            // Remove oldest entries
            let keysToRemove = sortedKeys.prefix(repositoryAnalysisCache.count - maxCacheSize)
            for key in keysToRemove {
                repositoryAnalysisCache.removeValue(forKey: key)
            }
        }
        
        return enhancedAnalysis
    }
    
    // MARK: - Analysis Generators
    
    /// Generate a repository overview analysis
    /// - Parameter repository: Repository to analyze
    /// - Returns: Analysis text
    private func generateRepositoryOverview(_ repository: GitHubService.Repository) async -> String {
        var overview = "# Repository Overview: \(repository.fullName)\n\n"
        
        do {
            // Get basic repository info
            let command = ["repo", "view", repository.fullName, "--json", "description,homepageUrl,createdAt,updatedAt,pushedAt,isArchived,stargazerCount,forkCount,watcherCount,issuesCount,openIssuesCount,topics,languages,licenseInfo"]
            
            let (output, exitCode) = try await githubService.runCommand(command)
            
            if exitCode == 0, let data = output.data(using: .utf8) {
                let json = try JSON(data: data)
                
                // Add repository description
                overview += "## Description\n\n"
                let description = json["description"].stringValue
                overview += description.isEmpty ? "No description provided.\n\n" : "\(description)\n\n"
                
                // Add repository stats
                overview += "## Repository Statistics\n\n"
                overview += "- **Stars:** \(json["stargazerCount"].intValue)\n"
                overview += "- **Forks:** \(json["forkCount"].intValue)\n"
                overview += "- **Watchers:** \(json["watcherCount"].intValue)\n"
                overview += "- **Total Issues:** \(json["issuesCount"].intValue)\n"
                overview += "- **Open Issues:** \(json["openIssuesCount"].intValue)\n"
                
                // Creation and update dates
                let createdAt = formatDate(json["createdAt"].stringValue)
                let updatedAt = formatDate(json["updatedAt"].stringValue)
                let pushedAt = formatDate(json["pushedAt"].stringValue)
                
                overview += "- **Created:** \(createdAt)\n"
                overview += "- **Last Updated:** \(updatedAt)\n"
                overview += "- **Last Push:** \(pushedAt)\n"
                
                // Add repository status
                if json["isArchived"].boolValue {
                    overview += "- **Status:** Archived ⚠️\n\n"
                } else {
                    overview += "- **Status:** Active ✅\n\n"
                }
                
                // Add topics
                overview += "## Topics\n\n"
                let topics = json["topics"].arrayValue.map { $0.stringValue }
                if topics.isEmpty {
                    overview += "No topics defined.\n\n"
                } else {
                    for topic in topics {
                        overview += "- \(topic)\n"
                    }
                    overview += "\n"
                }
                
                // Add languages
                overview += "## Languages\n\n"
                let languages = json["languages"].dictionaryValue
                if languages.isEmpty {
                    overview += "No language information available.\n\n"
                } else {
                    let sortedLanguages = languages.sorted { $0.value.intValue > $1.value.intValue }
                    for (language, bytes) in sortedLanguages {
                        overview += "- **\(language):** \(formatBytes(bytes.intValue))\n"
                    }
                    overview += "\n"
                }
                
                // Add license information
                overview += "## License\n\n"
                if let license = json["licenseInfo"]["name"].string {
                    overview += "Licensed under \(license)\n\n"
                } else {
                    overview += "No license information available.\n\n"
                }
                
                // Add repository URLs
                overview += "## Links\n\n"
                overview += "- **Repository:** \(repository.webUrl)\n"
                if let homepage = json["homepageUrl"].string, !homepage.isEmpty {
                    overview += "- **Homepage:** \(homepage)\n"
                }
                overview += "- **Clone URL (SSH):** \(repository.sshUrl)\n"
                overview += "- **Clone URL (HTTPS):** \(repository.httpsUrl)\n\n"
                
            } else {
                overview += "Unable to fetch detailed repository information.\n\n"
            }
            
            // Add default branch information
            overview += "## Default Branch\n\n"
            overview += "The default branch is `\(repository.defaultBranch)`.\n\n"
            
        } catch {
            overview += "Error retrieving repository information: \(error.localizedDescription)\n\n"
        }
        
        return overview
    }
    
    /// Generate a pull requests analysis
    /// - Parameter repository: Repository to analyze
    /// - Returns: Analysis text
    private func generatePullRequestsAnalysis(_ repository: GitHubService.Repository) async -> String {
        var analysis = "# Pull Request Analysis: \(repository.fullName)\n\n"
        
        do {
            // Get open pull requests
            let openCommand = ["pr", "list", "--repo", repository.fullName, "--state", "open", "--json", "number,title,createdAt,author,additions,deletions,changedFiles"]
            
            let (openOutput, openExitCode) = try await githubService.runCommand(openCommand)
            
            if openExitCode == 0, let openData = openOutput.data(using: .utf8) {
                let openPRs = try JSON(data: openData)
                
                analysis += "## Open Pull Requests\n\n"
                
                if openPRs.arrayValue.isEmpty {
                    analysis += "No open pull requests found.\n\n"
                } else {
                    analysis += "Found \(openPRs.arrayValue.count) open pull requests.\n\n"
                    
                    for pr in openPRs.arrayValue {
                        let number = pr["number"].intValue
                        let title = pr["title"].stringValue
                        let author = pr["author"]["login"].stringValue
                        let createdAt = formatDate(pr["createdAt"].stringValue)
                        let additions = pr["additions"].intValue
                        let deletions = pr["deletions"].intValue
                        let changedFiles = pr["changedFiles"].intValue
                        
                        analysis += "### PR #\(number): \(title)\n\n"
                        analysis += "- **Author:** \(author)\n"
                        analysis += "- **Created:** \(createdAt)\n"
                        analysis += "- **Changes:** +\(additions) / -\(deletions) in \(changedFiles) files\n"
                        analysis += "- **URL:** \(repository.webUrl)/pull/\(number)\n\n"
                    }
                }
                
                // Get recently closed PRs
                let closedCommand = ["pr", "list", "--repo", repository.fullName, "--state", "closed", "--limit", "5", "--json", "number,title,closedAt,author,merged"]
                
                let (closedOutput, closedExitCode) = try await githubService.runCommand(closedCommand)
                
                if closedExitCode == 0, let closedData = closedOutput.data(using: .utf8) {
                    let closedPRs = try JSON(data: closedData)
                    
                    analysis += "## Recently Closed Pull Requests\n\n"
                    
                    if closedPRs.arrayValue.isEmpty {
                        analysis += "No recently closed pull requests found.\n\n"
                    } else {
                        for pr in closedPRs.arrayValue {
                            let number = pr["number"].intValue
                            let title = pr["title"].stringValue
                            let author = pr["author"]["login"].stringValue
                            let closedAt = formatDate(pr["closedAt"].stringValue)
                            let merged = pr["merged"].boolValue
                            
                            analysis += "### PR #\(number): \(title)\n\n"
                            analysis += "- **Author:** \(author)\n"
                            analysis += "- **Closed:** \(closedAt)\n"
                            analysis += "- **Status:** \(merged ? "Merged ✅" : "Closed without merging ❌")\n"
                            analysis += "- **URL:** \(repository.webUrl)/pull/\(number)\n\n"
                        }
                    }
                }
            } else {
                analysis += "Unable to fetch pull request information.\n\n"
            }
        } catch {
            analysis += "Error retrieving pull request information: \(error.localizedDescription)\n\n"
        }
        
        return analysis
    }
    
    /// Generate an issues analysis
    /// - Parameter repository: Repository to analyze
    /// - Returns: Analysis text
    private func generateIssuesAnalysis(_ repository: GitHubService.Repository) async -> String {
        var analysis = "# Issues Analysis: \(repository.fullName)\n\n"
        
        do {
            // Get open issues
            let openCommand = ["issue", "list", "--repo", repository.fullName, "--state", "open", "--json", "number,title,createdAt,author,labels,assignees,comments"]
            
            let (openOutput, openExitCode) = try await githubService.runCommand(openCommand)
            
            if openExitCode == 0, let openData = openOutput.data(using: .utf8) {
                let openIssues = try JSON(data: openData)
                
                analysis += "## Open Issues\n\n"
                
                if openIssues.arrayValue.isEmpty {
                    analysis += "No open issues found.\n\n"
                } else {
                    analysis += "Found \(openIssues.arrayValue.count) open issues.\n\n"
                    
                    // Group issues by labels
                    var issuesByLabel: [String: [JSON]] = [:]
                    
                    for issue in openIssues.arrayValue {
                        let labels = issue["labels"].arrayValue.map { $0["name"].stringValue }
                        
                        if labels.isEmpty {
                            let unlabeled = issuesByLabel["unlabeled"] ?? []
                            issuesByLabel["unlabeled"] = unlabeled + [issue]
                        } else {
                            for label in labels {
                                var labelIssues = issuesByLabel[label] ?? []
                                labelIssues.append(issue)
                                issuesByLabel[label] = labelIssues
                            }
                        }
                    }
                    
                    // Display issues by label
                    for (label, issues) in issuesByLabel.sorted(by: { $0.key < $1.key }) {
                        analysis += "### \(label) (\(issues.count))\n\n"
                        
                        for issue in issues {
                            let number = issue["number"].intValue
                            let title = issue["title"].stringValue
                            let author = issue["author"]["login"].stringValue
                            let createdAt = formatDate(issue["createdAt"].stringValue)
                            let comments = issue["comments"].intValue
                            
                            analysis += "- **#\(number):** \(title)\n"
                            analysis += "  - **Author:** \(author)\n"
                            analysis += "  - **Created:** \(createdAt)\n"
                            analysis += "  - **Comments:** \(comments)\n"
                            analysis += "  - **URL:** \(repository.webUrl)/issues/\(number)\n\n"
                        }
                    }
                    
                    // Issue age statistics
                    let now = Date()
                    let ageGroups = [7, 30, 90, 365]
                    var ageCounts = [Int: Int]()
                    
                    for issue in openIssues.arrayValue {
                        if let createdDate = ISO8601DateFormatter().date(from: issue["createdAt"].stringValue) {
                            let daysSinceCreation = Int(now.timeIntervalSince(createdDate) / 86400)
                            
                            var placed = false
                            for group in ageGroups {
                                if daysSinceCreation <= group && !placed {
                                    ageCounts[group] = (ageCounts[group] ?? 0) + 1
                                    placed = true
                                }
                            }
                            
                            if !placed {
                                ageCounts[999] = (ageCounts[999] ?? 0) + 1
                            }
                        }
                    }
                    
                    analysis += "### Issue Age Analysis\n\n"
                    analysis += "- **Less than 7 days old:** \(ageCounts[7] ?? 0)\n"
                    analysis += "- **7-30 days old:** \(ageCounts[30] ?? 0)\n"
                    analysis += "- **30-90 days old:** \(ageCounts[90] ?? 0)\n"
                    analysis += "- **90-365 days old:** \(ageCounts[365] ?? 0)\n"
                    analysis += "- **More than 365 days old:** \(ageCounts[999] ?? 0)\n\n"
                }
