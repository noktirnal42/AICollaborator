import Foundation

/// Represents capabilities that AI agents can provide.
///
/// `AICapability` defines the possible capabilities that AI agents can have.
/// Agents declare their capabilities, and tasks specify which capabilities they require.
/// The AICollaborator uses this information to route tasks to appropriate agents.
///
/// ## Example Usage
///
/// ```swift
/// // An agent declares its capabilities
/// func provideCapabilities() -> [AICapability] {
///     return [.codeGeneration, .textAnalysis]
/// }
///
/// // A task specifies which capabilities it requires
/// func matchesCapabilities(_ capabilities: [AICapability]) -> Bool {
///     return capabilities.contains(.codeGeneration)
/// }
/// ```
@available(macOS 15.0, *)
public enum AICapability: String, Codable, CaseIterable {
    /// Generate code in various languages.
    case codeGeneration
    
    /// Analyze code for issues, patterns, or improvements.
    case codeAnalysis
    
    /// Process and analyze text content.
    case textAnalysis
    
    /// Solve complex problems through reasoning.
    case problemSolving
    
    /// Process and transform structured data.
    case dataProcessing
    
    /// Communicate effectively with human users.
    case humanInteraction
    
    /// Collaborate with other AI agents.
    case multiAgentCoordination
    
    /// Maintain and utilize conversation context.
    case contextManagement
    
    /// Access and interact with system resources.
    case systemAccess
    
    /// Generate, analyze, or modify visual content.
    case imageProcessing
    
    /// Custom capability with a string identifier.
    case custom(String)
    
    /// Equatability implementation
    public static func == (lhs: AICapability, rhs: AICapability) -> Bool {
        switch (lhs, rhs) {
        case (.codeGeneration, .codeGeneration),
             (.codeAnalysis, .codeAnalysis),
             (.textAnalysis, .textAnalysis),
             (.problemSolving, .problemSolving),
             (.dataProcessing, .dataProcessing),
             (.humanInteraction, .humanInteraction),
             (.multiAgentCoordination, .multiAgentCoordination),
             (.contextManagement, .contextManagement),
             (.systemAccess, .systemAccess),
             (.imageProcessing, .imageProcessing):
            return true
        case (.custom(let lhsValue), .custom(let rhsValue)):
            return lhsValue == rhsValue
        default:
            return false
        }
    }
    
    /// Array of all built-in capabilities (excludes custom).
    public static var allBuiltIn: [AICapability] {
        return [
            .codeGeneration,
            .codeAnalysis,
            .textAnalysis,
            .problemSolving,
            .dataProcessing,
            .humanInteraction,
            .multiAgentCoordination,
            .contextManagement,
            .systemAccess,
            .imageProcessing
        ]
    }
}

/// Extension to provide hashability for AICapability.
@available(macOS 15.0, *)
extension AICapability: Hashable {
    /// Hash value generation for AICapability.
    public func hash(into hasher: inout Hasher) {
        switch self {
        case .codeGeneration:
            hasher.combine(0)
        case .codeAnalysis:
            hasher.combine(1)
        case .textAnalysis:
            hasher.combine(2)
        case .problemSolving:
            hasher.combine(3)
        case .dataProcessing:
            hasher.combine(4)
        case .humanInteraction:
            hasher.combine(5)
        case .multiAgentCoordination:
            hasher.combine(6)
        case .contextManagement:
            hasher.combine(7)
        case .systemAccess:
            hasher.combine(8)
        case .imageProcessing:
            hasher.combine(9)
        case .custom(let value):
            hasher.combine(100)
            hasher.combine(value)
        }
    }
}

/// Represents metadata for an AI capability.
@available(macOS 15.0, *)
public struct AICapabilityMetadata {
    /// The capability the metadata describes.
    public let capability: AICapability
    
    /// A human-readable description of the capability.
    public let description: String
    
    /// Optional requirements for this capability, such as API keys or permissions.
    public let requirements: [String]?
    
