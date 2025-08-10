import Foundation

enum RateLimitType: String, CaseIterable {
    case imageAnalysis = "image_analysis"
    case rulesGeneration = "rules_generation"
    case admin = "admin"
    case api = "api"
    case general = "general"
}

struct RateLimitInfo {
    let type: RateLimitType
    let maxRequests: Int
    let windowSeconds: Int
}