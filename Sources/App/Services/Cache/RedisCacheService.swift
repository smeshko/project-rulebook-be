import Foundation
@preconcurrency import Redis
import Vapor
import NIO

/// Redis-based cache service for high-performance caching
public final class RedisCacheService: CacheService, @unchecked Sendable {
    
    
    private let redis: RedisClient
    private let configuration: RedisConfig
    private let logger: Logger
    
    public init(
        redis: RedisClient,
        configuration: RedisConfig,
        logger: Logger
    ) {
        self.redis = redis
        self.configuration = configuration
        self.logger = logger
    }
    
    // MARK: - CacheService Implementation
    
    public func get<T>(_ key: String, as type: T.Type) async throws -> T? where T: Codable {
        let startTime = Date()
        
        do {
            let result = try await redis.get(RedisKey(key), as: Data.self).get()
            guard let data = result else { 
                logCacheOperation("GET_MISS", key: key, startTime: startTime)
                return nil 
            }
            
            let value = try JSONDecoder().decode(type, from: data)
            logCacheOperation("GET_HIT", key: key, startTime: startTime, size: data.count)
            return value
        } catch {
            logger.error("Redis get error", metadata: [
                "key": .string(key),
                "error": .string(error.localizedDescription)
            ])
            throw CacheError.retrievalFailed(error)
        }
    }
    
    public func set<T>(_ key: String, value: T, ttl: TimeInterval?) async throws where T: Codable {
        let startTime = Date()
        
        do {
            let data = try JSONEncoder().encode(value)
            
            if let ttl = ttl {
                try await redis.setex(RedisKey(key), to: data, expirationInSeconds: Int(ttl)).get()
                logCacheOperation("SET_TTL", key: key, startTime: startTime, size: data.count, ttl: ttl)
            } else {
                try await redis.set(RedisKey(key), to: data).get()
                logCacheOperation("SET", key: key, startTime: startTime, size: data.count)
            }
        } catch {
            logger.error("Redis set error", metadata: [
                "key": .string(key),
                "error": .string(error.localizedDescription)
            ])
            throw CacheError.storageFailed(error)
        }
    }
    
    public func delete(_ key: String) async throws {
        let startTime = Date()
        
        do {
            let deleted = try await redis.delete([RedisKey(key)]).get()
            logCacheOperation("DELETE", key: key, startTime: startTime, deleted: deleted)
        } catch {
            logger.error("Redis delete error", metadata: [
                "key": .string(key),
                "error": .string(error.localizedDescription)
            ])
            throw CacheError.deletionFailed(error)
        }
    }
    
    public func flush() async throws {
        let startTime = Date()
        
        do {
            _ = try await redis.send(command: "FLUSHDB").get()
            logCacheOperation("FLUSH", key: "ALL", startTime: startTime)
            logger.info("Redis cache flushed")
        } catch {
            logger.error("Redis flush error", metadata: [
                "error": .string(error.localizedDescription)
            ])
            throw CacheError.flushFailed(error)
        }
    }
    
    public func exists(_ key: String) async throws -> Bool {
        let startTime = Date()
        
        do {
            let keyBuffer = ByteBuffer(string: key)
            let count = try await redis.send(command: "EXISTS", with: [
                RESPValue.bulkString(keyBuffer)
            ]).get().int ?? 0
            
            let exists = count > 0
            logCacheOperation("EXISTS", key: key, startTime: startTime, exists: exists)
            return exists
        } catch {
            logger.error("Redis exists error", metadata: [
                "key": .string(key),
                "error": .string(error.localizedDescription)
            ])
            throw CacheError.queryFailed(error)
        }
    }
    
    // MARK: - Advanced Operations
    
    /// Get multiple keys at once for better performance
    public func getMultiple<T>(_ keys: [String], as type: T.Type) async throws -> [String: T?] where T: Codable {
        let startTime = Date()
        
        do {
            let redisKeys = keys.map { RedisKey($0) }
            let results = try await redis.mget(redisKeys).get()
            
            var output: [String: T?] = [:]
            for (index, key) in keys.enumerated() {
                if let respValue = results[safe: index],
                   let data = respValue.data {
                    output[key] = try JSONDecoder().decode(type, from: data)
                } else {
                    output[key] = nil
                }
            }
            
            let hitCount = output.values.compactMap { $0 }.count
            logCacheOperation("MGET", key: "\(keys.count)_keys", startTime: startTime, hits: hitCount)
            
            return output
        } catch {
            logger.error("Redis mget error", metadata: [
                "keys_count": .string("\(keys.count)"),
                "error": .string(error.localizedDescription)
            ])
            throw CacheError.retrievalFailed(error)
        }
    }
    