    /// Optional level of proficiency for this capability.
    public let proficiencyLevel: ProficiencyLevel?
    
    /// Optional timestamp indicating when this capability was added or updated.
    public let updatedAt: Date?
    
    /// Initialize a new capability metadata.
    ///
    /// - Parameters:
    ///   - capability: The capability the metadata describes.
    ///   - description: A human-readable description of the capability.
    ///   - requirements: Optional requirements for this capability.
    ///   - proficiencyLevel: Optional level of proficiency for this capability.
    ///   - updatedAt: Optional timestamp indicating when this capability was added or updated.
    public init(
        capability: AICapability,
        description: String,
        requirements: [String]? = nil,
        proficiencyLevel: ProficiencyLevel? = nil,
        updatedAt: Date? = nil
    ) {
        self.capability = capability
        self.description = description
        self.requirements = requirements
        self.proficiencyLevel = proficiencyLevel
        self.updatedAt = updatedAt
    }
    
    /// Proficiency levels for capabilities.
    public enum ProficiencyLevel: Int, Codable, Comparable {
        /// Basic proficiency level.
        case basic = 1
        
        /// Intermediate proficiency level.
        case intermediate = 2
        
        /// Advanced proficiency level.
        case advanced = 3
        
        /// Expert proficiency level.
        case expert = 4
        
        /// Comparability implementation
        public static func < (lhs: ProficiencyLevel, rhs: ProficiencyLevel) -> Bool {
            return lhs.rawValue < rhs.rawValue
        }
    }
    
    /// Returns a human-readable description of the capability.
    public var humanReadableDescription: String {
        return "\(description) (Level: \(proficiencyLevel?.rawValue ?? 0))"
    }
}

/// Structure representing additional requirements for a capability.
@available(macOS 15.0, *)
public struct AICapabilityRequirement: Codable {
    /// The type of requirement.
    public enum RequirementType: String, Codable {
        /// API key or authentication credential.
        case apiKey
        
        /// Specific permission needed.
        case permission
        
        /// External dependency.
        case dependency
        
        /// Specific model required.
        case model
        
        /// Hardware requirement.
        case hardware
        
        /// Custom requirement type.
        case custom(String)
        
        private enum CodingKeys: String, CodingKey {
            case type, customValue
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let type = try container.decode(String.self, forKey: .type)
            
            switch type {
            case "apiKey": self = .apiKey
            case "permission": self = .permission
            case "dependency": self = .dependency
            case "model": self = .model
            case "hardware": self = .hardware
            case "custom":
                let customValue = try container.decode(String.self, forKey: .customValue)
                self = .custom(customValue)
            default:
                self = .custom(type)
            }
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            switch self {
            case .apiKey:
                try container.encode("apiKey", forKey: .type)
            case .permission:
                try container.encode("permission", forKey: .type)
            case .dependency:
                try container.encode("dependency", forKey: .type)
            case .model:
                try container.encode("model", forKey: .type)
            case .hardware:
                try container.encode("hardware", forKey: .type)
            case .custom(let value):
                try container.encode("custom", forKey: .type)
                try container.encode(value, forKey: .customValue)
            }
        }
    }
    
    /// The type of requirement.
    public let type: RequirementType
    
    /// Name of the requirement.
    public let name: String
    
    /// Description of the requirement.
    public let description: String
    
    /// Whether the requirement is mandatory.
    public let isMandatory: Bool
    
    /// Optional version requirement.
    public let versionRequirement: String?
    
    /// Initialize a new capability requirement.
    ///
    /// - Parameters:
    ///   - type: The type of requirement.
    ///   - name: Name of the requirement.
    ///   - description: Description of the requirement.
    ///   - isMandatory: Whether the requirement is mandatory.
    ///   - versionRequirement: Optional version requirement.
    public init(
        type: RequirementType,
        name: String,
        description: String,
        isMandatory: Bool = true,
        versionRequirement: String? = nil
    ) {
        self.type = type
        self.name = name
        self.description = description
        self.isMandatory = isMandatory
        self.versionRequirement = versionRequirement
    }
}

