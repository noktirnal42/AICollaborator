import Foundation

struct GithubPR: Identifiable, Codable, Equatable {
    let id: String
    let number: Int
    let title: String
    let body: String
    let branchName: String
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
        case branchName = "head_ref"
        case updatedAt = "updated_at"
    }
    
    init(id: String, number: Int, title: String, body: String, branchName: String, updatedAt: String, hasAnalysis: Bool = false) {
        self.id = id
        self.number = number
        self.title = title
        self.body = body
        self.branchName = branchName
        self.updatedAt = updatedAt
        self.hasAnalysis = hasAnalysis
    }
}

import Foundation

struct GithubPR: Identifiable, Codable, Equatable {
    let id: String
    let number: Int
    let title: String
    let body: String
    let branchName: String
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
        case branchName = "head_ref"
        case updatedAt = "updated_at"
    }
    
    init(id: String, number: Int, title: String, body: String, branchName: String, updatedAt: String, hasAnalysis: Bool = false) {
        self.id = id
        self.number = number
        self.title = title
        self.body = body
        self.branchName = branchName
        self.updatedAt = updatedAt
        self.hasAnalysis = hasAnalysis
    }
}

import Foundation

struct GithubPR: Identifiable, Codable, Equatable {
    let id: String
    let number: Int
    let title: String
    let body: String
    let branchName: String
    let updatedAt: String
    var hasAnalysis: Bool = false
    
    var bodyPreview: String {
        if body.count > 150 {
            return body.prefix(150) + "..."
        }
        return body
    }
    
    // For decoding from GitHub API
    enum CodingKeys: String, CodingKey {
        case id
        case number
        case title
        case body
        case branchName = "head_ref"
        case updatedAt = "updated_at"
    }
    
    init(id: String, number: Int, title: String, body: String, branchName: String, updatedAt: String, hasAnalysis: Bool = false) {
        self.id = id
        self.number = number
        self.title = title
        self.body = body
        self.branchName = branchName
        self.updatedAt = updatedAt
        self.hasAnalysis = hasAnalysis
    }
}

