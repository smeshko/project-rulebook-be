import Foundation

/// Represents a single cache entry with TTL and metadata
struct CacheEntry: Sendable {
    /// The cache key
    let key: String
    
    /// The cached value (JSON response string)
    let value: String
    
    /// When this entry was created
    let createdAt: Date
    
    /// When this entry expires
    let expiresAt: Date
    
    /// Number of times this entry has been accessed
    var hitCount: Int
    
    /// Last time this entry was accessed
    var lastAccessedAt: Date
    
    /// Initializes a new cache entry
    /// - Parameters:
    ///   - key: The cache key
    ///   - value: The value to cache
    ///   - ttl: Time to live in seconds
    init(key: String, value: String, ttl: TimeInterval) {
        self.key = key
        self.value = value
        self.createdAt = Date()
        self.expiresAt = Date().addingTimeInterval(ttl)
        self.hitCount = 0
        self.lastAccessedAt = Date()
    }
    
    /// Checks if this cache entry has expired
    var isExpired: Bool {
        return Date() > expiresAt
    }
    
    /// Age of this cache entry in seconds
    var age: TimeInterval {
        return Date().timeIntervalSince(createdAt)
    }
    
    /// Time remaining before expiration in seconds
    var timeToLive: TimeInterval {
        return max(0, expiresAt.timeIntervalSince(Date()))
    }
    
    /// Updates the hit count and last accessed timestamp
    /// - Returns: A new CacheEntry with updated access information
    func recordAccess() -> CacheEntry {
        var updated = self
        updated.hitCount += 1
        updated.lastAccessedAt = Date()
        return updated
    }
}

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

/// Types of AI operations that can be cached
enum AICacheType: String, CaseIterable, Sendable {
    case rulesGeneration = "rules_generation"
    case imageAnalysis = "image_analysis"
    
    /// Returns the appropriate TTL for this cache type
    /// - Parameter config: The cache configuration to use
    /// - Returns: TTL in seconds
    func getTTL(from config: CacheConfiguration) -> TimeInterval {
        switch self {
        case .rulesGeneration:
            return config.rulesGenerationTTL
        case .imageAnalysis:
            return config.imageAnalysisTTL
        }
    }
    
    /// Returns a human-readable description
    var description: String {
        switch self {
        case .rulesGeneration:
            return "Rules Generation"
        case .imageAnalysis:
            return "Image Analysis"
        }
    }
}