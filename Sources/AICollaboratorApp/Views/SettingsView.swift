#if canImport(SwiftUI)
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings

    @State private var repository: String = ""
    @State private var pythonPath: String = ""
    @State private var primaryModel: String = ""
    @State private var secondaryModel: String = ""
    @State private var refreshInterval: Double = 5 * 60
    @State private var autoRefresh: Bool = false
    
    var body: some View {
        Form {
            Section(header: Text("GitHub Repository")) {
                TextField("Repository (owner/repo)", text: $repository)
                    .textFieldStyle(.roundedBorder)

                Text("Example: noktirnal42/AIcollaborator")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Button("Apply Repository") {
                    settings.repository = repository
                    settings.saveSettings()
                }
                .buttonStyle(.borderedProminent)
                .disabled(repository == settings.repository)
            }

            Section(header: Text("Python Configuration")) {
                TextField("Python Path", text: $pythonPath)
                    .textFieldStyle(.roundedBorder)

                Button("Apply Python Path") {
                    settings.pythonPath = pythonPath
                    settings.saveSettings()
                }
                .buttonStyle(.borderedProminent)
                .disabled(pythonPath == settings.pythonPath)
            }

            Section(header: Text("AI Models")) {
                TextField("Primary Model", text: $primaryModel)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: primaryModel) { newValue in
                        settings.primaryModel = newValue
                        settings.saveSettings()
                    }

                TextField("Secondary Model", text: $secondaryModel)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: secondaryModel) { newValue in
                        settings.secondaryModel = newValue
                        settings.saveSettings()
                    }
            }

            Section(header: Text("Auto Refresh")) {
                Toggle("Enable Auto Refresh", isOn: $autoRefresh)
                    .onChange(of: autoRefresh) { newValue in
                        settings.autoRefreshEnabled = newValue
                        settings.saveSettings()
                    }

                if autoRefresh {
                    HStack {
                        Text("Interval: \(Int(refreshInterval / 60)) minutes")
                        Spacer()
                        Slider(value: $refreshInterval, in: 60...1800, step: 60)
                            .frame(width: 200)
                            .onChange(of: refreshInterval) { newValue in
                                settings.refreshInterval = newValue
                                settings.saveSettings()
                            }
                    }
                }
            }

            Section(header: Text("Application")) {
                Toggle("Show logs by default", isOn: Binding(
                    get: { settings.showLog },
                    set: {
                        settings.showLog = $0
                        settings.saveSettings()
                    }
                ))
            }

            Section {
                Button("Reset to Defaults") {
                    settings.resetToDefaults()
                    loadSettings()
                }
                .foregroundColor(.red)
            }
        }
        .padding()
        .frame(width: 520, height: 450)
        .onAppear {
            loadSettings()
        }
    }
    
    // MARK: - Helper Methods

    private func loadSettings() {
        repository = settings.repository
        pythonPath = settings.pythonPath
        primaryModel = settings.primaryModel
        secondaryModel = settings.secondaryModel
        refreshInterval = settings.refreshInterval
        autoRefresh = settings.autoRefreshEnabled
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppSettings())
}
#endif
