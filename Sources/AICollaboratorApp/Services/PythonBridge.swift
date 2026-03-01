#if canImport(SwiftUI)
import Foundation
import SwiftUI

class PythonBridge: ObservableObject {
    @Published var isInitialized = false
    @Published var isLoading = false
    @Published var statusMessage = "Not initialized"

    @Published var issues: [GithubIssue] = []
    @Published var pullRequests: [GithubPR] = []
    @Published var selectedIssueId: String? = nil
    @Published var selectedPRId: String? = nil

    @Published var currentAnalysis: String? = nil
    @Published var fixContent: String? = nil

    private let pythonScriptPath = NSString(string: "~/Desktop/ai_collaborator.py").expandingTildeInPath
    private let pythonPath = "/usr/bin/python3"

    var selectedItemIsPR: Bool {
        selectedPRId != nil
    }

    var selectedItem: Any? {
        if let id = selectedPRId {
            return pullRequests.first { $0.id == id }
        } else if let id = selectedIssueId {
            return issues.first { $0.id == id }
        }
        return nil
    }

    func initialize() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            self.updateStatus(loading: true, message: "Checking Python environment...")

            // Check if Python exists
            let pythonExists = FileManager.default.fileExists(atPath: self.pythonPath)
            guard pythonExists else {
                DispatchQueue.main.async {
                    self.updateStatus(loading: false, message: "Python not found at \(self.pythonPath)")
                }
                return
            }

            // Check if Ollama is running
            if !self.isOllamaRunning() {
                DispatchQueue.main.async {
                    self.updateStatus(loading: false, message: "Ollama is not running. Start Ollama and retry.")
                }
                return
            }

