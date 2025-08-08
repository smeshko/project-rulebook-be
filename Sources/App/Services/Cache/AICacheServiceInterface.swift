import Vapor

/// Protocol defining the interface for AI response caching
/// This interface allows for future migration from in-memory cache to Redis
public protocol AICacheServiceInterface: Sendable {
    
    // MARK: - Service Pattern Method
    
    /// Returns a service instance for the given request
    func `for`(_ request: Request) -> AICacheServiceInterface
    
    // MARK: - Cache Operations
    
    /// Retrieves a cached value for the given key
    /// - Parameter key: The cache key to look up
    /// - Returns: The cached string value if found and not expired, nil otherwise
    func get(key: String) async -> String?
    
    /// Stores a value in the cache with a specified TTL
    /// - Parameters:
    ///   - key: The cache key to store under
    ///   - value: The string value to cache
    ///   - ttl: Time to live in seconds
    func set(key: String, value: String, ttl: TimeInterval) async
    
    /// Checks if a key exists in the cache and is not expired
    /// - Parameter key: The cache key to check
    /// - Returns: true if the key exists and is valid, false otherwise
    func exists(key: String) async -> Bool
    
    /// Removes a specific key from the cache
    /// - Parameter key: The cache key to remove
    func remove(key: String) async
    
    /// Clears all entries from the cache
    func clear() async
    
    // MARK: - Cache Management
    
    /// Returns current cache statistics
    /// - Returns: CacheStatistics containing metrics about cache performance
    func getStatistics() async -> CacheStatistics
    
    /// Removes expired entries from the cache
    /// This is called automatically but can be triggered manually
    func cleanupExpired() async
    
    /// Returns the current number of entries in the cache
    /// - Returns: The count of active cache entries
    func count() async -> Int
}

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

// MARK: - Service Registration Extensions

extension Application.Services {
    var aiCache: Application.Service<AICacheServiceInterface> {
        .init(application: application)
    }
}

extension Request.Services {
    var aiCache: AICacheServiceInterface {
        self.request.application.services.aiCache.service.for(request)
    }
}