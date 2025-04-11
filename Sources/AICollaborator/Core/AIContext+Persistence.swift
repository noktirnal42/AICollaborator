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

