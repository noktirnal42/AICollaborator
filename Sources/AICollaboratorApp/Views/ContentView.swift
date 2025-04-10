import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var pythonBridge: PythonBridge
    @EnvironmentObject private var logManager: LogManager
    
    @State private var selectedTab = 0
    @State private var showLog = false
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("AI Collaborator")
                    .font(.largeTitle)
                    .bold()
                    .padding()
                
                Spacer()
                
                HStack(spacing: 16) {
                    Button("Fetch Issues") {
                        pythonBridge.fetchIssues()
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button("Fetch PRs") {
                        pythonBridge.fetchPRs()
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button("Analyze Selected") {
                        pythonBridge.analyzeSelected()
                    }
                    .buttonStyle(.bordered)
                    .disabled(pythonBridge.selectedItem == nil)
                }
                .padding()
            }
            .background(Color(.windowBackgroundColor))
            
            TabView(selection: $selectedTab) {
                IssueListView()
                    .tabItem {
                        Label("Issues", systemImage: "exclamationmark.circle")
                    }
                    .tag(0)
                
                PRListView()
                    .tabItem {
                        Label("Pull Requests", systemImage: "arrow.triangle.pull")
                    }
                    .tag(1)
                
                AnalysisView()
                    .tabItem {
                        Label("Analysis", systemImage: "text.magnifyingglass")
                    }
                    .tag(2)
            }
            
            if showLog || settings.showLog {
                Divider()
                
                LogView()
                    .frame(height: 200)
            }
            
            HStack {
                Button(showLog ? "Hide Log" : "Show Log") {
                    showLog.toggle()
                }
                .buttonStyle(.plain)
                .padding(.horizontal)
                
                Spacer()
                
                StatusBar()
            }
            .padding(.vertical, 4)
            .background(Color(.windowBackgroundColor))
        }
    }
}

struct StatusBar: View {
    @EnvironmentObject private var pythonBridge: PythonBridge
    
    var body: some View {
        HStack {
            if pythonBridge.isLoading {
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(0.7)
                    .padding(.trailing, 4)
                
                Text(pythonBridge.statusMessage)
            } else {
                Image(systemName: pythonBridge.isInitialized ? "circle.fill" : "circle")
                    .foregroundColor(pythonBridge.isInitialized ? .green : .red)
                
                Text(pythonBridge.statusMessage)
            }
        }
        .font(.caption)
        .padding(.horizontal)
    }
}

#Preview {
    ContentView()
        .environmentObject(AppSettings())
        .environmentObject(PythonBridge())
        .environmentObject(LogManager())
}

