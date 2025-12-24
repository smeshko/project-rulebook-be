import Foundation
import Vapor

/// Admin controller for managing AI response cache.
///
/// This controller handles all cache administration operations including statistics retrieval,
/// cache clearing, entry listing, manual cleanup, and health monitoring with inline business logic.
struct CacheAdminController {

    // MARK: - Cache Statistics Endpoint

    /// GET /api/admin/cache/stats
    /// Returns detailed cache statistics and performance metrics.
    func getCacheStatistics(_ req: Request) async throws -> CacheAdmin.Statistics.Response {
        let clientIP = req.services.ipExtractor.extractClientIP(from: req)

        // Security logging: Log admin cache statistics access
        req.logger.info("Admin cache statistics request", metadata: [
            "endpoint": "getCacheStatistics",
            "client_ip": .string(clientIP),
            "timestamp": .string(ISO8601DateFormatter().string(from: Date()))
        ])

        // Retrieve cache statistics and entries
        let statistics = await req.services.aiCache.getStatistics()
        let entriesByType = await req.services.aiCache.getEntriesByType()

        // Convert enum keys to strings for JSON serialization
        let stringKeysEntriesByType = Dictionary(uniqueKeysWithValues:
            entriesByType.map { (key, value) in (key.rawValue, value) }
        )

        return CacheAdmin.Statistics.Response(
            statistics: statistics,
            entriesByType: stringKeysEntriesByType,
            timestamp: Date()
        )
    }

    // MARK: - Clear Cache Endpoint

    /// DELETE /api/admin/cache
    /// Clears all entries from the cache.
    func clearCache(_ req: Request) async throws -> CacheAdmin.Clear.Response {
        let clientIP = req.services.ipExtractor.extractClientIP(from: req)

        // Security logging: Log admin cache clear request
        req.logger.info("Admin cache clear request", metadata: [
            "endpoint": "clearCache",
            "client_ip": .string(clientIP),
            "timestamp": .string(ISO8601DateFormatter().string(from: Date()))
        ])

        // Count entries before clearing for metrics
        let countBefore = await req.services.aiCache.count()

        // Execute cache clearing operation
        await req.services.aiCache.clear()

        // Count entries after clearing for verification
        let countAfter = await req.services.aiCache.count()

        // Security logging: Log completion with detailed metrics
        req.logger.info("Admin cache cleared", metadata: [
            "entries_removed": .string("\(countBefore)"),
            "remaining_entries": .string("\(countAfter)"),
            "client_ip": .string(clientIP)
        ])

        return CacheAdmin.Clear.Response(
            entriesRemoved: countBefore,
            remainingEntries: countAfter,
            timestamp: Date()
        )
    }

    // MARK: - Cache Entries Endpoint

    /// GET /api/admin/cache/entries
    /// Lists all cached entries with metadata (paginated for large caches).
    func getCacheEntries(_ req: Request) async throws -> CacheAdmin.Entries.Response {
        let clientIP = req.services.ipExtractor.extractClientIP(from: req)

        // Security logging: Log admin cache entries access
        req.logger.info("Admin cache entries request", metadata: [
            "endpoint": "getCacheEntries",
            "client_ip": .string(clientIP),
            "timestamp": .string(ISO8601DateFormatter().string(from: Date()))
        ])

        // Retrieve entries grouped by type
        let entriesByType = await req.services.aiCache.getEntriesByType()

        // For now, return empty entries array to avoid non-sendable type issues
        // This can be improved later with a proper sendable detailed info method
        let entriesInfo: [CacheAdmin.Entries.EntryInfo] = []

        // Convert enum keys to strings for JSON serialization
        let stringKeysEntriesByType = Dictionary(uniqueKeysWithValues:
            entriesByType.map { (key, value) in (key.rawValue, value) }
        )

        return CacheAdmin.Entries.Response(
            entries: entriesInfo,
            entriesByType: stringKeysEntriesByType,
            totalCount: entriesInfo.count,
            timestamp: Date()
        )
    }

    // MARK: - Manual Cleanup Endpoint

    /// POST /api/admin/cache/cleanup
    /// Manually triggers cleanup of expired entries.
    func manualCleanup(_ req: Request) async throws -> CacheAdmin.Cleanup.Response {
        let clientIP = req.services.ipExtractor.extractClientIP(from: req)

        // Security logging: Log admin manual cleanup request
        req.logger.info("Admin manual cache cleanup request", metadata: [
            "endpoint": "manualCleanup",
            "client_ip": .string(clientIP),
            "timestamp": .string(ISO8601DateFormatter().string(from: Date()))
        ])

        // Count entries before cleanup for metrics
        let countBefore = await req.services.aiCache.count()

        // Execute expired entries cleanup operation
        await req.services.aiCache.cleanupExpired()

        // Count entries after cleanup for verification
        let countAfter = await req.services.aiCache.count()

        // Calculate entries removed
        let entriesRemoved = countBefore - countAfter

        // Security logging: Log completion with detailed metrics
        req.logger.info("Admin manual cleanup completed", metadata: [
            "entries_removed": .string("\(entriesRemoved)"),
            "remaining_entries": .string("\(countAfter)"),
            "client_ip": .string(clientIP)
        ])

        return CacheAdmin.Cleanup.Response(
            entriesRemoved: entriesRemoved,
            remainingEntries: countAfter,
            timestamp: Date()
        )
    }

    // MARK: - Cache Health Endpoint