    /// Set multiple key-value pairs with optional TTL
    public func setMultiple<T>(_ values: [String: T], ttl: TimeInterval?) async throws where T: Codable {
        let startTime = Date()
        
        do {
            // Execute individual operations since pipelining is more complex in RediStack
            for (key, value) in values {
                let data = try JSONEncoder().encode(value)
                
                if let ttl = ttl {
                    try await redis.setex(RedisKey(key), to: data, expirationInSeconds: Int(ttl)).get()
                } else {
                    try await redis.set(RedisKey(key), to: data).get()
                }
            }
            
            logCacheOperation("MSET", key: "\(values.count)_keys", startTime: startTime)
        } catch {
            logger.error("Redis mset error", metadata: [
                "keys_count": .string("\(values.count)"),
                "error": .string(error.localizedDescription)
            ])
            throw CacheError.storageFailed(error)
        }
    }
    
    /// Increment a numeric value atomically
    public func increment(_ key: String, by amount: Int = 1, ttl: TimeInterval? = nil) async throws -> Int {
        let startTime = Date()
        
        do {
            let keyBuffer = ByteBuffer(string: key)
            let amountBuffer = ByteBuffer(string: "\(amount)")
            let result = try await redis.send(command: "INCRBY", with: [
                RESPValue.bulkString(keyBuffer),
                RESPValue.bulkString(amountBuffer)
            ]).get().int ?? 0
            
            // Set TTL if this is a new key and TTL is specified
            if let ttl = ttl, result == amount {
                _ = try await redis.expire(RedisKey(key), after: .seconds(Int64(ttl))).get()
            }
            
            logCacheOperation("INCR", key: key, startTime: startTime, value: result)
            return result
        } catch {
            logger.error("Redis increment error", metadata: [
                "key": .string(key),
                "error": .string(error.localizedDescription)
            ])
            throw CacheError.operationFailed(error)
        }
    }
    
    /// Get cache statistics
    public func getStatistics() async throws -> CacheStatistics {
        let startTime = Date()
        
        do {
            let statsBuffer = ByteBuffer(string: "stats")
            let info = try await redis.send(command: "INFO", with: [
                RESPValue.bulkString(statsBuffer)
            ]).get().string ?? ""
            
            // Parse Redis INFO stats
            var hits = 0
            var misses = 0
            
            for line in info.split(separator: "\r\n") {
                let parts = line.split(separator: ":")
                if parts.count == 2 {
                    let key = String(parts[0])
                    let value = String(parts[1])
                    
                    switch key {
                    case "keyspace_hits":
                        hits = Int(value) ?? 0
                    case "keyspace_misses":
                        misses = Int(value) ?? 0
                    default:
                        break
                    }
                }
            }
            
            // Get current database size
            let dbSize = try await redis.send(command: "DBSIZE").get().int ?? 0
            
            let stats = CacheStatistics(
                hits: hits,
                misses: misses,
                entryCount: dbSize,
                maxEntries: configuration.poolSize * 1000 // Estimate based on pool size
            )
            
            logCacheOperation("STATS", key: "info", startTime: startTime)
            return stats
        } catch {
            logger.error("Redis stats error", metadata: [
                "error": .string(error.localizedDescription)
            ])
            throw CacheError.queryFailed(error)
        }
    }
    
    // MARK: - Private Helpers
    
    private func logCacheOperation(
        _ operation: String,
        key: String,
        startTime: Date,
        size: Int? = nil,
        ttl: TimeInterval? = nil,
        deleted: Int? = nil,
        exists: Bool? = nil,
        hits: Int? = nil,
        value: Int? = nil
    ) {
        let duration = Date().timeIntervalSince(startTime)
        
        var metadata: [String: Logger.MetadataValue] = [
            "operation": .string(operation),
            "key": .string(key),
            "duration_ms": .string(String(format: "%.2f", duration * 1000))
        ]
        
        if let size = size {
            metadata["size_bytes"] = .string("\(size)")
        }
        
        if let ttl = ttl {
            metadata["ttl_seconds"] = .string("\(Int(ttl))")
        }
        
        if let deleted = deleted {
            metadata["deleted_count"] = .string("\(deleted)")
        }
        
        if let exists = exists {
            metadata["exists"] = .string("\(exists)")
        }
        
        if let hits = hits {
            metadata["hit_count"] = .string("\(hits)")
        }
        
        if let value = value {
            metadata["result_value"] = .string("\(value)")
        }
        
        logger.debug("Redis operation", metadata: metadata)
    }
}

