import Foundation

struct GithubIssue: Identifiable, Codable, Equatable {
    let id: String
    let number: Int
    let title: String
    let body: String
    let labels: [String]
    let updatedAt: String
    var hasAnalysis: Bool = false
    
    var bodyPreview: String {
        if body.count > 150 {
            return String(body.prefix(150)) + "..."
        }
        return body
    }
    
    // For decoding from GitHub API
    enum CodingKeys: String, CodingKey {
        case id
        case number
        case title
        case body
        case labels
        case updatedAt = "updated_at"
    }
    
    init(id: String, number: Int, title: String, body: String, labels: [String], updatedAt: String, hasAnalysis: Bool = false) {
        self.id = id
        self.number = number
        self.title = title
        self.body = body
        self.labels = labels
        self.updatedAt = updatedAt
        self.hasAnalysis = hasAnalysis
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        number = try container.decode(Int.self, forKey: .number)
        title = try container.decode(String.self, forKey: .title)
        body = try container.decode(String.self, forKey: .body)
        
        // For labels, GitHub API returns an array of objects with name property
        if let labelsArray = try? container.decode([[String: String]].self, forKey: .labels) {
            labels = labelsArray.compactMap { $0["name"] }
        } else {
            labels = []
        }
        
        updatedAt = try container.decode(String.self, forKey: .updatedAt)
        hasAnalysis = false
    }
}
