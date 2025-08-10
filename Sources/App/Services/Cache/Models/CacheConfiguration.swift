import Foundation

/// Configuration settings for the cache service
struct CacheConfiguration: Sendable {
    /// Maximum number of entries to store in cache
    let maxEntries: Int
    
    /// Default TTL for rules generation cache entries (in seconds)
    let rulesGenerationTTL: TimeInterval
    
    /// Default TTL for image analysis cache entries (in seconds)  
    let imageAnalysisTTL: TimeInterval
    
    /// Interval between automatic cleanup runs (in seconds)
    let cleanupInterval: TimeInterval
    
    /// Whether to enable detailed cache logging
    let enableLogging: Bool
    
    /// Default configuration for development environment
    static let development = CacheConfiguration(
        maxEntries: 500,
        rulesGenerationTTL: 3600, // 1 hour
        imageAnalysisTTL: 1800,   // 30 minutes
        cleanupInterval: 300,     // 5 minutes
        enableLogging: true
    )
    
    /// Default configuration for production environment
    static let production = CacheConfiguration(
        maxEntries: 1000,
        rulesGenerationTTL: 3600, // 1 hour
        imageAnalysisTTL: 1800,   // 30 minutes
        cleanupInterval: 600,     // 10 minutes
        enableLogging: false
    )
    
    /// Default configuration for testing environment
    static let testing = CacheConfiguration(
        maxEntries: 100,
        rulesGenerationTTL: 300,  // 5 minutes
        imageAnalysisTTL: 300,    // 5 minutes
        cleanupInterval: 60,      // 1 minute
        enableLogging: false
    )
}