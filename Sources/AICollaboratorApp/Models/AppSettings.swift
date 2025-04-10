import Foundation
import SwiftUI

class AppSettings: ObservableObject {
    @Published var showLog: Bool = false
    @Published var autoRefreshEnabled: Bool = false
    @Published var refreshInterval: TimeInterval = 5 * 60 // 5 minutes
    @Published var repository: String = "noktirnal42/AudioBloomAI"
    @Published var pythonPath: String = "/usr/bin/python3"
    @Published var customOllamaModels: [String] = []
    
    @Published var primaryModel: String = "llama3.2:latest"
    @Published var secondaryModel: String = "deepseek-r1:8b"
    
    private let defaults = UserDefaults.standard
    
    init() {
        loadSettings()
    }
    
    func saveSettings() {
        defaults.set(showLog, forKey: "showLog")
        defaults.set(autoRefreshEnabled, forKey: "autoRefreshEnabled")
        defaults.set(refreshInterval, forKey: "refreshInterval")
        defaults.set(repository, forKey: "repository")
        defaults.set(pythonPath, forKey: "pythonPath")
        defaults.set(customOllamaModels, forKey: "customOllamaModels")
        defaults.set(primaryModel, forKey: "primaryModel")
        defaults.set(secondaryModel, forKey: "secondaryModel")
    }
    
    func loadSettings() {
        showLog = defaults.bool(forKey: "showLog")
        autoRefreshEnabled = defaults.bool(forKey: "autoRefreshEnabled")
        refreshInterval = defaults.double(forKey: "refreshInterval")
        
        if let repo = defaults.string(forKey: "repository") {
            repository = repo
        }
        
        if let pythonPathValue = defaults.string(forKey: "pythonPath") {
            pythonPath = pythonPathValue
        }
        
        if let models = defaults.stringArray(forKey: "customOllamaModels") {
            customOllamaModels = models
        }
        
        if let primary = defaults.string(forKey

import Foundation
import SwiftUI

class AppSettings: ObservableObject {
    @Published var showLog: Bool = false
    @Published var autoRefreshEnabled: Bool = false
    @Published var refreshInterval: TimeInterval = 5 * 60 // 5 minutes
    @Published var repository: String = "noktirnal42/AudioBloomAI"
    @Published var pythonPath: String = "/usr/bin/python3"
    @Published var customOllamaModels: [String] = []
    
    @Published var primaryModel: String = "llama3.2:latest"
    @Published var secondaryModel: String = "deepseek-r1:8b"
    
    private let defaults = UserDefaults.standard
    
    init() {
        loadSettings()
    }
    
    func saveSettings() {
        defaults.set(showLog, forKey: "showLog")
        defaults.set(autoRefreshEnabled, forKey: "autoRefreshEnabled")
        defaults.set(refreshInterval, forKey: "refreshInterval")
        defaults.set(repository, forKey: "repository")
        defaults.set(pythonPath, forKey: "pythonPath")
        defaults.set(customOllamaModels, forKey: "customOllamaModels")
        defaults.set(primaryModel, forKey: "primaryModel")
        defaults.set(secondaryModel, forKey: "secondaryModel")
    }
    
    func loadSettings() {
        showLog = defaults.bool(forKey: "showLog")
        autoRefreshEnabled = defaults.bool(forKey: "autoRefreshEnabled")
        refreshInterval = defaults.double(forKey: "refreshInterval")
        
        if let repo = defaults.string(forKey: "repository") {
            repository = repo
        }
        
        if let pythonPathValue = defaults.string(forKey: "pythonPath") {
            pythonPath = pythonPathValue
        }
        
        if let models = defaults.stringArray(forKey: "customOllamaModels") {
            customOllamaModels = models
        }
        
        if let primary = defaults.string(forKey: "primaryModel") {
            primaryModel = primary
        }
        
        if let secondary = defaults.string(forKey: "secondaryModel") {
            secondaryModel = secondary
        }
    }
    
    func resetToDefaults() {
        showLog = false
        autoRefreshEnabled = false
        refreshInterval = 5 * 60
        repository = "noktirnal42/AudioBloomAI"
        pythonPath = "/usr/bin/python3"
        customOllamaModels = []
        primaryModel = "llama3.2:latest"
        secondaryModel = "deepseek-r1:8b"
        
        saveSettings()
    }
}

import Foundation
import SwiftUI

class AppSettings: ObservableObject {
    @Published var showLog: Bool = false
    @Published var autoRefreshEnabled: Bool = false
    @Published var refreshInterval: TimeInterval = 5 * 60 // 5 minutes
    @Published var repository: String = "noktirnal42/AudioBloomAI"
    @Published var pythonPath: String = "/usr/bin/python3"
    @Published var customOllamaModels: [String] = []
    
    @Published var primaryModel: String = "llama3.2:latest"
    @Published var secondaryModel: String = "deepseek-r1:8b"
    
    private let defaults = UserDefaults.standard
    
    init() {
        loadSettings()
    }
    
    func saveSettings() {
        defaults.set(showLog, forKey: "showLog")
        defaults.set(autoRefreshEnabled, forKey: "autoRefreshEnabled")
        defaults.set(refreshInterval, forKey: "refreshInterval")
        defaults.set(repository, forKey: "repository")
        defaults.set(pythonPath, forKey: "pythonPath")
        defaults.set(customOllamaModels, forKey: "customOllamaModels")
        defaults.set(primaryModel, forKey: "primaryModel")
        defaults.set(secondaryModel, forKey: "secondaryModel")
    }
    
    func loadSettings() {
        showLog = defaults.bool(forKey: "showLog")
        autoRefreshEnabled = defaults.bool(forKey: "autoRefreshEnabled")
        refreshInterval = defaults.double(forKey: "refreshInterval")
        
        if let repo = defaults.string(forKey: "repository") {
            repository = repo
        }
        
        if let pythonPathValue = defaults.string(forKey: "pythonPath") {
            pythonPath = pythonPathValue
        }
        
        if let models = defaults.stringArray(forKey: "customOllamaModels") {
            customOllamaModels = models
        }
        
        if let primary = defaults.string(forKey: "primaryModel") {
            primaryModel = primary
        }
        
        if let secondary = defaults.string(forKey: "secondaryModel") {
            secondaryModel = secondary
        }
    }
    
    func resetToDefaults() {
        showLog = false
        autoRefreshEnabled = false
        refreshInterval = 5 * 60
        repository = "noktirnal42/AudioBloomAI"
        pythonPath = "/usr/bin/python3"
        customOllamaModels = []
        primaryModel = "llama3.2:latest"
        secondaryModel = "deepseek-r1:8b"
        
        saveSettings()
    }
}

