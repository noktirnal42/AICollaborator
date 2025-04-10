import SwiftUI

struct IssueListView: View {
    @EnvironmentObject private var pythonBridge: PythonBridge
    @EnvironmentObject private var logManager: LogManager
    
    @State private var selectedIssue: GithubIssue? = nil
    @State private var searchText: String = ""
    @State private var showIssueDetail: Bool = false
    
    private var filteredIssues: [GithubIssue] {
        if searchText.isEmpty {
            return pythonBridge.issues
        } else {
            return pythonBridge.issues.filter { issue in
                issue.title.localizedCaseInsensitiveContains(searchText) ||
                issue.body.localizedCaseInsensitiveContains(searchText) ||
                issue.labels.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
        }
    }
    
    var body: some View {
        VStack {
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search issues", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            
            if pythonBridge.issues.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.circle")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    
                    Text("No issues found")
                        .font(.title2)
                    
                    Text("Click 'Fetch Issues' to load open issues from GitHub")
                        .foregroundColor(.secondary)
                    
                    Button("Fetch Issues") {
                        logManager.log("Manually fetching issues", level: .info)
                        pythonBridge.fetchIssues()
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.top)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.windowBackgroundColor).opacity(0.5))
            } else {
                List(filteredIssues, selection: $pythonBridge.selectedIssueId) { issue in
                    IssueRow(issue: issue)
                        .padding(.vertical, 4)
                        .onTapGesture {
                            selectedIssue = issue
                            showIssueDetail = true
                        }
                        .contextMenu {
                            Button("Analyze") {
                                analyzeIssue(issue)
                            }
                            
                            Button("Fix Issue") {
                                fixIssue(issue)
                            }
                            
                            Divider()
                            
                            Button("Open in GitHub") {
                                openInGitHub(issue)
                            }
                        }
                }
                .listStyle(.inset)
                .refreshable {
                    logManager.log("Refreshing issues via pull-to-refresh", level: .debug)
                    await refreshIssues()
                }
            }
        }
        .sheet(isPresented: $showIssueDetail, content: {
            if let issue = selectedIssue {
                IssueDetailView(issue: issue)
                    .environmentObject(pythonBridge)
                    .environmentObject(logManager)
                    .frame(width: 700, height: 600)
            }
        })
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    logManager.log("Manually fetching issues", level: .info)
                    pythonBridge.fetchIssues()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Refresh issues")
                .disabled(pythonBridge.isLoading)
            }
            
            ToolbarItem(placement: .automatic) {
                if let issueId = pythonBridge.selectedIssueId,
                   let issue = pythonBridge.issues.first(where: { $0.id == issueId }) {
                    Menu {
                        Button("Analyze") {
                            analyzeIssue(issue)
                        }
                        
                        Button("Fix Issue") {
                            fixIssue(issue)
                        }
                        
                        Divider()
                        
                        Button("Open in GitHub") {
                            openInGitHub(issue)
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
    }
    
    private func analyzeIssue(_ issue: GithubIssue) {
        logManager.log("Analyzing issue #\(issue.number): \(issue.title)", level: .info)
        pythonBridge.selectedIssueId = issue.id
        pythonBridge.selectedPRId = nil
        pythonBridge.analyzeIssue(issue)
    }
    
    private func fixIssue(_ issue: GithubIssue) {
        logManager.log("Generating fix for issue #\(issue.number): \(issue.title)", level: .info)
        pythonBridge.selectedIssueId = issue.id
        pythonBridge.selectedPRId = nil
        pythonBridge.generateIssueFix()
    }
    
    private func openInGitHub(_ issue: GithubIssue) {
        guard let url = URL(string: "https://github.com/\(pythonBridge.repo)/issues/\(issue.number)") else {
            logManager.log("Failed to create GitHub URL for issue #\(issue.number)", level: .error)
            return
        }
        
        NSWorkspace.shared.open(url)
    }
    
    private func refreshIssues() async {
        pythonBridge.fetchIssues()
    }
}

struct IssueRow: View {
    let issue: GithubIssue
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("#\(issue.number)")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Text(issue.title)
                    .font(.headline)
                
                Spacer()
                
                if issue.hasAnalysis {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            }
            
            Text(issue.bodyPreview)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(2)
            
            HStack {
                ForEach(issue.labels, id: \.self) { label in
                    Text(label)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(4)
                }
                
                Spacer()
                
                Text("Updated: \(issue.updatedAt)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct IssueDetailView: View {
    let issue: GithubIssue
    @EnvironmentObject private var pythonBridge: PythonBridge
    @EnvironmentObject private var logManager: LogManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading) {
                    Text("Issue #\(issue.number)")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text(issue.title)
                        .font(.title2)
                        .fontWeight(.bold)
                }
                
                Spacer()
                
                Button("Close") {
                    dismiss()
                }
                .keyboardShortcut(.escape, modifiers: [])
            }
            .padding()
            .background(Color(.windowBackgroundColor))
            
            Divider()
            
            // Body
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Issue metadata
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            ForEach(issue.labels, id: \.self) { label in
                                Text(label)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(Color.blue.opacity(0.2))
                                    .cornerRadius(4)
                            }
                            
                            Spacer()
                            
                            Text("Updated: \(issue.updatedAt)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Issue body
                    Text(issue.body)
                        .font(.body)
                    
                    Spacer()
                }
                .padding()
            }
            
            Divider()
            
            // Action buttons
            HStack {
                Spacer()
                
                Button("Open in GitHub") {
                    openInGitHub()
                }
                .buttonStyle(.bordered)
                
                Button("Analyze") {
                    analyzeIssue()
                    dismiss()
                }
                .buttonStyle(.bordered)
                
                Button("Fix Issue") {
                    fixIssue()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
    }
    
    private func analyzeIssue() {
        logManager.log("Analyzing issue #\(issue.number) from detail view", level: .info)
        pythonBridge.selectedIssueId = issue.id
        pythonBridge.selectedPRId = nil
        pythonBridge.analyzeIssue(issue)
    }
    
    private func fixIssue() {
        logManager.log("Generating fix for issue #\(issue.number) from detail view", level: .info)
        pythonBridge.selectedIssueId = issue.id
        pythonBridge.selectedPRId = nil
        pythonBridge.generateIssueFix()
    }
    
    private func openInGitHub() {
        guard let url = URL(string: "https://github.com/\(pythonBridge.repo)/issues/\(issue.number)") else {
            logManager.log("Failed to create GitHub URL for issue #\(issue.number)", level: .error)
            return
        }
        
        NSWorkspace.shared.open(url)
    }
}

#Preview {
    IssueListView()
        .environmentObject(PythonBridge.preview)
        .environmentObject(LogManager())
}
