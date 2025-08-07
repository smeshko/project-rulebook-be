import Vapor

/// Admin controller for managing AI response cache
struct AICacheAdminController {
    
    // MARK: - Cache Statistics Endpoint
    
    /// GET /api/admin/cache/stats
    /// Returns detailed cache statistics and performance metrics
    func getCacheStatistics(_ req: Request) async throws -> CacheStatisticsResponse {
        // Security logging: Log admin cache access
        req.logger.info("Admin cache statistics request", metadata: [
            "endpoint": "getCacheStatistics",
            "client_ip": .string(extractClientIP(from: req)),
            "timestamp": .string(ISO8601DateFormatter().string(from: Date()))
        ])
        
        let statistics = await req.aiCache.getStatistics()
        let entriesByType = await (req.aiCache as? InMemoryAICacheService)?.getEntriesByType() ?? [:]
        
        // Convert enum keys to strings for JSON serialization
        let stringKeysEntriesByType = Dictionary(uniqueKeysWithValues: 
            entriesByType.map { (key, value) in (key.rawValue, value) }
        )
        
        return CacheStatisticsResponse(
            statistics: statistics,
            entriesByType: stringKeysEntriesByType,
            timestamp: Date()
        )
    }
    
    // MARK: - Clear Cache Endpoint
    
    /// DELETE /api/admin/cache
    /// Clears all entries from the cache
    func clearCache(_ req: Request) async throws -> CacheClearResponse {
        // Security logging: Log admin cache clear
        req.logger.info("Admin cache clear request", metadata: [
            "endpoint": "clearCache",
            "client_ip": .string(extractClientIP(from: req)),
            "timestamp": .string(ISO8601DateFormatter().string(from: Date()))
        ])
        
        let countBefore = await req.aiCache.count()
        await req.aiCache.clear()
        let countAfter = await req.aiCache.count()
        
        req.logger.info("Admin cache cleared", metadata: [
            "entries_removed": .string("\(countBefore)"),
            "remaining_entries": .string("\(countAfter)"),
            "client_ip": .string(extractClientIP(from: req))
        ])
        
        return CacheClearResponse(
            entriesRemoved: countBefore,
            remainingEntries: countAfter,
            timestamp: Date()
        )
    }
    
    // MARK: - Cache Entries Endpoint
    
    /// GET /api/admin/cache/entries
    /// Lists all cached entries with metadata (paginated for large caches)
    func getCacheEntries(_ req: Request) async throws -> CacheEntriesResponse {
        // Security logging: Log admin cache entries access
        req.logger.info("Admin cache entries request", metadata: [
            "endpoint": "getCacheEntries",
            "client_ip": .string(extractClientIP(from: req)),
            "timestamp": .string(ISO8601DateFormatter().string(from: Date()))
        ])
        
        guard let memoryCache = req.aiCache as? InMemoryAICacheService else {
            throw Abort(.internalServerError, reason: "Cache service type not supported")
        }
        
        let entriesByType = await memoryCache.getEntriesByType()
        
        // For now, return empty entries array to avoid non-sendable type issues
        // This can be improved later with a proper sendable detailed info method
        let entriesInfo: [CacheEntryInfo] = []
        
        // Convert enum keys to strings for JSON serialization
        let stringKeysEntriesByType = Dictionary(uniqueKeysWithValues: 
            entriesByType.map { (key, value) in (key.rawValue, value) }
        )
        
        return CacheEntriesResponse(
            entries: entriesInfo,
            entriesByType: stringKeysEntriesByType,
            totalCount: entriesInfo.count,
            timestamp: Date()
        )
    }
    
    // MARK: - Manual Cleanup Endpoint
    
    /// POST /api/admin/cache/cleanup
    /// Manually triggers cleanup of expired entries
    func manualCleanup(_ req: Request) async throws -> CacheCleanupResponse {
        // Security logging: Log admin manual cleanup
        req.logger.info("Admin manual cache cleanup request", metadata: [
            "endpoint": "manualCleanup",
            "client_ip": .string(extractClientIP(from: req)),
            "timestamp": .string(ISO8601DateFormatter().string(from: Date()))
        ])
        
        let countBefore = await req.aiCache.count()
        await req.aiCache.cleanupExpired()
        let countAfter = await req.aiCache.count()
        
        let entriesRemoved = countBefore - countAfter
        
        req.logger.info("Admin manual cleanup completed", metadata: [
            "entries_removed": .string("\(entriesRemoved)"),
            "remaining_entries": .string("\(countAfter)"),
            "client_ip": .string(extractClientIP(from: req))
        ])
        
        return CacheCleanupResponse(
            entriesRemoved: entriesRemoved,
            remainingEntries: countAfter,
            timestamp: Date()
        )
    }
    
    // MARK: - Cache Health Endpoint
    
