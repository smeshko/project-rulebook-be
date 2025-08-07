import Vapor

struct DatabaseConfig: Sendable {
    let name: String
    let host: String
    let username: String
    let password: String
    let port: Int
}

struct ServicesConfig: Sendable {
    let brevoAPIKey: String
    let brevoURL: String
    let openAIKey: String
}

struct SecurityConfig: Sendable {
    let baseURL: String
    let appIdentifier: String
    let jwtKey: String
    let corsAllowedOrigins: [String]
    let rateLimitMaxRequests: Int
    let rateLimitWindowMinutes: Int
}

struct AWSConfig: Sendable {
    let accessKey: String
    let secretAccessKey: String
    let region: String
    let s3BucketName: String
}

struct APNSConfig: Sendable {
    let key: String
    let privateKey: String
    let teamId: String
}

struct CacheConfig: Sendable {
    let maxEntries: Int
    let rulesGenerationTTL: TimeInterval
    let imageAnalysisTTL: TimeInterval
    let cleanupInterval: TimeInterval
    let enableLogging: Bool
}