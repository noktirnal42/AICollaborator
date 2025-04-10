import SwiftUI

struct LogView: View {
    @EnvironmentObject private var logManager: LogManager
    @State private var selectedLogLevel: LogLevel = .all
    @State private var searchText: String = ""
    @State private var showSearch: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Logs")
                    .font(.headline)
                    .padding(.leading)
                
                Spacer()
                
                if showSearch {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        
                        TextField("Search logs", text: $searchText)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 200)
                        
                        Button {
                            searchText = ""
                            showSearch = false
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }
                
                Button {
                    withAnimation {
                        showSearch.toggle()
                        if !showSearch {
                            searchText = ""
                        }
                    }
                } label: {
                    Image(systemName: "magnifyingglass")
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 4)
                
                Menu {
                    ForEach(LogLevel.allCases, id: \.self) { level in
                        Button(action: {
                            selectedLogLevel = level
                            logManager.filter = level
                        }) {
                            HStack {
                                Image(systemName: level.icon)
                                Text(level.rawValue.capitalized)
                                if level == selectedLogLevel {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                    
                    Divider()
                    
                    Button(action: {
                        logManager.clearLogs()
                    }) {
                        Label("Clear Logs", systemImage: "trash")
                    }
                    
                    Button(action: {
                        if let url = logManager.exportLogs() {
                            NSWorkspace.shared.open(url)
                        }
                    }) {
                        Label("Export Logs", systemImage: "square.and.arrow.up")
                    }
                } label: {
                    HStack {
                        Image(systemName: selectedLogLevel.icon)
                        Text(selectedLogLevel.rawValue.capitalized)
                        Image(systemName: "chevron.down")
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(6)
                }
                .padding(.trailing)
            }
            .padding(.vertical, 4)
            .background(Color(.windowBackgroundColor))
            
            Divider()
            
            if logManager.logs.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    
                    Text("No logs available")
                        .font(.title3)
                    
                    Text("Application logs will appear here")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    List {
                        ForEach(logManager.filteredLogs()) { entry in
                            LogEntryRow(entry: entry)
                                .id(entry.id)
                        }
                    }
                    .listStyle(.plain)
                    .onChange(of: logManager.logs.count) { newCount in
                        if let lastLog = logManager.logs.last {
                            proxy.scrollTo(lastLog.id, anchor: .bottom)
                        }
                    }
                }
            }
        }
        .onChange(of: searchText) { newValue in
            logManager.searchText = newValue
        }
    }
}

struct LogEntryRow: View {
    let entry: LogEntry
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: entry.level.icon)
                .foregroundColor(entry.level.color)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.formattedTimestamp)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(entry.message)
                    .font(.subheadline)
            }
        }
        .padding(.vertical, 4)
        .contextMenu {
            Button("Copy") {
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString("\(entry.formattedTimestamp) [\(entry.level.rawValue.uppercased())] \(entry.message)", forType: .string)
            }
        }
    }
}

#Preview {
    LogView()
        .environmentObject(LogManager())
}

