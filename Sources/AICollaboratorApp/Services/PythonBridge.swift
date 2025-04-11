import Foundation
import PythonSwiftCore
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
    private var pythonInstance: PythonInstance?
    
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
            
            self.updateStatus(loading: true, message: "Initializing Python...")
            
            do {
                // Initialize Python
                self.pythonInstance = try PythonInstance(pythonPath: self.pythonPath)
                
                // Check if Python script exists
                let fileManager = FileManager.default
                if !fileManager.fileExists(atPath: self.pythonScriptPath) {
                    throw NSError(domain: "com.aicollab", code: 1, 
                                  userInfo: [NSLocalizedDescriptionKey: "AI Collaborator script not found at \(self.pythonScriptPath)"])
                }
                
                // Check Ollama is running
                if !self.isOllamaRunning() {
                    throw NSError(domain: "com.aicollab", code: 2,
                                  userInfo: [NSLocalizedDescriptionKey: "Ollama is not running. Please start Ollama first."])
                }
                
                DispatchQueue.main.async {
                    self.isInitialized = true
                    self.updateStatus(loading: false, message: "Ready")
                }
            } catch {
                DispatchQueue.main.async {
                    self.updateStatus(loading: false, message: "Initialization failed: \(error.localizedDescription)")
                    print("Initialization error: \(error)")
                }
            }
        }
    }
    
    func cleanup() {
        // Cleanup Python instance
        pythonInstance = nil
        isInitialized = false
        updateStatus(loading: false, message: "Not initialized")
    }
    
    func fetchIssues() {
        guard isInitialized else {
            updateStatus(loading: false, message: "Python not initialized")
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
                    print("Error fetching issues: \(error)")
                }
            }
        }
    }
    
    func fetchPRs() {
        guard isInitialized else {
            updateStatus(loading: false, message: "Python not initialized")
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
                    print("Error fetching PRs: \(error)")
                }
            }
        }
    }
    
    func analyzeSelected() {
        guard isInitialized else {
            updateStatus(loading: false, message: "Python not initialized")
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
                    
                    // Mark PR as analyzed
                    if let index = self.pullRequests.firstIndex(where: { $0.id == pr.id }) {
                        self.pullRequests[index].hasAnalysis = true
                    }
                    
                    self.updateStatus(loading: false, message: "Analysis complete for PR #\(pr.number)")
                }
            } catch {
                DispatchQueue.main.async {
                    self.updateStatus(loading: false, message: "Error analyzing PR: \(error.localizedDescription)")
                    print("Error analyzing PR: \(error)")
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
                    
                    // Mark issue as analyzed
                    if let index = self.issues.firstIndex(where: { $0.id == issue.id }) {
                        self.issues[index].hasAnalysis = true
                    }
                    
                    self.updateStatus(loading: false, message: "Analysis complete for issue #\(issue.number)")
                }
            } catch {
                DispatchQueue.main.async {
                    self.updateStatus(loading: false, message: "Error analyzing issue: \(error.localizedDescription)")
                    print("Error analyzing issue: \(error)")
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
                    print("Error generating fix: \(error)")
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
            // Save fix content to a temporary file
            let tempDir = NSTemporaryDirectory()
            let fixFilePath = "\(tempDir)/issue_fix_\(issue.number).md"
            try fixContent.write(toFile: fixFilePath, atomically: true, encoding: .utf8)
            
            // Run Python command to apply fix
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
            print("Error committing fix: \(error)")
            return false
        }
    }
    
    func createPR(title: String, body: String, baseBranch: String = "main") -> Bool {
        guard isInitialized else {
            updateStatus(loading: false, message: "Python not initialized")
            return false
        }
        
        updateStatus(loading: true, message: "Creating PR...")
        
        do {
            let tempDir = NSTemporaryDirectory()
            let bodyFilePath = "\(tempDir)/pr_body.md"
            try body.write(toFile: bodyFilePath, atomically: true, encoding: .utf8)
            
            let result = try runPythonCommand(arguments: [
                "create-pr",
                "--title", title,
                "--body-file", bodyFilePath,
                "--base", baseBranch
            ])
            
            updateStatus(loading: false, message: "PR created: \(result)")
            return true
        } catch {
            updateStatus(loading: false, message: "Error creating PR: \(error.localizedDescription)")
            print("Error creating PR: \(error)")
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
        let error = String(data: errorData, encoding: .utf8) ?? ""
        
        if process.terminationStatus != 0 {
            throw NSError(domain: "com.aicollab", code: Int(process.terminationStatus),
                          userInfo: [NSLocalizedDescriptionKey: error.isEmpty ? "Unknown error" : error])
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
            let issues = try JSONDecoder().decode([GithubIssue].self, from: jsonData)
            return issues
        } catch {
            print("Error parsing issues JSON: \(error)")
            return []
        }
    }
    
    private func parsePRs(from jsonString: String) -> [GithubPR] {
        guard let jsonData = jsonString.data(using: .utf8) else { return [] }
        
        do {
            let prs = try JSONDecoder().decode([GithubPR].self, from: jsonData)
            return prs
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
        
        // Sample issues
        bridge.issues = [
            GithubIssue(
                id: "1", 
                number: 101, 
                title: "Audio module crashes on high frequencies", 
                body: """
                    The audio processing module crashes when processing frequencies above 18kHz. 
                    The issue occurs consistently when playing audio with frequencies in the 19-22kHz range. 
                    We need to implement a proper frequency filtering mechanism that safely handles these high-frequency signals.
                    """, 
                labels: ["bug", "audio"], 
                updatedAt: "2025-04-09T15:32:00Z", 
                hasAnalysis: true
            ),
            GithubIssue(
                id: "2", 
                number: 102, 
                title: "Implement FFT visualization", 
                body: """
                    We need to add a real-time FFT visualization component that displays the frequency spectrum of the audio being processed. 
                    This should be integrated with the main interface and provide customizable parameters like window size and scaling.
                    """, 
                labels: ["enhancement", "visualization"], 
                updatedAt: "2025-04-10T09:15:12Z"
            ),
            GithubIssue(
                id: "3", 
                number: 103, 
                title: "Memory leak in AudioBuffer class", 
                body: """
                    There appears to be a memory leak in the AudioBuffer class when allocating large buffers. 
                    The memory isn't properly released when the buffer is no longer needed, leading to gradually increasing memory usage over time.
                    """, 
                labels: ["bug", "memory", "critical"], 
                updatedAt: "2025-04-10T11:45:30Z"
            )
        ]
        
        // Sample PRs
        bridge.pullRequests = [
            GithubPR(
                id: "101", 
                number: 104, 
                title: "Fix audio processing performance issues", 
                body: """
                    This PR addresses the performance bottlenecks in the audio processing pipeline. 
                    I've optimized the buffer handling code and added better concurrency management to improve throughput. 
                    The PR includes comprehensive benchmarks showing a 35% improvement in processing time.
                    """, 
                branchName: "fix/performance-improvements", 
                updatedAt: "2025-04-08T14:22:00Z", 
                hasAnalysis: true
            ),
            GithubPR(
                id: "102", 
                number: 105, 
                title: "Add support for FLAC encoding", 
                body: """
                    This PR adds FLAC encoding support to the existing audio exporting functionality. 
                    FLAC provides lossless compression while maintaining audio quality. 
                    I've integrated the libFLAC library and added appropriate Swift wrappers to make it consistent with our existing API.
                    """, 
                branchName: "feature/flac-support", 
                updatedAt: "2025-04-09T16:40:21Z"
            ),
            GithubPR(
                id: "103", 
                number: 106, 
                title: "Update Swift 6 compatibility", 
                body: """
                    This PR updates the codebase to maintain compatibility with Swift 6 and macOS 15+. 
                    I've addressed deprecated APIs and adopted new Swift 6 features where appropriate. 
                    All tests are passing and the app functions correctly on the latest macOS version.
                    """, 
                    branchName: "maintenance/swift6-update", updatedAt: "2025-04-10T10:05:45Z")
        ]
        
        // Sample analysis
        bridge.currentAnalysis = """
            # Collaborative PR Review: #104 - Fix audio processing performance issues
            
            ## Primary Analysis (llama3.2:latest)
            
            This PR implements several important performance improvements to the audio processing pipeline:
            
            1. **Buffer Management**: The PR replaces single-use buffers with a buffer pool, significantly reducing memory allocations during audio processing.
            
            2. **Concurrency Improvements**: The implementation now uses Swift's structured concurrency with async/await patterns to better manage parallel processing tasks.
            
            3. **Algorithm Optimization**: The FFT algorithm has been optimized by using a more efficient implementation that reduces computational complexity.
            
            The changes look well-structured and follow best practices for Swift 6 and macOS 15+. The performance benchmarks included in the PR show a significant improvement (35%) in processing time, which aligns with the code changes observed.
            
            One concern is the thread safety of the buffer pool implementation. While the implementation uses actors for thread isolation, there could be potential issues with buffer reuse that might lead to race conditions in edge cases.
            
            ## Enhanced Review (deepseek-r1:8b)
            
            Building on the primary analysis, here are additional considerations and technical insights:
            
            **Swift 6 Compatibility**: The PR properly leverages new Swift 6 features:
            - Correct use of `@preconcurrency` attribute for legacy code integration
            - Proper implementation of `Sendable` conformance for thread-safe types
            - Strategic use of new memory management APIs for better buffer handling
            
            **Audio Processing Specific Concerns**:
            - The buffer pooling strategy could potentially introduce latency during high-demand processing. Consider adding a dynamic scaling mechanism for the pool size based on load.
            - The FFT optimization appears to use Apple's Accelerate framework effectively, but consider adding fallbacks for edge cases.
            
            **Memory Management**:
            ```swift
            func recycleBuffer(_ buffer: AudioBuffer) {
                // Current implementation
                pool.append(buffer)
                
                // Suggested enhancement
                if pool.count > maxPoolSize {
                    // Trim excess buffers when pool grows too large
                    pool = Array(pool.suffix(maxPoolSize))
                }
            }
            ```
            
            **Performance Testing**:
            While the PR includes benchmarks showing a 35% improvement, it would be beneficial to include real-world testing scenarios that simulate typical user workloads rather than synthetic benchmarks alone.
            
            ## Next Steps
            
            1. Review the feedback above
            2. Address thread safety concerns in the buffer pool implementation
            3. Consider implementing the suggested enhancements to buffer management
            4. Add more comprehensive real-world performance tests
            """
        
        // Sample fix content
        bridge.fixContent = """
            # Collaborative Solution: Issue #101 - Audio module crashes on high frequencies
            
            ## Initial Solution (llama3.2:latest)
            
            The issue with high frequency crashes appears to be related to improper buffer handling when processing frequencies above the Nyquist frequency (half the sampling rate). Here's my proposed solution:
            
            1. Implement a high-frequency filtering mechanism that safely handles frequencies above 18kHz:
            
            ```swift
            struct SafeFrequencyHandler {
                private let sampleRate: Double
                private let nyquistFrequency: Double
                
                init(sampleRate: Double = 44100.0) {
                    self.sampleRate = sampleRate
                    self.nyquistFrequency = sampleRate / 2.0
                }
                
                func processSamples(_ samples: [Float], maxFrequency: Double? = nil) -> [Float] {
                    let maxFreq = min(maxFrequency ?? nyquistFrequency, nyquistFrequency * 0.95)
                    
                    // Apply low-pass filter to remove frequencies above the safe threshold
                    return applyLowPassFilter(samples, cutoffFrequency: maxFreq)
                }
                
                private func applyLowPassFilter(_ samples: [Float], cutoffFrequency: Double) -> [Float] {
                    // Implementation of a simple low-pass filter
                    // This can be enhanced with more sophisticated filtering methods
                    
                    // For now, using Apple's Accelerate framework for efficient filtering
                    // (Actual implementation would use vDSP for real-time filtering)
                    
                    // This is a simplified example
                    return samples.map { $0 * 0.95 } // Placeholder for actual filter
                }
            }
            ```
            
            2. Update the AudioProcessor class to use our new SafeFrequencyHandler:
            
            ```swift
            class AudioProcessor {
                private let frequencyHandler: SafeFrequencyHandler
                
                init(sampleRate: Double = 44100.0) {
                    self.frequencyHandler = SafeFrequencyHandler(sampleRate: sampleRate)
                }
                
                func processBuffer(_ buffer: AudioBuffer) -> AudioBuffer {
                    // Extract samples from buffer
                    let samples = buffer.samples
                    
                    // Process with frequency safety
                    let processedSamples = frequencyHandler.processSamples(samples)
                    
                    // Create new buffer with processed samples
                    return AudioBuffer(samples: processedSamples, format: buffer.format)
                }
            }
            ```
            
            ## Enhanced Solution (deepseek-r1:8b)
            
            While the initial solution provides a good foundation, here are some enhancements to make it more robust:
            
            1. **Use Accelerate Framework Properly**:
            
            Instead of the placeholder in the low-pass filter, we should implement a proper filter using vDSP:
            
            ```swift
            import Accelerate
            
            private func applyLowPassFilter(_ samples: [Float], cutoffFrequency: Double) -> [Float] {
                let filterLength = 101  // Should be odd
                let filterHalfLength = filterLength / 2
                
                // Calculate normalized cutoff frequency (0.0 to 1.0)
                let normalizedCutoff = cutoffFrequency / (sampleRate / 2.0)
                
                // Create filter coefficients (Windowed Sinc)
                var coefficients = [Float](repeating: 0.0, count: filterLength)
                
                for i in 0..<filterLength {
                    if i != filterHalfLength {
                        let x = Float.pi * Float(i - filterHalfLength)
                        coefficients[i] = sin(2.0 * Float(normalizedCutoff) * x) / x
                        
                        // Apply Hamming window
                        let windowCoeff = 0.54 - 0.46 * cos(2.0 * Float.pi * Float(i) / Float(filterLength - 1))
                        coefficients[i] *= windowCoeff
                    } else {
                        coefficients[i] = 2.0 * Float(normalizedCutoff)
                    }
                }
                
                // Normalize coefficients
                let sum = vDSP.sum(coefficients)
                vDSP.divide(coefficients, sum, result: &coefficients)
                
                // Apply filter using convolution
                let paddedSamples = [Float](repeating: 0.0, count: filterHalfLength) + samples + [Float](repeating: 0.0, count: filterHalfLength)
                var result = [Float](repeating: 0.0, count: samples.count)
                
                vDSP.convolve(paddedSamples, coefficients, result: &result)
                return result
            }
            ```
            
            2. **Add Error Handling and Diagnostics**:
            
            ```swift
            enum AudioProcessingError: Error {
                case frequencyOutOfRange(frequency: Double, maxAllowed: Double)
                case bufferProcessingFailed(reason: String)
                
                var description: String {
                    switch self {
                    case .frequencyOutOfRange(let frequency, let maxAllowed):
                        return "Frequency \(frequency)Hz exceeds maximum allowed \(maxAllowed)Hz"
                    case .bufferProcessingFailed(let reason):
                        return "Buffer processing failed: \(reason)"
                    }
                }
            }
            
            // Updated processor method with diagnostics
            func processBuffer(_ buffer: AudioBuffer) throws -> AudioBuffer {
                do {
                    // Check if buffer contains suspicious high frequencies
                    let highestFrequency = analyzeHighestFrequency(buffer)
                    logger.debug("Detected highest frequency: \(highestFrequency) Hz")
                    
                    if highestFrequency > nyquistFrequency {
                        logger.warning("Potentially unsafe frequency detected: \(highestFrequency) Hz")
                    }
                    
                    // Extract samples from buffer
                    let samples = buffer.samples
                    
                    // Process with frequency safety
                    let processedSamples = frequencyHandler.processSamples(samples)
                    
                    // Create new buffer with processed samples
                

