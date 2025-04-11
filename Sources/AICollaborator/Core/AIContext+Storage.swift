import Foundation

/// Extension providing storage methods for AIContext.
@available(macOS 15.0, *)
extension AIContext {
    
    // MARK: - Storage Methods
    
    /// Store a value in the context.
    ///
    /// This method stores a value with the given key. If a value already exists
    /// for the key, a `valueAlreadyExists` error is thrown.
    ///
    /// - Parameters:
    ///   - key: The key to store the value under.
    ///   - value: The value to store.
    ///
    /// - Returns: `true` if the value was stored successfully.
    /// - Throws: `AIError.valueAlreadyExists` if a value already exists for the key.
    @discardableResult
    public func store<T>(_ key: String, value: T) async throws -> Bool {
        guard storage[key] == nil else {
            throw AIError.valueAlreadyExists
        }
        
        let entry = ContextEntry(
            value: value,
            type: T.self,
            timestamp: Date(),
            version: 1
        )
        
        storage[key] = entry
        notifyDelegates(key: key, oldValue: nil, newValue: value)
        
        return true
    }
    
    /// Retrieve a value from the context.
    ///
    /// This method retrieves a value for the given key. If the value doesn't exist,
    /// a `valueNotFound` error is thrown.
    ///
    /// - Parameter key: The key to retrieve the value for.
    /// - Returns: The stored value.
    /// - Throws: `AIError.valueNotFound` if no value exists for the key.
    public func retrieve(_ key: String) async throws -> Any {
        guard let entry = storage[key] else {
            throw AIError.valueNotFound
        }
        
        return entry.value
    }
    
    /// Retrieve a value with type safety.
    ///
    /// This method retrieves a value for the given key and attempts to cast it to the specified type.
    /// If the value doesn't exist or can't be cast to the specified type, an error is thrown.
    ///
    /// - Parameters:
    ///   - key: The key to retrieve the value for.
    ///   - type: The type to cast the value to.
    ///
    /// - Returns: The stored value cast to the specified type.
    /// - Throws: `AIError.valueNotFound` if no value exists for the key.
    ///           `AIError.typeMismatch` if the value can't be cast to the specified type.
    public func retrieve<T>(_ key: String, as type: T.Type) async throws -> T {
        guard let entry = storage[key] else {
            throw AIError.valueNotFound
        }
        
        guard let value = entry.value as? T else {
            throw AIError.typeMismatch
        }
        
        return value
    }
    
    /// Update an existing value in the context.
    ///
    /// This method updates a value for the given key. If the value doesn't exist,
    /// a `valueNotFound` error is thrown.
    ///
    /// - Parameters:
    ///   - key: The key to update the value for.
    ///   - value: The new value.
    ///
    /// - Returns: `true` if the value was updated successfully.
    /// - Throws: `AIError.valueNotFound` if no value exists for the key.
    ///           `AIError.typeMismatch` if the new value has a different type than the stored value.
    @discardableResult
    public func update<T>(_ key: String, value: T) async throws -> Bool {
        guard let existingEntry = storage[key] else {
            throw AIError.valueNotFound
        }
        
        guard type(of: existingEntry.value) == T.self else {
            throw AIError.typeMismatch
        }
        
        let oldValue = existingEntry.value
        
        let entry = ContextEntry(
            value: value,
            type: T.self,
            timestamp: Date(),
            version: existingEntry.version + 1
        )
        
        storage[key] = entry
        notifyDelegates(key: key, oldValue: oldValue, newValue: value)
        
        return true
    }
    
    /// Store or update a value in the context.
    ///
    /// This method stores a value if it doesn't exist, or updates it if it does exist.
    ///
    /// - Parameters:
    ///   - key: The key to store or update the value for.
    ///   - value: The value to store or update.
    ///
    /// - Returns: `true` if the value was stored or updated successfully.
    @discardableResult
    public func storeOrUpdate<T>(_ key: String, value: T) async -> Bool {
        do {
            if storage[key] != nil {
                return try await update(key, value: value)
            } else {
                return try await store(key, value: value)
            }
        } catch {
            return false
        }
    }
    
    /// Remove a value from the context.
    ///
    /// This method removes a value for the given key. If the value doesn't exist,
    /// a `valueNotFound` error is thrown.
    ///
    /// - Parameter key: The key to remove the value for.
    /// - Returns: The removed value.
    /// - Throws: `AIError.valueNotFound` if no value exists for the key.
    @discardableResult
    public func remove(_ key: String) async throws -> Any {
        guard let entry = storage[key] else {
            throw AIError.valueNotFound
        }
        
        let value = entry.value
        storage.removeValue(forKey: key)
        notifyDelegates(key: key, oldValue: value, newValue: NSNull())
        
        return value
    }
    
    /// Check if a value exists for the given key.
    ///
    /// - Parameter key: The key to check.
    /// - Returns: `true` if a value exists for the key, `false` otherwise.
    public func contains(_ key: String) async -> Bool {
        return storage[key] != nil
    }
    
    /// Get metadata for a stored value.
    ///
    /// This method retrieves metadata for a value, including its type, timestamp, and version.
    ///
    /// - Parameter key: The key to get metadata for.
    /// - Returns: A tuple containing the type, timestamp, and version.
    /// - Throws: `AIError.valueNotFound` if no value exists for the key.
    public func getMetadata(_ key: String) async throws -> (type: Any.Type, timestamp: Date, version: Int) {
        guard let entry = storage[key] else {
            throw AIError.valueNotFound
        }
        
        return (entry.type, entry.timestamp, entry.version)
    }
    
    /// Get all available keys in the context.
    ///
    /// - Returns: Array of all keys in the context.
    public func availableKeys() async -> [String] {
        return Array(storage.keys)
    }
    
    /// Clear all values from the context.
    ///
    /// - Parameter keys: Optional array of keys to clear. If `nil`, all values are cleared.
    /// - Returns: `true` if the values were cleared successfully.
    @discardableResult
    public func clear(keys: [String]? = nil) async -> Bool {
        if let keys = keys {
            for key in keys {
                storage.removeValue(forKey: key)
            }
        } else {
            storage.removeAll()
        }
        
        return true
    }
}
