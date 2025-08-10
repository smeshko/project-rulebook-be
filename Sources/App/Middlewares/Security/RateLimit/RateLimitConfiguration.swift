import Foundation

struct RateLimitConfiguration {
    // AI Operation Limits (most restrictive)
    let imageAnalysisLimit: Int
    let imageAnalysisWindow: Int
    let rulesGenerationLimit: Int
    let rulesGenerationWindow: Int
    
    // Admin Limits (restricted)
    let adminLimit: Int
    let adminWindow: Int
    
    // API Limits (moderate)
    let apiLimit: Int
    let apiWindow: Int
    
    // General Limits (lenient)
    let generalLimit: Int
    let generalWindow: Int
    
    static let `default` = RateLimitConfiguration(
        // AI operations: Very restrictive to prevent abuse
        imageAnalysisLimit: 5,
        imageAnalysisWindow: 3600, // 1 hour
        rulesGenerationLimit: 10,
        rulesGenerationWindow: 3600, // 1 hour
        
        // Admin operations: Restricted but reasonable
        adminLimit: 20,
        adminWindow: 300, // 5 minutes
        
        // API operations: Moderate limits
        apiLimit: 100,
        apiWindow: 3600, // 1 hour
        
        // General web requests: Lenient
        generalLimit: 1000,
        generalWindow: 3600 // 1 hour
    )
    
    static func production() -> RateLimitConfiguration {
        return RateLimitConfiguration(
            imageAnalysisLimit: 3,
            imageAnalysisWindow: 3600,
            rulesGenerationLimit: 5,
            rulesGenerationWindow: 3600,
            adminLimit: 10,
            adminWindow: 300,
            apiLimit: 50,
            apiWindow: 3600,
            generalLimit: 500,
            generalWindow: 3600
        )
    }
    
    static func development() -> RateLimitConfiguration {
        return RateLimitConfiguration(
            imageAnalysisLimit: 50,
            imageAnalysisWindow: 3600,
            rulesGenerationLimit: 100,
            rulesGenerationWindow: 3600,
            adminLimit: 200,
            adminWindow: 300,
            apiLimit: 1000,
            apiWindow: 3600,
            generalLimit: 10000,
            generalWindow: 3600
        )
    }
}