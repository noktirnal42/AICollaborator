import Foundation

struct AnalysisResult: Identifiable, Codable {
    let id: UUID
    let targetId: String
    let targetType: TargetType
    let content: String
    let createdAt: Date
    
    enum TargetType: String, Codable {
        case issue
        case pullRequest
    }
    
    init(targetId: String, targetType: TargetType, content: String) {
        self.id = UUID()
        self.targetId = targetId
        self.targetType = targetType
        self.content = content
        self.createdAt = Date()
    }
}

extension AnalysisResult {
    // Parse Markdown content to extract sections
    var primaryAnalysis: String? {
        guard let primaryRange = content.range(of: "(llama3.2:latest)")?.upperBound,
              let secondaryRange = content.range(of: "(deepseek-r1:8b)") else {
            return nil
        }
        
        let secondaryStartIndex = content.distance(from: content.startIndex, to: secondaryRange.lowerBound)
        let primaryText = content[primaryRange...]
        
        if let endIndex = primaryText.firstIndex(where: { $0 == '#' }) {
            return String(primaryText[..<endIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
        } else if secondaryStartIndex > 0 {
            let endIndex = content.index(content.startIndex, offsetBy: secondaryStartIndex - 1)
            return String(primaryText[..<endIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        return String(primaryText)
    }
    
    var secondaryAnalysis: String? {
        guard let secondaryRange = content.range(of: "(deepseek-r1:8b)")?.upperBound,
              let nextStepsRange = content.range(of: "## Next Steps") else {
            return nil
        }
        
        let secondaryText = content[secondaryRange..<nextStepsRange.lowerBound]
        return String(secondaryText).trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    var nextSteps: String? {
        guard let nextStepsRange = content.range(of: "## Next Steps")?.upperBound else {
            return nil
        }
        
        return String(content[nextStepsRange...]).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

