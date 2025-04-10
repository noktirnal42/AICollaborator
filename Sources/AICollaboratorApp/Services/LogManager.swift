import Foundation
import SwiftUI

/// Logging level for the application
enum LogLevel: String, Codable, CaseIterable {
    case debug
    case info
    case warning
    case error
    case all
    
    /// Color associated with each log level
    var color: Color {
        switch self {
        case .debug:
            return .gray
        case .info:
            return .blue
        case .warning:
            return .orange
        case .error:
            return .red
        case .all:
            return .primary
        }
    }
    
    /// Icon representing each log level
    var icon: String {
        switch self {
        case .debug:
            return "ladybug"
        case .info:
            return "info.circle"
        case .warning:
            return "exclamationmark.triangle"
        case .error:
            return "xmark.octagon"
        case .all:
            return "list.bullet"
        }
    }
}

/// Represents a single log entry
struct LogEntry: Identifiable, Codable, Equatable {
    let id: UUID
    let timestamp: Date
    let message: String
    let level: LogLevel
    
    init(timestamp: Date, message: String, level: LogLevel) {
        self.id = UUID()
        self.timestamp = timestamp
        self.message = message
        self.level = level
    }
    
    /// Formatted timestamp for display
    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: timestamp)
    }
}

/// Manages application logs with persistence and filtering
class LogManager: ObservableObject {
    @Published var logs: [LogEntry] = []
    @Published var filter: LogLevel = .all
    @Published var searchText: String = ""
    
    private let fileManager = FileManager.default
    private let logFileName = "ai_collaborator.log"
    private let maxLogEntries = 1000
    
    private var logFileURL: URL {
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsDirectory.appendingPathComponent(logFileName)
    }
    
    init() {
        loadLogs()
    }
    
    /// Add a new log entry
    func log(_ message: String, level: LogLevel = .info) {
        let timestamp = Date()
        let entry = LogEntry(timestamp: timestamp, message: message, level: level)
        
        DispatchQueue.main.async {
            self.logs.append(entry)
            // Trim logs if they exceed maximum
            if self.logs.count > self.maxLogEntries {
                self.logs = Array(self.logs.suffix(self.maxLogEntries))
            }
        }
        
        // Write to file
        writeLogToFile(entry)
    }
    
    /// Clear all logs
    func clearLogs() {
        DispatchQueue.main.async {
            self.logs.removeAll()
        }
        
        // Delete log file
        try? fileManager.removeItem(at: logFileURL)
    }
    
    /// Get filtered logs based on level and search text
    func filteredLogs() -> [LogEntry] {
        var filteredByLevel: [LogEntry]
        
        if filter == .all {
            filteredByLevel = logs
        } else {
            filteredByLevel = logs.filter { $0.level == filter }
        }
        
        // Apply search filter if search text is not empty
        if !searchText.isEmpty {
            return filteredByLevel.filter { 
                $0.message.lowercased().contains(searchText.lowercased()) 
            }
        }
        
        return filteredByLevel
    }
    
    /// Export logs to a file
    func exportLogs() -> URL? {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let logData = try encoder.encode(logs)
            
            let exportURL = logFileURL.deletingLastPathComponent().appendingPathComponent("exported_logs.json")
            try logData.write(to: exportURL)
            return exportURL
        } catch {
            log("Failed to export logs: \(error.localizedDescription)", level: .error)
            return nil
        }
    }
    
    // MARK: - Private Methods
    
    /// Load logs from persistent storage
    private func loadLogs() {
        guard fileManager.fileExists(atPath: logFileURL.path) else {
            return
        }
        
        do {
            let logData = try Data(contentsOf: logFileURL)
            let decoder = JSONDecoder()
            let loadedLogs = try decoder.decode([LogEntry].self, from: logData)
            
            DispatchQueue.main.async {
                self.logs = loadedLogs
            }
        } catch {
            print("Error loading logs: \(error)")
        }
    }
    
    /// Write a log entry to the log file
    private func writeLogToFile(_ entry: LogEntry) {
        do {
            var allLogs = logs
            if !allLogs.contains(where: { $0.id == entry.id }) {
                allLogs.append(entry)
            }
            
            let encoder = JSONEncoder()
            let logData = try encoder.encode(allLogs)
            try logData.write(to: logFileURL)
        } catch {
            print("Error writing logs to file: \(error)")
        }
    }
}