/// A collection of utility methods for working with capabilities.
@available(macOS 15.0, *)
public struct AICapabilityUtility {
    /// Checks if a set of capabilities contains all the required capabilities.
    ///
    /// - Parameters:
    ///   - availableCapabilities: The available capabilities.
    ///   - requiredCapabilities: The required capabilities.
    ///
    /// - Returns: True if all required capabilities are available, false otherwise.
    public static func hasRequiredCapabilities(
        availableCapabilities: [AICapability],
        requiredCapabilities: [AICapability]
    ) -> Bool {
        // Convert to sets for efficient contains operations
        let availableSet = Set(availableCapabilities)
        
        // Check if all required capabilities are in the available set
        for capability in requiredCapabilities {
            if !availableSet.contains(capability) {
                return false
            }
        }
        
        return true
    }
    
    /// Returns the missing capabilities from a set of required capabilities.
    ///
    /// - Parameters:
    ///   - availableCapabilities: The available capabilities.
    ///   - requiredCapabilities: The required capabilities.
    ///
    /// - Returns: Array of missing capabilities, empty if none are missing.
    public static func missingCapabilities(
        availableCapabilities: [AICapability],
        requiredCapabilities: [AICapability]
    ) -> [AICapability] {
        // Convert to sets for efficient contains operations
        let availableSet = Set(availableCapabilities)
        
        // Filter out capabilities that are not in the available set
        return requiredCapabilities.filter { !availableSet.contains($0) }
    }
    
    /// Returns a standard description for a capability.
    ///
    /// - Parameter capability: The capability to describe.
    /// - Returns: A standard description of the capability.
    public static func standardDescription(for capability: AICapability) -> String {
        switch capability {
        case .codeGeneration:
            return "Ability to generate code in various programming languages"
        case .codeAnalysis:
            return "Ability to analyze code for issues, patterns, or improvements"
        case .textAnalysis:
            return "Ability to process and analyze text content"
        case .problemSolving:
            return "Ability to solve complex problems through reasoning"
        case .dataProcessing:
            return "Ability to process and transform structured data"
        case .humanInteraction:
            return "Ability to communicate effectively with human users"
        case .multiAgentCoordination:
            return "Ability to collaborate with other AI agents"
        case .contextManagement:
            return "Ability to maintain and utilize conversation context"
        case .systemAccess:
            return "Ability to access and interact with system resources"
        case .imageProcessing:
            return "Ability to generate, analyze, or modify visual content"
        case .custom(let value):
            return "Custom capability: \(value)"
        }
    }
}

/// Metadata about an AI agent.
@available(macOS 15.0, *)
public struct AIAgentMetadata {
    /// The name of the agent.
    public let name: String
    
    /// The version of the agent.
    public let version: String
    
    /// A brief description of the agent.
    public let description: String
    
    /// The creator or provider of the agent.
    public let provider: String?
    
    /// Optional URL for more information about the agent.
    public let infoURL: URL?
    
    /// Optional timestamp indicating when the agent was created or updated.
    public let updatedAt: Date?
    
    /// The capabilities this agent provides.
    public let capabilities: [AICapability]?
    
    /// Initialize a new agent metadata.
    ///
    /// - Parameters:
    ///   - name: The name of the agent.
    ///   - version: The version of the agent.
    ///   - description: A brief description of the agent.
    ///   - provider: The creator or provider of the agent.
    ///   - infoURL: Optional URL for more information about the agent.
    ///   - updatedAt: Optional timestamp indicating when the agent was created or updated.
    ///   - capabilities: The capabilities this agent provides.
    public init(
        name: String,
        version: String,
        description: String,
        provider: String? = nil,
        infoURL: URL? = nil,
        updatedAt: Date? = nil,
        capabilities: [AICapability]? = nil
    ) {
        self.name = name
        self.version = version
        self.description = description
        self.provider = provider
        self.infoURL = infoURL
        self.updatedAt = updatedAt
        self.capabilities = capabilities
    }
}
