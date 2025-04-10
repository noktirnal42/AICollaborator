import SwiftUI

@main
struct AICollaboratorApp: App {
    // State objects for app-wide state management
    @StateObject private var pythonBridge = PythonBridge()
    @StateObject private var logManager = LogManager()
    @StateObject private var settings = AppSettings()
    
    // App state
    @State private var sidebarSelection: NavigationItem? = .dashboard
    @State private var isInitializing = true
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                // Main content view with navigation
                NavigationSplitView {
                    SidebarView(selection: $sidebarSelection)
                        .environmentObject(pythonBridge)
                        .environmentObject(logManager)
                } detail: {
                    if isInitializing {
                        InitializingView(isInitializing: $isInitializing)
                            .environmentObject(pythonBridge)
                            .environmentObject(logManager)
                    } else {
                        DetailView(selection: sidebarSelection)
                            .environmentObject(pythonBridge)
                            .environmentObject(logManager)
                            .environmentObject(settings)
                    }
                }
                .navigationSplitViewStyle(.balanced)
            }
            .onAppear {
                // Initialize services when app appears
                logManager.log("Application started", level: .info)
                pythonBridge.initialize()
                
                // Set up automatic GitHub monitoring if enabled
                if settings.autoRefreshEnabled {
                    startMonitoring()
                }
                
                // Auto-hide initialization screen after a short delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    if pythonBridge.isInitialized {
                        isInitializing = false
                    }
                }
            }
            .onChange(of: pythonBridge.isInitialized) { newValue in
                if newValue {
                    // Hide initialization screen when Python is initialized
                    isInitializing = false
                }
            }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.automatic)
        .commands {
            // Menu commands
            SidebarCommands()
            ToolbarCommands()
            
            CommandMenu("GitHub") {
                Button("Fetch Issues") {
                    pythonBridge.fetchIssues()
                }
                .keyboardShortcut("I", modifiers: [.command])
                
                Button("Fetch PRs") {
                    pythonBridge.fetchPRs()
                }
                .keyboardShortcut("P", modifiers: [.command])
                
                Divider()
                
                Button("Analyze Selected") {
                    pythonBridge.analyzeSelected()
                }
                .keyboardShortcut("A", modifiers: [.command])
                .disabled(pythonBridge.selectedItem == nil)
                
                Divider()
                
                Button("Toggle Monitoring") {
                    settings.autoRefreshEnabled.toggle()
                    if settings.autoRefreshEnabled {
                        startMonitoring()
                    }
                    settings.saveSettings()
                }
                .keyboardShortcut("M", modifiers: [.command])
            }
            
            CommandMenu("View") {
                Button("Show Log") {
                    settings.showLog.toggle()
                    settings.saveSettings()
                }
                .keyboardShortcut("L", modifiers: [.command])
            }
        }
        
        // Settings UI
        Settings {
            SettingsView()
                .environmentObject(settings)
                .environmentObject(pythonBridge)
                .environmentObject(logManager)
                .frame(width: 550, height: 450)
        }
    }
    
    private func startMonitoring() {
        // Set up a timer to periodically check for new PRs and issues
        Timer.scheduledTimer(withTimeInterval: settings.refreshInterval, repeats: true) { _ in
            if pythonBridge.isInitialized && !pythonBridge.isLoading {
                logManager.log("Auto-refreshing GitHub data", level: .debug)
                pythonBridge.fetchIssues()
                pythonBridge.fetchPRs()
            }
        }
    }
}

// MARK: - Navigation Items
enum NavigationItem: String, Identifiable, CaseIterable {
    case dashboard = "Dashboard"
    case issues = "Issues"
    case pullRequests = "Pull Requests"
    case analysis = "Analysis"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .dashboard:
            return "square.grid.2x2"
        case .issues:
            return "exclamationmark.circle"
        case .pullRequests:
            return "arrow.triangle.pull"
        case .analysis:
            return "text.magnifyingglass"
        }
    }
}

// MARK: - Views

// Navigation Sidebar View
struct SidebarView: View {
    @Binding var selection: NavigationItem?
    @EnvironmentObject var pythonBridge: PythonBridge
    @EnvironmentObject var logManager: LogManager
    
