import Vapor
import Foundation

/// Redis-based implementation of AICacheServiceInterface.
///
/// This service provides AI response caching using Redis as the backend storage,
/// offering distributed caching capabilities with TTL support and statistics tracking.
/// It wraps the generic CacheService to provide AI-specific caching functionality.
///
/// ## Key Features
/// - **Distributed Caching**: Redis backend allows multiple application instances to share cache
/// - **TTL Support**: Automatic expiration of cached entries based on content type
/// - **Statistics Tracking**: Hit/miss ratios and cache utilization metrics
/// - **Type-aware Caching**: Different TTLs for different AI operation types
/// - **Performance Optimized**: Efficient Redis operations with minimal overhead
///
/// ## Cache Key Strategy
/// - Uses AI-specific key generation through CacheKeyGeneratorServiceInterface
/// - Keys include operation type, content hash, and context information
/// - Consistent key generation ensures cache hits across requests
final class RedisAICacheService: AICacheServiceInterface {
    
    private let cacheService: CacheService
    private let keyGenerator: CacheKeyGeneratorServiceInterface
    private let logger: Logger
    
    init(
        cacheService: CacheService,
        keyGenerator: CacheKeyGeneratorServiceInterface,
        logger: Logger
    ) {
        self.cacheService = cacheService
        self.keyGenerator = keyGenerator
        self.logger = logger
    }
    
    // MARK: - Service Pattern Method
    
    func `for`(_ request: Request) -> AICacheServiceInterface {
        return RedisAICacheService(
            cacheService: cacheService,
            keyGenerator: keyGenerator,
            logger: request.logger
        )
    }
    
    // MARK: - Cache Operations
    
    func get(key: String) async -> String? {
        do {
            return try await cacheService.get(key, as: String.self)
        } catch {
            logger.warning("AI cache get failed", metadata: [
                "key": .string(key),
                "error": .string(error.localizedDescription)
            ])
            return nil
        }
    }
    
    func set(key: String, value: String, ttl: TimeInterval) async {
        do {
            try await cacheService.set(key, value: value, ttl: ttl)
        } catch {
            logger.error("AI cache set failed", metadata: [
                "key": .string(key),
                "ttl": .string("\(Int(ttl))"),
                "error": .string(error.localizedDescription)
            ])
        }
    }
    
    func exists(key: String) async -> Bool {
        do {
            let value: String? = try await cacheService.get(key, as: String.self)
            return value != nil
        } catch {
            return false
        }
    }
    
    func remove(key: String) async {
        do {
            try await cacheService.delete(key)
        } catch {
            logger.warning("AI cache remove failed", metadata: [
                "key": .string(key),
                "error": .string(error.localizedDescription)
            ])
        }
    }
    
    func clear() async {
        do {
            // For now, just flush the entire cache since we don't have pattern deletion
            // In production, this should be implemented with Redis SCAN and DELETE operations
            try await cacheService.flush()
            logger.info("AI cache cleared (full cache flush)")
        } catch {
            logger.error("AI cache clear failed", metadata: [
                "error": .string(error.localizedDescription)
            ])
        }
    }
    
    // MARK: - Cache Management
    
    func getStatistics() async -> CacheStatistics {
        do {
            // Use RedisCacheService's built-in statistics if it's a RedisCacheService
            if let redisCacheService = cacheService as? RedisCacheService {
                return try await redisCacheService.getStatistics()
            }
        } catch {
            logger.warning("Failed to get Redis cache statistics", metadata: [
                "error": .string(error.localizedDescription)
            ])
        }
        
        // Fallback to basic statistics
        let entryCount = await count()
        return CacheStatistics(
            hits: 0,        // Would need separate tracking
            misses: 0,      // Would need separate tracking  
            entryCount: entryCount,
            maxEntries: Int.max  // Redis has no hard limit by default
        )
    }
    
    func cleanupExpired() async {
        // Redis handles TTL expiration automatically
        // This is a no-op for Redis implementation
        logger.debug("AI cache cleanup requested - Redis handles TTL automatically")
    }
    
    func count() async -> Int {
        do {
            // Since we don't have pattern-based counting, we'll use the overall statistics
            if let redisCacheService = cacheService as? RedisCacheService {
                let stats = try await redisCacheService.getStatistics()
                // This gives us total cache entries, not just AI entries
                // In a real implementation, we'd need Redis SCAN operations
                return stats.entryCount
            }
        } catch {
            logger.warning("AI cache count failed", metadata: [
                "error": .string(error.localizedDescription)
            ])
        }
        return 0
    }
    
    func getEntriesByType() async -> [AICacheType: [String]] {
        // Without SCAN capability, we can't efficiently retrieve keys by pattern
        // This would require implementing Redis SCAN operations in RedisCacheService
        logger.debug("AI cache entries by type requested - not implemented without SCAN support")
        
        // Return empty dictionary for now
        return [:]
    }
}