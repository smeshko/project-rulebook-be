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