    var body: some View {
        List(selection: $selection) {
            ForEach(NavigationItem.allCases) { item in
                NavigationLink(value: item) {
                    Label {
                        Text(item.rawValue)
                    } icon: {
                        Image(systemName: item.icon)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("AI Collaborator")
    }
}

// Main Content View based on selection
struct DetailView: View {
    var selection: NavigationItem?
    @EnvironmentObject var pythonBridge: PythonBridge
    @EnvironmentObject var logManager: LogManager
    @EnvironmentObject var settings: AppSettings
    
    var body: some View {
        VStack(spacing: 0) {
            // Main content area
            Group {
                switch selection {
                case .dashboard:
                    DashboardView()
                case .issues:
                    IssueListView()
                case .pullRequests:
                    PRListView()
                case .analysis:
                    AnalysisView()
                case nil:
                    EmptyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Log view (collapsible)
            if settings.showLog {
                Divider()
                LogView()
                    .frame(height: 200)
            }
        }
        .navigationTitle(selection?.rawValue ?? "AI Collaborator")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    if pythonBridge.isInitialized {
                        if selection == .issues {
                            pythonBridge.fetchIssues()
                        } else if selection == .pullRequests {
                            pythonBridge.fetchPRs()
                        }
                    } else {
                        pythonBridge.initialize()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Refresh data")
            }
            
            ToolbarItem(placement: .automatic) {
                Button {
                    settings.showLog.toggle()
                    settings.saveSettings()
                } label: {
                    Image(systemName: settings.showLog ? "chevron.down" : "chevron.up")
                }
                .help(settings.showLog ? "Hide logs" : "Show logs")
            }
            
            ToolbarItem(placement: .automatic) {
                if pythonBridge.isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                } else {
                    Circle()
                        .fill(pythonBridge.isInitialized ? Color.green : Color.red)
                        .frame(width: 10, height: 10)
                }
            }
        }
    }
}

// Dashboard View
struct DashboardView: View {
    @EnvironmentObject private var pythonBridge: PythonBridge
    @EnvironmentObject private var logManager: LogManager
    
    var body: some View {
        VStack(spacing: 20) {
            HStack(spacing: 20) {
                // Issues Stats
                StatusCard(
                    title: "Issues",
                    count: pythonBridge.issues.count,
                    icon: "exclamationmark.circle",
                    color: .blue
                ) {
                    pythonBridge.fetchIssues()
                }
                
                // PRs Stats
                StatusCard(
                    title: "Pull Requests",
                    count: pythonBridge.pullRequests.count,
                    icon: "arrow.triangle.pull",
                    color: .purple
                ) {
                    pythonBridge.fetchPRs()
                }
            }
            .padding()
            
            // Recent Activity Section
            VStack(alignment: .leading) {
                Text("Recent Activity")
                    .font(.headline)
                    .padding(.horizontal)
                
                List {
                    if pythonBridge.issues.isEmpty && pythonBridge.pullRequests.isEmpty {
                        ContentUnavailableView {
                            Label("No Recent Activity", systemImage: "tray")
                        } description: {
                            Text("Fetch issues and pull requests to see recent activity")
                        } actions: {
                            Button("Fetch Issues") {
                                pythonBridge.fetchIssues()
                            }
                            .buttonStyle(.borderedProminent)
                            
                            Button("Fetch PRs") {
                                pythonBridge.fetchPRs()
                            }
                            .buttonStyle(.bordered)
                        }
                    } else {
                        // Issues section
                        if !pythonBridge.issues.isEmpty {
                            Section("Recent Issues") {
                                ForEach(pythonBridge.issues.prefix(3)) { issue in
                                    HStack {
                                        Text("#\(issue.number)")
                                            .foregroundColor(.secondary)
                                        Text(issue.title)
                                            .lineLimit(1)
                                        Spacer()
                                        Text(issue.updatedAt)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                        
                        // PRs section
                        if !pythonBridge.pullRequests.isEmpty {
                            Section("Recent Pull Requests") {
                                ForEach(pythonBridge.pullRequests.prefix(3)) { pr in
                                    HStack {
                                        Text("#\(pr.number)")
                                            .foregroundColor(.secondary)
                                        Text(pr.title)
                                            .lineLimit(1)
                                        Spacer()
                                        Text(pr.updatedAt)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding()
    }
}

// Status Card
struct StatusCard: View {
    let title: String
    let count: Int
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        VStack {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("\(count)")
                        .font(.system(size: 36, weight: .bold))
                }
                
                Spacer()
                
                Image(systemName: icon)
                    .font(.system(size: 36))
                    .foregroundColor(color)
            }
            
            Divider()
                .padding(.vertical, 8)
            
            Button("Refresh") {
                action()
            }
            .buttonStyle(.plain)
            .font(.caption)
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding()
        .background(Color(.textBackgroundColor).opacity(0.5))
        .cornerRadius(12)
        .frame(maxWidth: .infinity)
    }
}

// Initialization View
struct InitializingView: View {
    @Binding var isInitializing: Bool
    @EnvironmentObject var pythonBridge: PythonBridge
    @EnvironmentObject var logManager: LogManager
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "desktopcomputer.and.arrow.down")
                .font(.system(size: 64))
                .foregroundColor(.blue)
            
            Text("Initializing AI Collaborator")
                .font(.title)
            
            if !pythonBridge.isInitialized {
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(1.5)
                    .padding()
                
                Text(pythonBridge.statusMessage)
                    .foregroundColor(.secondary)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.green)
                
                Text("Initialization Complete")
                    .foregroundColor(.secondary)
                
                Button("Continue") {
                    isInitializing = false
                }
                .buttonStyle(.borderedProminent)
                .padding(.top)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
}
