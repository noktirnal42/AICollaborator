import Foundation

/// Error types for the AICollaborator framework.
///
/// `AIError` defines the various error types that can occur within the AICollaborator framework.
/// Each error type includes a description and optional recovery suggestions.
///
/// ## Example Usage
///
/// ```swift
/// do {
///     try await context.store("key", value: "value")
/// } catch AIError.valueAlreadyExists {
///     print("Value already exists")
/// } catch {
///     print("An error occurred: \(error.localizedDescription)")
/// }
/// ```
@available(macOS 15.0, *)
public enum AIError: Error, CustomStringConvertible, LocalizedError {
    /// A value already exists for the given key.
    case valueAlreadyExists
    
    /// A value was not found for the given key.
    case valueNotFound
    
    /// The type of a value doesn't match the expected type.
    case typeMismatch
    
    /// A task has invalid parameters.
    case invalidTaskParameters
    
    /// No suitable agent was found for a task.
    case noSuitableAgentFound
    
    /// A task execution timed out.
    case taskExecutionTimeout
    
    /// A task was canceled.
    case taskCanceled
    
    /// Authentication failed.
    case authenticationFailed
    
    /// A task does not support asynchronous execution.
    case taskDoesNotSupportAsyncExecution
    
    /// A required capability is missing.
    case missingCapability(AICapability)
    
    /// A specific model is required but not available.
    case modelNotAvailable(String)
    
    /// Context operations exceeded the maximum allowed.
    case contextOperationLimitExceeded
    
    /// An error occurred with an external service.
    case externalServiceError(String)
    
    /// A general error with a custom message.
    case general(String)
    
    /// Human-readable description of the error.
    public var description: String {
        switch self {
        case .valueAlreadyExists:
            return "Value already exists for the given key"
        case .valueNotFound:
            return "Value not found for the given key"
        case .typeMismatch:
            return "Type mismatch between stored and requested value"
        case .invalidTaskParameters:
            return "Invalid task parameters"
        case .noSuitableAgentFound:
            return "No suitable agent found for the task"
        case .taskExecutionTimeout:
            return "Task execution timed out"
        case .taskCanceled:
            return "Task was canceled"
        case .authenticationFailed:
            return "Authentication failed"
        case .taskDoesNotSupportAsyncExecution:
            return "Task does not support asynchronous execution"
        case .missingCapability(let capability):
            return "Missing required capability: \(capability)"
        case .modelNotAvailable(let model):
            return "Required model not available: \(model)"
        case .contextOperationLimitExceeded:
            return "Context operation limit exceeded"
        case .externalServiceError(let service):
            return "Error with external service: \(service)"
        case .general(let message):
            return message
        }
    }
    
    /// Localized error description.
    public var errorDescription: String? {
        return description
    }
    
    /// Localized recovery suggestion.
    public var recoverySuggestion: String? {
        switch self {
        case .valueAlreadyExists:
            return "Use update() method instead of store(), or use storeOrUpdate() to handle both cases"
        case .valueNotFound:
            return "Check if the key exists before attempting to retrieve or update it"
        case .typeMismatch:
            return "Ensure the type used for retrieval matches the stored type"
        case .invalidTaskParameters:
            return "Verify all required parameters are provided and valid"
        case .noSuitableAgentFound:
            return "Register an agent with the required capabilities or modify task requirements"
        case .taskExecutionTimeout:
            return "Increase the timeout duration or optimize the task for faster execution"
        case .taskCanceled:
            return "Task was canceled, check if cancellation was intentional"
        case .authenticationFailed:
            return "Verify credentials and connection settings"
        case .taskDoesNotSupportAsyncExecution:
            return "Use a synchronous execution method instead"
        case .missingCapability:
            return "Register an agent with the required capability or implement the capability"
        case .modelNotAvailable:
            return "Configure access to the required model or use an alternative"
        case .contextOperationLimitExceeded:
            return "Reduce the number of context operations or increase the limit"
        case .externalServiceError:
            return "Check the external service status and connection"
        case .general:
            return "Check the error details for more information"
        }
    }
    
    /// The underlying error, if this error wraps another error.
    public var underlyingError: Error? {
        switch self {
        case .externalServiceError:
            // External service errors might have underlying errors in a real implementation
            return nil
        default:
            return nil
        }
    }
    
    /// Returns whether this error can be recovered from.
    public var isRecoverable: Bool {
        switch self {
        case .valueAlreadyExists, .valueNotFound, .typeMismatch, .invalidTaskParameters,
             .contextOperationLimitExceeded:
            return true
        case .taskExecutionTimeout, .taskCanceled:
            return true
        case .authenticationFailed, .missingCapability, .modelNotAvailable,
             .externalServiceError:
            return true
        case .noSuitableAgentFound, .taskDoesNotSupportAsyncExecution, .general:
            return false
        }
    }
}

/// Extension providing helper methods for AIError.
@available(macOS 15.0, *)
extension AIError {
    /// Creates a general error with a custom message.
    ///
    /// - Parameter message: The custom error message.
    /// - Returns: A general error with the custom message.
    public static func withMessage(_ message: String) -> AIError {
        return .general(message)
    }
    
    /// Wraps another error in an AIError.
    ///
    /// - Parameters:
    ///   - error: The error to wrap.
    ///   - context: Optional context information about the error.
    /// - Returns: A general AIError wrapping the provided error.
    public static func wrap(_ error: Error, context: String? = nil) -> AIError {
        if let aiError = error as? AIError {
            return aiError
        }
        
        let message = context != nil ? "\(context!): \(error.localizedDescription)" : error.localizedDescription
        return .general(message)
    }
    
    /// Returns a debug description of the error, including chain of underlying errors.
    ///
    /// - Returns: A debug description of the error.
    public func debugDescription() -> String {
        var description = self.description
        
        if let suggestion = self.recoverySuggestion {
            description += "\nRecovery suggestion: \(suggestion)"
        }
        
        var currentError: Error? = self.underlyingError
        var depth = 1
        
        while let error = currentError {
            description += "\nCaused by (\(depth)): \(error.localizedDescription)"
            
            if let aiError = error as? AIError {
                currentError = aiError.underlyingError
            } else if let nsError = error as NSError, let underlyingError = nsError.userInfo[NSUnderlyingErrorKey] as? Error {
                currentError = underlyingError
            } else {
                currentError = nil
            }
            
            depth += 1
        }
        
        return description
    }
    
    /// Handles the error by performing the appropriate recovery action.
    ///
    /// - Parameters:
    ///   - defaultAction: The default action to perform if no specific recovery is available.
    ///   - recoveryHandler: Optional handler for specific error types.
    /// - Returns: True if the error was handled, false otherwise.
    public func handle(
        defaultAction: () -> Bool = { false },
        recoveryHandler: ((AIError) -> Bool)? = nil
    ) -> Bool {
        // If a recovery handler is provided and it returns true, the error is handled
        if let recoveryHandler = recoveryHandler, recoveryHandler(self) {
            return true
        }
        
        // Perform default recovery actions based on error type
        switch self {
        case .valueAlreadyExists, .valueNotFound, .typeMismatch,
             .taskExecutionTimeout, .taskCanceled:
            // These errors are generally recoverable with appropriate action
            return isRecoverable && defaultAction()
            
        case .invalidTaskParameters, .noSuitableAgentFound, .authenticationFailed,
             .taskDoesNotSupportAsyncExecution, .missingCapability, .modelNotAvailable,
             .contextOperationLimitExceeded, .externalServiceError, .general:
            // These errors may require specific handling depending on the context
            return defaultAction()
        }
    }
}
