import Vapor
import Foundation

// MARK: - Response Models

/// Response model for cache statistics endpoint
struct CacheStatisticsResponse: Content, Sendable {
    let statistics: CacheStatistics
    let entriesByType: [String: [String]] // Convert enum keys to strings
    let timestamp: Date
    
    enum CodingKeys: String, CodingKey {
        case statistics
        case entriesByType = "entries_by_type"
        case timestamp
    }
}

/// Response model for cache clear endpoint
struct CacheClearResponse: Content, Sendable {
    let entriesRemoved: Int
    let remainingEntries: Int
    let timestamp: Date
    
    enum CodingKeys: String, CodingKey {
        case entriesRemoved = "entries_removed"
        case remainingEntries = "remaining_entries"
        case timestamp
    }
}

/// Response model for cache entries endpoint
struct CacheEntriesResponse: Content, Sendable {
    let entries: [CacheEntryInfo]
    let entriesByType: [String: [String]] // Convert enum keys to strings
    let totalCount: Int
    let timestamp: Date
    
    enum CodingKeys: String, CodingKey {
        case entries
        case entriesByType = "entries_by_type"
        case totalCount = "total_count"
        case timestamp
    }
}

/// Sendable cache entry info for API responses
struct CacheEntryInfo: Content, Sendable {
    let key: String
    let age: TimeInterval
    let ttlRemaining: TimeInterval
    let hitCount: Int
    let lastAccessed: TimeInterval
    let expired: Bool
    
    enum CodingKeys: String, CodingKey {
        case key
        case age
        case ttlRemaining = "ttl_remaining"
        case hitCount = "hit_count"
        case lastAccessed = "last_accessed"
        case expired
    }
}

/// Response model for manual cleanup endpoint
struct CacheCleanupResponse: Content, Sendable {
    let entriesRemoved: Int
    let remainingEntries: Int
    let timestamp: Date
    
    enum CodingKeys: String, CodingKey {
        case entriesRemoved = "entries_removed"
        case remainingEntries = "remaining_entries"
        case timestamp
    }
}

/// Health status enum for cache
enum CacheHealthStatus: String, Content, Sendable {
    case healthy = "healthy"
    case warning = "warning"
    case critical = "critical"
}

/// Response model for cache health endpoint
struct CacheHealthResponse: Content, Sendable {
    let status: CacheHealthStatus
    let statistics: CacheStatistics
    let issues: [String]
    let recommendations: [String]
    let timestamp: Date
}