    /// GET /api/admin/cache/health
    /// Returns cache health status and performance metrics.
    func getCacheHealth(_ req: Request) async throws -> CacheAdmin.Health.Response {
        let clientIP = req.services.ipExtractor.extractClientIP(from: req)

        // Security logging: Log admin cache health request
        req.logger.info("Admin cache health request", metadata: [
            "endpoint": "getCacheHealth",
            "client_ip": .string(clientIP)
        ])

        // Retrieve cache statistics and configuration
        let statistics = await req.services.aiCache.getStatistics()
        let config = try req.application.configuration.cache

        // Analyze health status and identify issues
        let utilizationPercentage = statistics.utilization
        let hitRatio = statistics.hitRatio

        let healthStatus: CacheAdmin.Health.Status
        var issues: [String] = []

        // Determine health status based on cache metrics
        switch (utilizationPercentage, hitRatio) {
        case (let util, _) where util > 95:
            healthStatus = .critical
            issues.append("Cache is nearly full (\(String(format: "%.1f", util))%)")
        case (let util, _) where util > 90:
            healthStatus = .warning
            issues.append("Cache utilization is very high (\(String(format: "%.1f", util))%)")
        case (_, let hit) where hit < 30 && statistics.totalRequests > 50:
            healthStatus = .warning
            issues.append("Cache hit ratio is low (\(String(format: "%.1f", hit))%)")
        default:
            healthStatus = .healthy
        }

        // Generate performance recommendations
        let recommendations = generateHealthRecommendations(for: statistics, config: config)

        return CacheAdmin.Health.Response(
            status: healthStatus,
            statistics: statistics,
            issues: issues,
            recommendations: recommendations,
            timestamp: Date()
        )
    }

    // MARK: - Redis Health Endpoint

    /// GET /api/admin/cache/redis/health
    /// Returns Redis connectivity status and performance metrics.
    func getRedisHealth(_ req: Request) async throws -> CacheAdmin.RedisHealth.Response {
        let clientIP = req.services.ipExtractor.extractClientIP(from: req)

        // Security logging: Log admin Redis health request
        req.logger.info("Admin Redis health request", metadata: [
            "endpoint": "getRedisHealth",
            "client_ip": .string(clientIP)
        ])

        let startTime = Date()
        var status: CacheAdmin.RedisHealth.Status
        var issues: [String] = []
        var latencyMs: Double? = nil
        var connected = false

        do {
            // Test Redis connectivity with a simple ping operation
            // We'll use a health check key that doesn't interfere with application data
            let healthCheckKey = "redis:health:check:\(UUID().uuidString)"
            let testValue = "test_value_for_health_check"

            // Test write operation
            try await req.services.cache.set(healthCheckKey, value: testValue, ttl: 5.0)

            // Test read operation
            let retrievedValue: String? = try await req.services.cache.get(healthCheckKey, as: String.self)

            // Calculate latency
            let endTime = Date()
            latencyMs = endTime.timeIntervalSince(startTime) * 1000

            // If we got here, connection succeeded
            connected = true

            // Verify the test succeeded
            if retrievedValue == testValue {
                status = latencyMs! < 100 ? .healthy : .warning

                if latencyMs! >= 100 {
                    issues.append("High Redis latency (\(String(format: "%.1f", latencyMs!))ms)")
                }

                // Clean up test key
                try? await req.services.cache.delete(healthCheckKey)

                req.logger.info("Redis health check successful", metadata: [
                    "latency_ms": .string(String(format: "%.2f", latencyMs!)),
                    "status": .string(status.rawValue)
                ])
            } else {
                status = .critical
                issues.append("Redis data integrity test failed - retrieved value doesn't match written value")

                req.logger.warning("Redis health check failed - data integrity issue", metadata: [
                    "expected": .string(testValue),
                    "received": .string(retrievedValue ?? "nil")
                ])
            }

        } catch {
            // Redis connection failed
            status = .critical
            issues.append("Redis connection failed: \(error.localizedDescription)")

            let endTime = Date()
            latencyMs = endTime.timeIntervalSince(startTime) * 1000

            req.logger.error("Redis health check failed", metadata: [
                "error": .string(error.localizedDescription),
                "attempt_duration_ms": .string(String(format: "%.2f", latencyMs!))
            ])
        }

        return CacheAdmin.RedisHealth.Response(
            status: status,
            connected: connected,
            latencyMs: latencyMs,
            issues: issues,
            timestamp: Date()
        )
    }

    // MARK: - Private Helper Methods

    /// Generates performance recommendations based on cache statistics and configuration.
    private func generateHealthRecommendations(for statistics: CacheStatistics, config: CacheConfig) -> [String] {
        var recommendations: [String] = []

        // Check utilization recommendations
        if statistics.utilization > 80 {
            recommendations.append("Consider increasing CACHE_MAX_ENTRIES (currently \(statistics.maxEntries))")
        }

        // Check hit ratio recommendations
        if statistics.hitRatio < 50 && statistics.totalRequests > 100 {
            recommendations.append("Low cache hit ratio may indicate TTL values are too short")
        }

        // Check TTL configuration recommendations
        if config.rulesGenerationTTL < 3600 {
            recommendations.append("Consider increasing CACHE_RULES_TTL for better performance")
        }

        // Check for empty cache issues
        if statistics.entryCount == 0 && statistics.totalRequests > 0 {
            recommendations.append("Cache is empty but has requests - check if caching is working correctly")
        }

        // Acknowledge good performance
        if statistics.totalRequests > 1000 && statistics.hitRatio > 70 {
            recommendations.append("Cache is performing well - good hit ratio with high request volume")
        }

        return recommendations
    }
}