            DispatchQueue.main.async {
                self.isInitialized = true
                self.updateStatus(loading: false, message: "Ready")
            }
        }
    }

    func cleanup() {
        isInitialized = false
        updateStatus(loading: false, message: "Not initialized")
    }

    func fetchIssues() {
        guard isInitialized else {
            updateStatus(loading: false, message: "Not initialized")
            return
        }

        updateStatus(loading: true, message: "Fetching issues...")

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            do {
                let result = try self.runPythonCommand(arguments: ["issue", "list"])
                let issues = self.parseIssues(from: result)

                DispatchQueue.main.async {
                    self.issues = issues
                    self.updateStatus(loading: false, message: "Fetched \(issues.count) issues")
                }
            } catch {
                DispatchQueue.main.async {
                    self.updateStatus(loading: false, message: "Error fetching issues: \(error.localizedDescription)")
                }
            }
        }
    }

    func fetchPRs() {
        guard isInitialized else {
            updateStatus(loading: false, message: "Not initialized")
            return
        }

        updateStatus(loading: true, message: "Fetching pull requests...")

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            do {
                let result = try self.runPythonCommand(arguments: ["pr", "list"])
                let prs = self.parsePRs(from: result)

                DispatchQueue.main.async {
                    self.pullRequests = prs
                    self.updateStatus(loading: false, message: "Fetched \(prs.count) pull requests")
                }
            } catch {
                DispatchQueue.main.async {
                    self.updateStatus(loading: false, message: "Error fetching PRs: \(error.localizedDescription)")
                }
            }
        }
    }

    func analyzeSelected() {
        guard isInitialized else {
            updateStatus(loading: false, message: "Not initialized")
            return
        }

        if let prId = selectedPRId, let pr = pullRequests.first(where: { $0.id == prId }) {
            analyzePR(pr)
        } else if let issueId = selectedIssueId, let issue = issues.first(where: { $0.id == issueId }) {
            analyzeIssue(issue)
        } else {
            updateStatus(loading: false, message: "No item selected")
        }
    }

    func analyzePR(_ pr: GithubPR) {
        updateStatus(loading: true, message: "Analyzing PR #\(pr.number)...")

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            do {
                let result = try self.runPythonCommand(arguments: ["pr", String(pr.number)])
                DispatchQueue.main.async {
                    self.currentAnalysis = result
                    self.fixContent = nil
                    if let index = self.pullRequests.firstIndex(where: { $0.id == pr.id }) {
                        self.pullRequests[index].hasAnalysis = true
                    }
                    self.updateStatus(loading: false, message: "Analysis complete for PR #\(pr.number)")
                }
            } catch {
                DispatchQueue.main.async {
                    self.updateStatus(loading: false, message: "Error analyzing PR: \(error.localizedDescription)")
                }
            }
        }
    }

    func analyzeIssue(_ issue: GithubIssue) {
        updateStatus(loading: true, message: "Analyzing issue #\(issue.number)...")

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            do {
                let result = try self.runPythonCommand(arguments: ["issue", String(issue.number)])
                DispatchQueue.main.async {
                    self.currentAnalysis = result
                    self.fixContent = nil
                    if let index = self.issues.firstIndex(where: { $0.id == issue.id }) {
                        self.issues[index].hasAnalysis = true
                    }
                    self.updateStatus(loading: false, message: "Analysis complete for issue #\(issue.number)")
                }
            } catch {
                DispatchQueue.main.async {
                    self.updateStatus(loading: false, message: "Error analyzing issue: \(error.localizedDescription)")
                }
            }
        }
    }

    func generateIssueFix() {
        guard isInitialized, let issueId = selectedIssueId,
              let issue = issues.first(where: { $0.id == issueId }) else {
            updateStatus(loading: false, message: "No issue selected")
            return
        }

        updateStatus(loading: true, message: "Generating fix for issue #\(issue.number)...")

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            do {
                let result = try self.runPythonCommand(arguments: ["issue", "fix", String(issue.number)])
                DispatchQueue.main.async {
                    self.fixContent = result
                    self.updateStatus(loading: false, message: "Fix generated for issue #\(issue.number)")
                }
            } catch {
                DispatchQueue.main.async {
                    self.updateStatus(loading: false, message: "Error generating fix: \(error.localizedDescription)")
                }
            }
        }
    }

    func commitIssueFix(commitMessage: String, branchName: String) -> Bool {
        guard isInitialized, let issueId = selectedIssueId,
              let issue = issues.first(where: { $0.id == issueId }),
              let fixContent = fixContent else {
            updateStatus(loading: false, message: "No fix available to commit")
            return false
        }

        updateStatus(loading: true, message: "Committing fix for issue #\(issue.number)...")

        do {
            let tempDir = NSTemporaryDirectory()
            let fixFilePath = "\(tempDir)/issue_fix_\(issue.number).md"
            try fixContent.write(toFile: fixFilePath, atomically: true, encoding: .utf8)

            let result = try runPythonCommand(arguments: [
                "issue", "apply", String(issue.number),
                "--fix-file", fixFilePath,
                "--branch", branchName,
                "--message", commitMessage
            ])
            updateStatus(loading: false, message: "Fix committed: \(result)")
            return true
        } catch {
            updateStatus(loading: false, message: "Error committing fix: \(error.localizedDescription)")
            return false
        }
    }

    func createPR(title: String, body: String, baseBranch: String = "main") -> Bool {
        guard isInitialized else {
            updateStatus(loading: false, message: "Not initialized")
            return false
        }

        updateStatus(loading: true, message: "Creating PR...")

        do {
            let tempDir = NSTemporaryDirectory()
            let bodyFilePath = "\(tempDir)/pr_body.md"
            try body.write(toFile: bodyFilePath, atomically: true, encoding: .utf8)

            let result = try runPythonCommand(arguments: [
                "create-pr", "--title", title, "--body-file", bodyFilePath, "--base", baseBranch
            ])
            updateStatus(loading: false, message: "PR created: \(result)")
            return true
        } catch {
            updateStatus(loading: false, message: "Error creating PR: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Helper Methods

    private func updateStatus(loading: Bool, message: String) {
        DispatchQueue.main.async {
            self.isLoading = loading
            self.statusMessage = message
        }
    }

    private func runPythonCommand(arguments: [String]) throws -> String {
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: pythonPath)
        process.arguments = [pythonScriptPath] + arguments
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

        let output = String(data: outputData, encoding: .utf8) ?? ""
        let errorOutput = String(data: errorData, encoding: .utf8) ?? ""

        if process.terminationStatus != 0 {
            throw NSError(domain: "com.aicollab", code: Int(process.terminationStatus),
                          userInfo: [NSLocalizedDescriptionKey: errorOutput.isEmpty ? "Unknown error" : errorOutput])
        }

        return output
    }

    private func isOllamaRunning() -> Bool {
        let process = Process()
        let outputPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/curl")
        process.arguments = ["-s", "-o", "/dev/null", "-w", "%{http_code}", "http://localhost:11434/api/tags"]
        process.standardOutput = outputPipe

        do {
            try process.run()
            process.waitUntilExit()
            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: outputData, encoding: .utf8) ?? ""
            return output == "200"
        } catch {
            return false
        }
    }

    private func parseIssues(from jsonString: String) -> [GithubIssue] {
        guard let jsonData = jsonString.data(using: .utf8) else { return [] }
        do {
            return try JSONDecoder().decode([GithubIssue].self, from: jsonData)
        } catch {
            print("Error parsing issues JSON: \(error)")
            return []
        }
    }

    private func parsePRs(from jsonString: String) -> [GithubPR] {
        guard let jsonData = jsonString.data(using: .utf8) else { return [] }
        do {
            return try JSONDecoder().decode([GithubPR].self, from: jsonData)
        } catch {
            print("Error parsing PRs JSON: \(error)")
            return []
        }
    }

    // MARK: - Preview Helper

    static var preview: PythonBridge {
        let bridge = PythonBridge()
        bridge.isInitialized = true
        bridge.statusMessage = "Preview mode"

        bridge.issues = [
            GithubIssue(id: "1", number: 101, title: "Sample issue",
                        body: "Sample issue body", labels: ["bug"], updatedAt: "2025-04-09T15:32:00Z")
        ]

        bridge.pullRequests = [
            GithubPR(id: "101", number: 104, title: "Sample PR",
                     body: "Sample PR body", branchName: "feature/sample", updatedAt: "2025-04-08T14:22:00Z")
        ]

        return bridge
    }
}
#endif