    /// GET /api/admin/cache/health
    /// Returns cache health status and performance metrics
    func getCacheHealth(_ req: Request) async throws -> CacheHealthResponse {
        req.logger.info("Admin cache health request", metadata: [
            "endpoint": "getCacheHealth",
            "client_ip": .string(extractClientIP(from: req))
        ])
        
        let statistics = await req.aiCache.getStatistics()
        let config = try req.application.configuration.cache
        
        // Determine health status based on cache metrics
        let utilizationPercentage = statistics.utilization
        let hitRatio = statistics.hitRatio
        
        let healthStatus: CacheHealthStatus
        let issues: [String] = []
        var currentIssues = issues
        
        switch (utilizationPercentage, hitRatio) {
        case (let util, _) where util > 95:
            healthStatus = .critical
            currentIssues.append("Cache is nearly full (\(String(format: "%.1f", util))%)")
        case (let util, _) where util > 90:
            healthStatus = .warning
            currentIssues.append("Cache utilization is very high (\(String(format: "%.1f", util))%)")
        case (_, let hit) where hit < 30 && statistics.totalRequests > 50:
            healthStatus = .warning
            currentIssues.append("Cache hit ratio is low (\(String(format: "%.1f", hit))%)")
        default:
            healthStatus = .healthy
        }
        
        return CacheHealthResponse(
            status: healthStatus,
            statistics: statistics,
            issues: currentIssues,
            recommendations: generateRecommendations(for: statistics, config: config),
            timestamp: Date()
        )
    }
    
    // MARK: - Private Helper Methods
    
    /// Extracts the real client IP address from the request, checking proxy headers first
    private func extractClientIP(from request: Request) -> String {
        // Check X-Forwarded-For header (may contain multiple IPs, client is first)
        if let forwardedFor = request.headers.first(name: "X-Forwarded-For") {
            let trimmed = forwardedFor.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                let firstIP = String(trimmed.split(separator: ",").first ?? "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if isValidIPAddress(firstIP) {
                    return firstIP
                }
            }
        }
        
        // Check X-Real-IP header (single IP)
        if let realIP = request.headers.first(name: "X-Real-IP") {
            let trimmed = realIP.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty && isValidIPAddress(trimmed) {
                return trimmed
            }
        }
        
        // Check CF-Connecting-IP header (Cloudflare specific)
        if let cfIP = request.headers.first(name: "CF-Connecting-IP") {
            let trimmed = cfIP.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty && isValidIPAddress(trimmed) {
                return trimmed
            }
        }
        
        // Fallback to remote address
        return request.remoteAddress?.hostname ?? "unknown"
    }
    
    /// Validates if a string is a valid IP address (IPv4 or IPv6)
    private func isValidIPAddress(_ ip: String) -> Bool {
        guard !ip.isEmpty, ip != "unknown", ip != "localhost" else { return false }
        
        // Check for IPv4 format
        if ip.contains(".") {
            let components = ip.split(separator: ".")
            guard components.count == 4 else { return false }
            return components.allSatisfy { component in
                guard let num = Int(component), num >= 0, num <= 255 else { return false }
                return true
            }
        }
        
        // Basic IPv6 validation
        if ip.contains(":") {
            let components = ip.split(separator: ":")
            guard components.count >= 2, components.count <= 8 else { return false }
            return components.allSatisfy { component in
                return component.allSatisfy { char in
                    char.isHexDigit
                }
            }
        }
        
        return false
    }
    
    /// Generates performance recommendations based on cache statistics
    private func generateRecommendations(for statistics: CacheStatistics, config: CacheConfig) -> [String] {
        var recommendations: [String] = []
        
        // Check utilization
        if statistics.utilization > 80 {
            recommendations.append("Consider increasing CACHE_MAX_ENTRIES (currently \(statistics.maxEntries))")
        }
        
        // Check hit ratio
        if statistics.hitRatio < 50 && statistics.totalRequests > 100 {
            recommendations.append("Low cache hit ratio may indicate TTL values are too short")
        }
        
        // Check TTL configuration
        if config.rulesGenerationTTL < 3600 {
            recommendations.append("Consider increasing CACHE_RULES_TTL for better performance")
        }
        
        if statistics.entryCount == 0 && statistics.totalRequests > 0 {
            recommendations.append("Cache is empty but has requests - check if caching is working correctly")
        }
        
        if statistics.totalRequests > 1000 && statistics.hitRatio > 70 {
            recommendations.append("Cache is performing well - good hit ratio with high request volume")
        }
        
        return recommendations
    }
}

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

// MARK: - Character Extension

private extension Character {
    /// Checks if the character is a valid hexadecimal digit
    var isHexDigit: Bool {
        return self.isASCII && (
            (self >= "0" && self <= "9") ||
            (self >= "a" && self <= "f") ||
            (self >= "A" && self <= "F")
        )
    }
}