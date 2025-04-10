import SwiftUI

struct AnalysisView: View {
    @EnvironmentObject private var pythonBridge: PythonBridge
    @EnvironmentObject private var logManager: LogManager
    
    @State private var isFixingIssue = false
    @State private var showCommitSheet = false
    @State private var branchName = ""
    @State private var commitMessage = ""
    
    var body: some View {
        VStack {
            if let analysis = pythonBridge.currentAnalysis {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                if pythonBridge.selectedItemIsPR {
                                    Text("Pull Request Analysis")
                                        .font(.headline)
                                } else {
                                    Text("Issue Analysis")
                                        .font(.headline)
                                }
                                
                                Spacer()
                                
                                if !pythonBridge.selectedItemIsPR {
                                    Button(isFixingIssue ? "Cancel Fix" : "Fix Issue") {
                                        if isFixingIssue {
                                            isFixingIssue = false
                                        } else {
                                            isFixingIssue = true
                                            isFixingIssue = true
                                            pythonBridge.generateIssueFix()
                                        }
                                    .buttonStyle(isFixingIssue ? .bordered : .borderedProminent)
                                }
                                
                                if isFixingIssue && pythonBridge.fixContent != nil {
                                    Button("Commit Fix") {
                                        // Create default branch name and commit message based on issue
                                        if let issueId = pythonBridge.selectedIssueId,
                                           let issue = pythonBridge.issues.first(where: { $0.id == issueId }) {
                                            branchName = "fix/issue-\(issue.number)"
                                            commitMessage = "Fix #\(issue.number): \(issue.title)"
                                        }
                                        showCommitSheet = true
                                    }
                                    .buttonStyle(.borderedProminent)
                                }
                            }
                        }
                        
                        Divider()
                        
                        if isFixingIssue && pythonBridge.fixContent != nil {
                            Text("Fix Solution")
                                .font(.headline)
                                .padding(.top, 8)
                            
                            MarkdownView(content: pythonBridge.fixContent ?? "")
                                .padding(.vertical)
                        } else {
                            MarkdownView(content: analysis)
                                .padding(.vertical)
                        }
                    }
                    .padding()
                }
            } else {
                VStack(spacing: 20) {
                    Image(systemName: "text.magnifyingglass")
                        .font(.system(size: 64))
                        .foregroundColor(.secondary)
                    
                    Text("No Analysis Available")
                        .font(.title)
                    
                    Text("Select an issue or PR and click 'Analyze Selected' to generate an analysis.")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.windowBackgroundColor).opacity(0.5))
            }
        }
        .sheet(isPresented: $showCommitSheet) {
            CommitSheet(
                isPresented: $showCommitSheet,
                branchName: $branchName,
                commitMessage: $commitMessage,
                onCommit: {
                    logManager.log("Committing fix with branch: \(branchName)", level: .info)
                    if pythonBridge.commitIssueFix(commitMessage: commitMessage, branchName: branchName) {
                        isFixingIssue = false
                    }
                }
            )
        }
    }
}

struct MarkdownView: View {
    let content: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Simple parsing of markdown for headers, code blocks, and lists
            ForEach(parseMarkdown(content), id: \.id) { block in
                switch block.type {
                case .header1:
                    Text(block.content)
                        .font(.title)
                        .fontWeight(.bold)
                        .padding(.top, 8)
                case .header2:
                    Text(block.content)
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding(.top, 6)
                case .header3:
                    Text(block.content)
                        .font(.title3)
                        .fontWeight(.bold)
                        .padding(.top, 4)
                case .codeBlock:
                    Text(block.content)
                        .font(.system(.body, design: .monospaced))
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                case .listItem:
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                        Text(block.content)
                    }
                case .text:
                    Text(block.content)
                }
            }
        }
    }
    
    private func parseMarkdown(_ text: String) -> [MarkdownBlock] {
        var blocks: [MarkdownBlock] = []
        var codeBlockLines: [String] = []
        var inCodeBlock = false
        
        let lines = text.components(separatedBy: .newlines)
        
        for (index, line) in lines.enumerated() {
            if line.starts(with: "```") {
                if inCodeBlock {
                    // End code block
                    blocks.append(MarkdownBlock(
                        id: UUID().uuidString,
                        type: .codeBlock,
                        content: codeBlockLines.joined(separator: "\n")
                    ))
                    codeBlockLines = []
                    inCodeBlock = false
                } else {
                    // Start code block
                    inCodeBlock = true
                }
                continue
            }
            
            if inCodeBlock {
                codeBlockLines.append(line)
                continue
            }
            
            // Headers
            if line.starts(with: "# ") {
                blocks.append(MarkdownBlock(
                    id: "\(index)",
                    type: .header1,
                    content: line.dropFirst(2).trimmingCharacters(in: .whitespaces)
                ))
            } else if line.starts(with: "## ") {
                blocks.append(MarkdownBlock(
                    id: "\(index)",
                    type: .header2,
                    content: line.dropFirst(3).trimmingCharacters(in: .whitespaces)
                ))
            } else if line.starts(with: "### ") {
                blocks.append(MarkdownBlock(
                    id: "\(index)",
                    type: .header3,
                    content: line.dropFirst(4).trimmingCharacters(in: .whitespaces)
                ))
            }
            // List items
            else if line.starts(with: "- ") || line.starts(with: "* ") || line.matches(regex: #"^\d+\.\s"#) {
                let content: String
                if let range = line.range(of: #"^[\-\*\d\.]+\s"#, options: .regularExpression) {
                    content = line[range.upperBound...].trimmingCharacters(in: .whitespaces)
                } else {
                    content = line
                }
                blocks.append(MarkdownBlock(
                    id: "\(index)",
                    type: .listItem,
                    content: content
                ))
            }
            // Plain text
            else if !line.isEmpty {
                blocks.append(MarkdownBlock(
                    id: "\(index)",
                    type: .text,
                    content: line
                ))
            }
        }
        
        return blocks
    }
}

struct MarkdownBlock: Identifiable {
    let id: String
    let type: MarkdownBlockType
    let content: String
}

enum MarkdownBlockType {
    case header1
    case header2
    case header3
    case codeBlock
    case listItem
    case text
}

struct CommitSheet: View {
    @Binding var isPresented: Bool
    @Binding var branchName: String
    @Binding var commitMessage: String
    let onCommit: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Commit Fix")
                .font(.title2)
                .bold()
            
            Form {
                Section(header: Text("Branch Name")) {
                    TextField("Branch name", text: $branchName)
                        .textFieldStyle(.roundedBorder)
                }
                
                Section(header: Text("Commit Message")) {
                    TextEditor(text: $commitMessage)
                        .frame(height: 100)
                        .border(Color.gray.opacity(0.2))
                }
            }
            .formStyle(.grouped)
            
            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button("Commit") {
                    onCommit()
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(branchName.isEmpty || commitMessage.isEmpty)
            }
            .padding(.horizontal)
        }
        .padding()
        .frame(width: 500, height: 400)
    }
}

extension String {
    func matches(regex pattern: String) -> Bool {
        do {
            let regex = try NSRegularExpression(pattern: pattern)
            let range = NSRange(self.startIndex..., in: self)
            return regex.firstMatch(in: self, range: range) != nil
        } catch {
            return false
        }
    }
}

#Preview {
    AnalysisView()
        .environmentObject(PythonBridge.preview)
        .environmentObject(PythonBridge.preview)
        .environmentObject(LogManager())
}
