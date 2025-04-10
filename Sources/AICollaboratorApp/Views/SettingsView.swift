import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var pythonBridge: PythonBridge
    @EnvironmentObject private var logManager: LogManager
    
    @State private var repository: String
    @State private var pythonPath: String
    @State private var primaryModel: String
    @State private var secondaryModel: String
    @State private var refreshInterval: Double
    @State private var autoRefresh: Bool
    @State private var availableModels: [String] = []
    
    init() {
        // Initialize state with empty values - they will be populated from the settings
        _repository = State(initialValue: "")
        _pythonPath = State(initialValue: "")
        _primaryModel = State(initialValue: "")
        _secondaryModel = State(initialValue: "")
        _refreshInterval = State(initialValue: 5 * 60)
        _autoRefresh = State(initialValue: false)
    }
    
    var body: some View {
        TabView {
            // General Settings
            generalSettingsView
                .tabItem {
                    Label("General", systemImage: "gear")
                }
                .tag(0)
            
            // GitHub Settings
            githubSettingsView
                .tabItem {
                    Label("GitHub", systemImage: "network")
                }
                .tag(1)
            
            // AI Models
            aiModelsSettingsView
                .tabItem {
                    Label("AI Models", systemImage: "brain")
                }
                .tag(2)
            
            // Logging
            loggingSettingsView
                .tabItem {
                    Label("Logging", systemImage: "doc.text")
                }
                .tag(3)
        }
        .padding(20)
        .frame(width: 550, height: 450)
        .onAppear {
            // Load settings into local state
            loadSettings()
            
            // Fetch available models from Ollama
            fetchAvailableModels()
        }
    }
    
    // General Settings View
    private var generalSettingsView: some View {
        Form {
            Section(header: Text("Application Settings")) {
                Toggle("Show logs by default", isOn: Binding(
                    get: { settings.showLog },
                    set: {
                        settings.showLog = $0
                        settings.saveSettings()
                    }
                ))
                
                Toggle("Resume last session on startup", isOn: Binding(
                    get: { settings.resumeLastSession },
                    set: {
                        settings.resumeLastSession = $0
                        settings.saveSettings()
                    }
                ))
            }
            
            Section(header: Text("Python Configuration")) {
                HStack {
                    TextField("Python Path", text: $pythonPath)
                        .textFieldStyle(.roundedBorder)
                    
                    Button("Browse") {
                        selectPythonPath()
                    }
                    .buttonStyle(.bordered)
                }
                
                Text("Current path: \(pythonPath)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Button("Apply Python Path") {
                    settings.pythonPath = pythonPath
                    settings.saveSettings()
                    pythonBridge.initialize()
                }
                .buttonStyle(.borderedProminent)
                .disabled(pythonPath == settings.pythonPath)
            }
        }
    }
    
    // GitHub Settings View
    private var githubSettingsView: some View {
        Form {
            Section(header: Text("Repository Settings")) {
                TextField("Repository (owner/repo)", text: $repository)
                    .textFieldStyle(.roundedBorder)
                
                Text("Example: noktirnal42/AudioBloomAI")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Button("Apply Repository") {
                    settings.repository = repository
                    settings.saveSettings()
                    pythonBridge.repo = repository
                    
                    // Log the change
                    logManager.log("Repository changed to \(repository)", level: .info)
                }
                .buttonStyle(.borderedProminent)
                .disabled(repository == settings.repository)
            }
            
            Section(header: Text("Auto-Refresh Settings")) {
                Toggle("Enable automatic refresh", isOn: $autoRefresh)
                    .onChange(of: autoRefresh) { newValue in
                        settings.autoRefreshEnabled = newValue
                        settings.saveSettings()
                    }
                
                if autoRefresh {
                    VStack(alignment: .leading) {
                        Text("Refresh interval: \(Int(refreshInterval / 60)) minutes")
                        
                        Slider(value: $refreshInterval, in: 60...1800, step: 60)
                            .onChange(of: refreshInterval) { newValue in
                                settings.refreshInterval = newValue
                                settings.saveSettings()
                            }
                    }
                }
            }
        }
    }
    
    // AI Models Settings View
    private var aiModelsSettingsView: some View {
        Form {
            Section(header: Text("Ollama Models")) {
                // Primary model selection
                Picker("Primary Model", selection: $primaryModel) {
                    ForEach(availableModels, id: \.self) { model in
                        Text(model).tag(model)
                    }
                }
                .onChange(of: primaryModel) { newValue in
                    settings.primaryModel = newValue
                    settings.saveSettings()
                    
                    // Log the change
                    logManager.log("Primary model changed to \(newValue)", level: .info)
                }
                
                // Secondary model selection
                Picker("Secondary Model", selection: $secondaryModel) {
                    ForEach(availableModels, id: \.self) { model in
                        Text(model).tag(model)
                    }
                }
                .onChange(of: secondaryModel) { newValue in
                    settings.secondaryModel = newValue
                    settings.saveSettings()
                    
                    // Log the change
                    logManager.log("Secondary model changed to \(newValue)", level: .info)
                }
                
                Button("Refresh Models") {
                    fetchAvailableModels()
                }
                .buttonStyle(.bordered)
            }
            
            Section(header: Text("Custom Models")) {
                if !settings.customOllamaModels.isEmpty {
                    ForEach(settings.customOllamaModels, id: \.self) { model in
                        HStack {
                            Text(model)
                            
                            Spacer()
                            
                            Button {
                                removeCustomModel(model)
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } else {
                    Text("No custom models added")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    TextField("Add custom model", text: Binding(
                        get: { addCustomModelText },
                        set: { addCustomModelText = $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                    
                    Button("Add") {
                        addCustomModel()
                    }
                    .buttonStyle(.bordered)
                    .disabled(addCustomModelText.isEmpty)
                }
            }
        }
    }
    
    // Logging Settings View
    private var loggingSettingsView: some View {
        Form {
            Section(header: Text("Log Management")) {
                HStack {
                    Text("Current logs: \(logManager.logs.count)")
                    
                    Spacer()
                    
                    Button("Clear Logs") {
                        logManager.clearLogs()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Export Logs") {
                        if let url = logManager.exportLogs() {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .buttonStyle(.bordered)
                }
                
                Toggle("Show log panel by default", isOn: Binding(
                    get: { settings.showLog },
                    set: {
                        settings.showLog = $0
                        settings.saveSettings()
                    }
                ))
            }
            
            Section(header: Text("Debug Settings")) {
                Toggle("Enable debug logging", isOn: Binding(
                    get: { settings.enableDebugLogging },
                    set: {
                        settings.enableDebugLogging = $0
                        settings.saveSettings()
                        
                        // Log the change
                        let level: LogLevel = $0 ? .debug : .info
                        logManager.log("Debug logging \($0 ? "enabled" : "disabled")", level: level)
                    }
                ))
                
                if settings.enableDebugLogging {
                    Text("Debug logs will be displayed in the log panel")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private var addCustomModelText: String = ""
    
    private func loadSettings() {
        repository = settings.repository
        pythonPath = settings.pythonPath
        primaryModel = settings.primaryModel
        secondaryModel = settings.secondaryModel
        refreshInterval = settings.refreshInterval
        autoRefresh = settings.autoRefreshEnabled
    }
    
    private func selectPythonPath() {
        let panel =

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @State private var repository: String
    @State private var pythonPath: String
    @State private var primaryModel: String
    @State private var secondaryModel: String
    @State private var refreshInterval: Double
    @State private var autoRefresh: Bool
    
    init() {
        // Initialize state with empty values - they will be populated from the settings
        _repository = State(initialValue: "")
        _pythonPath = State(initialValue: "")
        _primaryModel = State(initialValue: "")
        _secondaryModel = State(initialValue: "")
        _refreshInterval = State(initialValue: 5 * 60)
        _autoRefresh = State(initialValue: false)
    }
    
    var body: some View {
        Form {
            Section(header: Text("GitHub Repository")) {
                TextField("Repository", text: $repository)
                    .onChange(of: repository) { _ in
                        settings.repository = repository
                        settings.saveSettings()
                    }
            }
            
            Section(header: Text("Python Configuration")) {
                TextField("Python Path", text: $pythonPath)
                    .onChange(of: pythonPath) { _ in
                        settings.pythonPath = pythonPath
                        settings.saveSettings()
                    }
            }
            
            Section(header: Text("AI Models")) {
                TextField("Primary Model", text: $primaryModel)
                    .onChange(of: primaryModel) { _ in
                        settings.primaryModel = primaryModel
                        settings.saveSettings()
                    }
                
                TextField("Secondary Model", text: $secondaryModel)
                    .onChange(of: secondaryModel) { _ in
                        settings.secondaryModel = secondaryModel
                        settings.saveSettings()
                    }
            }
            
            Section(header: Text("Auto Refresh")) {
                Toggle("Enable Auto Refresh", isOn: $autoRefresh)
                    .onChange(of: autoRefresh) { _ in
                        settings.autoRefreshEnabled = autoRefresh
                        settings.saveSettings()
                    }
                
                if autoRefresh {
                    HStack {
                        Text("Interval: \(Int(refreshInterval / 60)) minutes")
                        Spacer()
                        Slider(value: $refreshInterval, in: 60...1800, step: 60)
                            .frame(width: 200)
                            .onChange(of: refreshInterval) { _ in
                                settings.refreshInterval = refreshInterval
                                settings.saveSettings()
                            }
                    }
                }
            }
            
            Section {
                Button("Reset to Defaults") {
                    settings.resetToDefaults()
                    
                    // Update local state with new settings
                    repository = settings.repository
                    pythonPath = settings.pythonPath
                    primaryModel = settings.primaryModel
                    secondaryModel = settings.secondaryModel
                    refreshInterval = settings.refreshInterval
                    autoRefresh = settings.autoRefreshEnabled
                }
                .foregroundColor(.red)
            }
        }
        .padding()
        .frame(width: 500, height: 400)
        .onAppear {
            // Load settings into local state
            repository = settings.repository
            pythonPath = settings.pythonPath
            primaryModel = settings.primaryModel
            secondaryModel = settings.secondaryModel
            refreshInterval = settings.refreshInterval
            autoRefresh = settings.autoRefreshEnabled
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppSettings())
}

