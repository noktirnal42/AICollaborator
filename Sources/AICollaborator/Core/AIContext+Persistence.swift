import Foundation

/// Extension providing persistence capabilities for AIContext.
@available(macOS 15.0, *)
extension AIContext {
    /// Current state of the context.
    public struct ContextState: Codable {
        /// The conversation history.
        public let history: [AIMessage]
        
        /// Timestamp when the state was created.
        public let timestamp: Date
        
        /// Version of the state format.
        public let version: Int = 1
        
        /// Serialized storage data.
        public let storageData: [String: [String: Codable]]
    }
    
    /// Save the current state of the context.
    ///
    /// - Parameter prettyPrinted: Whether to format the output for readability.
    /// - Returns: The encoded state data.
    /// - Throws: Error if encoding fails.
    public func saveState(prettyPrinted: Bool = false) async throws -> Data {
        // Transform storage into codable format
        var serializableStorage: [String: [String: Codable]] = [:]
        
        for (key, entry) in storage {
            if let value = entry.value as? Codable {
                serializableStorage[key] = [
                    "value": value,
                    "timestamp": entry.timestamp as Codable,
                    "version": entry.version as Codable
                ]
            }
        }
        
        let state = ContextState(
            history: conversationHistory,
            timestamp: Date(),
            storageData: serializableStorage
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        if prettyPrinted {
            encoder.outputFormatting = .prettyPrinted
        }
        
        return try encoder.encode(state)
    }
    
    /// Restore the context state from saved data.
    ///
    /// - Parameter data: The encoded state data.
    /// - Returns: `true` if the state was restored successfully.
    /// - Throws: Error if decoding fails.
    @discardableResult
    public func restoreState(_ data: Data) async throws -> Bool {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let state = try decoder.decode(ContextState.self, from: data)
        
        // Restore the conversation history
        conversationHistory = state.history
        
        // Restore storage data (partial - will only restore codable values)
        for (key, entryData) in state.storageData {
            if let value = entryData["value"] as? Codable,
               let timestamp = entryData["timestamp"] as? Date,
               let version = entryData["version"] as? Int {
                
                storage[key] = ContextEntry(
                    value: value,
                    type: type(of: value),
                    timestamp: timestamp,
                    version: version
                )
            }
        }
        
        return true
    }
    
    /// Setup auto-persistence of context state.
    ///
    /// - Parameters:
    ///   - interval: How often to save the state, in seconds.
    ///   - handler: Closure to handle the saved state data.
    ///
    /// - Returns: A task that can be cancelled to stop auto-persistence.
    public func setupAutoPersistence(
        interval: TimeInterval = 300, // 5 minutes
        handler: @escaping (Result<Data, Error>) -> Void
    ) -> Task<Void, Never> {
        return Task {
            while !Task.isCancelled {
                do {
                    try await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                    let stateData = try await saveState()
                    handler(.success(stateData))
                } catch {
                    handler(.failure(error))
                }
            }
        }
    }
    
    /// Save the context state to a file.
    ///
    /// - Parameters:
    ///   - url: The URL to save the state to.
    ///   - prettyPrinted: Whether to format the output for readability.
    ///
    /// - Returns: `true` if the state was saved successfully.
    /// - Throws: Error if encoding or writing fails.
    @discardableResult
    public func saveStateToFile(url: URL, prettyPrinted: Bool = false) async throws -> Bool {
        let data = try await saveState(prettyPrinted: prettyPrinted)
        try data.write(to: url)
        return true
    }
    
    /// Restore the context state from a file.
    ///
    /// - Parameter url: The URL to load the state from.
    /// - Returns: `true` if the state was restored successfully.
    /// - Throws: Error if reading or decoding fails.
    @discardableResult
    public func restoreStateFromFile(_ url: URL) async throws -> Bool {
        let data = try Data(contentsOf: url)
        return try await restoreState(data)
    }
}

import Foundation

/// Extension providing persistence methods for AIContext.
@available(macOS 15.0, *)
extension AIContext {
    
    // MARK: - Serialization and Persistence
    
    /// Serialize the context to a dictionary for persistence.
    ///
    /// - Returns: A dictionary representation of the context.
    public func serialize() async -> [String: Any] {
        var result: [String: Any] = [
            "sessionId": sessionId.uuidString,
            "timestamp": Date()
        ]
        
        var serializableStorage: [String: [String: Any]] = [:]
        
        for (key, entry) in storage {
            if let value = entry.value as? Codable {
                do {
                    let data = try JSONEncoder().encode(value)
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        serializableStorage[key] = [
                            "value": json,
                            "type": String(describing: entry.type),
                            "timestamp": entry.timestamp,
                            "version": entry.version
                        ]
                    }
                } catch {
                    // Skip non-serializable values
                }
            }
        }
        
        result["storage"] = serializableStorage
        
        do {
            let historyData = try JSONEncoder().encode(conversationHistory)
            result["conversationHistory"] = historyData
        } catch {
            // Skip conversation history if it can't be serialized
        }
        
        return result
    }
    
    /// Load context from a serialized dictionary.
    ///
    /// - Parameter dictionary: The serialized context.
    /// - Returns: `true` if the context was loaded successfully.
    @discardableResult
    public func load(from dictionary: [String: Any]) async -> Bool {
        // Clear existing data
        storage.removeAll()
        conversationHistory.removeAll()
        
        // Load serialized storage
        if let serializableStorage = dictionary["storage"] as? [String: [String: Any]] {
            for (key, entryDict) in serializableStorage {
                if let json = entryDict["value"] as? [String: Any],
                   let typeString = entryDict["type"] as? String,
                   let timestamp = entryDict["timestamp"] as? Date,
                   let version = entryDict["version"] as? Int {
                    
                    // This is a simplified version. In a real implementation,
                    // you would need to handle deserialization based on the type.
                    storage[key] = ContextEntry(
                        value: json,
                        type: NSObject.self,
                        timestamp: timestamp,
                        version: version
                    )
                }
            }
        }
        
        // Load conversation history
        if let historyData = dictionary["conversationHistory"] as? Data {
            do {
                conversationHistory = try JSONDecoder().decode([AIMessage].self, from: historyData)
            } catch {
                // Handle error
            }
        }
        
        return true
    }
}