// MARK: - ServiceLifecycle Implementation

extension RedisCacheService: ServiceLifecycle {
    /// Initializes the Redis cache service during application startup.
    public func startup(_ app: Application) async throws {
        do {
            // Test Redis connection with a ping
            _ = try await redis.ping().get()
            
            // Get Redis server info to verify connectivity and log version
            let statsBuffer = ByteBuffer(string: "server")
            let info = try await redis.send(command: "INFO", with: [
                RESPValue.bulkString(statsBuffer)
            ]).get().string ?? ""
            
            // Extract Redis version for logging
            var redisVersion = "unknown"
            for line in info.split(separator: "\r\n") {
                if line.hasPrefix("redis_version:") {
                    redisVersion = String(line.dropFirst("redis_version:".count))
                    break
                }
            }
            
            // Log successful startup with connection details
            app.logger.info("Redis cache service started successfully", metadata: [
                "redis_version": .string(redisVersion),
                "pool_size": .string("\(configuration.poolSize)"),
                "host": .string(configuration.host),
                "port": .string("\(configuration.port)")
            ])
            
        } catch {
            app.logger.error("Redis cache service startup failed", metadata: [
                "error": .string(error.localizedDescription),
                "host": .string(configuration.host),
                "port": .string("\(configuration.port)")
            ])
            throw error
        }
    }
    
    /// Gracefully shuts down the Redis cache service during application termination.
    public func shutdown(_ app: Application) async throws {
        do {
            // Close the Redis connection pool gracefully
            // Note: RediStack automatically handles connection cleanup on deallocation
            app.logger.info("Redis cache service shutting down gracefully")
            
            // Optional: Send a final command to ensure connection is still valid before shutdown
            _ = try await redis.ping().get()
            
            app.logger.info("Redis cache service shut down successfully")
            
        } catch {
            // Log shutdown errors but don't throw to avoid cascade failures
            app.logger.warning("Redis cache service shutdown encountered issues", metadata: [
                "error": .string(error.localizedDescription)
            ])
        }
    }
}

// MARK: - ServiceHealthCheck Implementation

extension RedisCacheService: ServiceHealthCheck {
    /// Performs a health check to determine if Redis cache is operating correctly.
    public func isHealthy() async -> Bool {
        do {
            // Test basic connectivity with ping
            let startTime = Date()
            _ = try await redis.ping().get()
            let responseTime = Date().timeIntervalSince(startTime)
            
            // Check response time is reasonable (under 100ms for healthy Redis)
            guard responseTime < 0.1 else {
                logger.warning("Redis health check: slow response time", metadata: [
                    "response_time_ms": .string(String(format: "%.2f", responseTime * 1000))
                ])
                return false
            }
            
            // Test basic operations (set/get/delete)
            let testKey = "health_check_test_\(UUID().uuidString)"
            let testValue = "health_check_value"
            
            // Test set operation
            try await redis.set(RedisKey(testKey), to: testValue).get()
            
            // Test get operation
            let retrievedValue = try await redis.get(RedisKey(testKey), as: String.self).get()
            guard retrievedValue == testValue else {
                logger.warning("Redis health check: set/get operation failed")
                return false
            }
            
            // Test delete operation
            let deleted = try await redis.delete([RedisKey(testKey)]).get()
            guard deleted > 0 else {
                logger.warning("Redis health check: delete operation failed")
                return false
            }
            
            // All operations succeeded
            return true
            
        } catch {
            logger.warning("Redis health check failed", metadata: [
                "error": .string(error.localizedDescription)
            ])
            return false
        }
    }
    
    /// Provides a human-readable name for this service's health check.
    public func healthCheckName() -> String {
        "Redis Cache Service"
    }
}

// MARK: - Extensions

extension Array {
    fileprivate subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}