import Foundation

/// Protocol defining the interface for components that interact with humans in the AICollaborator framework.
public protocol HumanInteractive {
    /// Present information to the human user
    /// - Parameters:
    ///   - information: The information to present
    ///   - format: The format to use for presentation
    func presentToHuman(information: Any, format: PresentationFormat)
    
    /// Request feedback from the human user
    /// - Parameters:
    ///   - prompt: The prompt to show to the user
    ///   - options: Optional array of predefined options
    /// - Returns: The feedback provided by the human
    func requestHumanFeedback(prompt: String, options: [String]?) -> String
    
    /// Notify the human of an important event
    /// - Parameters:
    ///   - event: Description of the event
    ///   - level: The importance level of the notification
    func notifyHuman(event: String, level: NotificationLevel)
    
    /// Check if human interaction is available
    /// - Returns: Boolean indicating whether human interaction is currently available
    func isHumanInteractionAvailable() -> Bool
}

/// Format options for presenting information to humans
public enum PresentationFormat {
    case text
    case markdown
    case json
    case structuredData
    case visualization
}

/// Importance levels for human notifications
public enum NotificationLevel {
    case info
    case warning
    case error
    case critical
}

