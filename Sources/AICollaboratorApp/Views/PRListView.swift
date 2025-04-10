import SwiftUI

struct PRListView: View {
    @EnvironmentObject private var pythonBridge: PythonBridge
    @EnvironmentObject private var logManager: LogManager
    
    @State private var selectedPR: GithubPR? = nil
    @State private var searchText: String = ""
    @State private var showPRDetail: Bool = false
    
    private var filteredPRs: [GithubPR] {
        if searchText.isEmpty {
            return pythonBridge.pullRequests
        } else {
            return pythonBridge.pullRequests.filter { pr in
                pr.title.localizedCaseInsensitiveContains(searchText) ||
                pr.body.localizedCaseInsensitiveContains(searchText) ||
                pr.branchName.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        VStack {
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search pull requests", text: $searchText)
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
            
            if pythonBridge.pullRequests.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "arrow.triangle.pull")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    
                    Text("No pull requests found")
                        .font(.title2)
                    
                    Text("Click 'Fetch PRs' to load open pull requests from GitHub")
                        .foregroundColor(.secondary)
                    
                    Button("Fetch PRs") {
                        logManager.log("Manually fetching pull requests", level: .info)
                        pythonBridge.fetchPRs()
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.top)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.windowBackgroundColor).opacity(0.5))
            } else {
                List(filteredPRs, selection: $pythonBridge.selectedPRId) { pr in
                    PRRow(pr: pr)
                        .padding(.vertical, 4)
                        .onTapGesture {
                            selectedPR = pr
                            showPRDetail = true
                        }
                        .contextMenu {
                            Button("Analyze") {
                                analyzePR(pr)
                            }
                            
                            Divider()
                            
                            Button("Open in GitHub") {
                                openInGitHub(pr)
                            }
                        }
                }
                .listStyle(.inset)
                .refreshable {
                    logManager.log("Refreshing PRs via pull-to-refresh", level: .debug)
                    await refreshPRs()
                }
            }
        }
        .sheet(isPresented: $showPRDetail, content: {
            if let pr = selectedPR {
                PRDetailView(pr: pr)
                    .environmentObject(pythonBridge)
                    .environmentObject(logManager)
                    .frame(width: 700, height: 600)
            }
        })
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    logManager.log("Manually fetching pull requests", level: .info)
                    pythonBridge.fetchPRs()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Refresh pull requests")
                .disabled(pythonBridge.isLoading)
            }
            
            ToolbarItem(placement: .automatic) {
                if let prId = pythonBridge.selectedPRId,
                   let pr = pythonBridge.pullRequests.first(where: { $0.id == prId }) {
                    Menu {
                        Button("Analyze") {
                            analyzePR(pr)
                        }
                        
                        Divider()
                        
                        Button("Open in GitHub") {
                            openInGitHub(pr)
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
    }
    
    private func analyzePR(_ pr: GithubPR) {
        logManager.log("Analyzing PR #\(pr.number): \(pr.title)", level: .info)
        pythonBridge.selectedPRId = pr.id
        pythonBridge.selectedIssueId = nil
        pythonBridge.analyzePR(pr)
    }
    
    private func openInGitHub(_ pr: GithubPR) {
        guard let url = URL(string: "https://github.com/\(pythonBridge.repo)/pull/\(pr.number)") else {
            logManager.log("Failed to create GitHub URL for PR #\(pr.number)", level: .error)
            return
        }
        
        NSWorkspace.shared.open(url)
    }
    
    private func refreshPRs() async {
        pythonBridge.fetchPRs()
    }
}

struct PRRow: View {
    let pr: GithubPR
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("#\(pr.number)")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Text(pr.title)
                    .font(.headline)
                
                Spacer()
                
                if pr.hasAnalysis {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            }
            
            Text(pr.bodyPreview)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(2)
            
            HStack {
                Text(pr.branchName)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.purple.opacity(0.2))
                    .cornerRadius(4)
                
                Spacer()
                
                Text("Updated: \(pr.updatedAt)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct PRDetailView: View {
    let pr: GithubPR
    @EnvironmentObject private var pythonBridge: PythonBridge
    @EnvironmentObject private var logManager: LogManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading) {
                    Text("Pull Request #\(pr.number)")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text(pr.title)
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
                    // PR metadata
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Branch: \(pr.branchName)")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.purple.opacity(0.2))
                                .cornerRadius(4)
                            
                            Spacer()
                            
                            Text("Updated: \(pr.updatedAt)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // PR body
                    Text(pr.body)
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
                    analyzePR()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
    }
    
    private func analyzePR() {
        logManager.log("Analyzing PR #\(pr.number) from detail view", level: .info)
        pythonBridge.selectedPRId = pr.id
        pythonBridge.selectedIssueId = nil
        pythonBridge.analyzePR(pr)
    }
    
    private func openInGitHub() {
        guard let url = URL(string: "https://github.com/\(pythonBridge.repo)/pull/\(pr.number)") else {
            logManager.log("Failed to create GitHub URL for PR #\(pr.number)", level: .error)
            return
        }
        
        NSWorkspace.shared.open(url)
    }
}

#Preview {
    PRListView()
        .environmentObject(PythonBridge.preview)
        .environmentObject(LogManager())
}
