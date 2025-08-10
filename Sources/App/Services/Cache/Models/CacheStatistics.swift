import Foundation

/// Cache statistics for monitoring and optimization
public struct CacheStatistics: Codable, Sendable {
    /// Total number of cache hit requests
    let hits: Int
    
    /// Total number of cache miss requests
    let misses: Int
    
    /// Current number of entries in cache
    let entryCount: Int
    
    /// Maximum number of entries allowed
    let maxEntries: Int
    
    /// Cache hit ratio as a percentage
    public var hitRatio: Double {
        let total = hits + misses
        return total > 0 ? Double(hits) / Double(total) * 100.0 : 0.0
    }
    
    /// Total cache requests
    public var totalRequests: Int {
        return hits + misses
    }
    
    /// Cache utilization as a percentage
    public var utilization: Double {
        return maxEntries > 0 ? Double(entryCount) / Double(maxEntries) * 100.0 : 0.0
    }
}