@testable import App
import Foundation
import Vapor

/// Mock AI Cache service for testing with configurable behavior.
///
/// This service implements the AICacheServiceInterface with in-memory storage
/// and configurable hit/miss ratios for testing cache scenarios.
final class MockAICacheService: AICacheServiceInterface, @unchecked Sendable {
    private let application: Application
    private let logger: Logger
    
    // Cache storage
    private var cache: [String: CacheEntry] = [:]
    private var statistics = Statistics()
    
    // Configuration
    private var forceMiss: Bool = false
    private var hitRatio: Double = 1.0  // Default to always hit for predictable testing
    private var maxEntries: Int = 1000
    
    /// Internal cache entry with expiration
    private struct CacheEntry {
        let value: String
        let expiresAt: Date
        
        var isExpired: Bool {
            Date() > expiresAt
        }
    }
    
    /// Internal statistics tracking
    private struct Statistics {
        var hits: Int = 0
        var misses: Int = 0
        
        mutating func recordHit() { hits += 1 }
        mutating func recordMiss() { misses += 1 }
        mutating func reset() { hits = 0; misses = 0 }
    }
    
    init(app: Application) {
        self.application = app
        self.logger = app.logger
    }
    
    // MARK: - Test Configuration Methods
    
    /// Configure the cache to always miss for testing cache miss scenarios.
    func configureForceMiss(_ force: Bool = true) {
        forceMiss = force
        logger.info("MockAICacheService configured to force miss: \(force)")
    }
    
    /// Configure the hit ratio for probabilistic cache behavior testing.
    /// - Parameter ratio: Hit ratio from 0.0 (always miss) to 1.0 (always hit)
    func configureHitRatio(_ ratio: Double) {
        hitRatio = max(0.0, min(1.0, ratio))
        logger.info("MockAICacheService hit ratio set to: \(hitRatio)")
    }
    
    /// Configure maximum entries for capacity testing.
    func configureMaxEntries(_ max: Int) {
        maxEntries = max
        logger.info("MockAICacheService max entries set to: \(max)")
    }
    
    /// Reset all statistics and cache entries.
    func reset() {
        cache.removeAll()
        statistics.reset()
        forceMiss = false
        hitRatio = 1.0
        logger.info("MockAICacheService reset to default state")
    }
    
    /// Manually add a cache entry for testing.
    func setTestEntry(key: String, value: String, ttl: TimeInterval) {
        let expiresAt = Date().addingTimeInterval(ttl)
        cache[key] = CacheEntry(value: value, expiresAt: expiresAt)
    }
    
    // MARK: - AICacheServiceInterface Implementation
    
    func `for`(_ request: Request) -> AICacheServiceInterface {
        return self
    }
    
    func get(key: String) async -> String? {
        // Clean up expired entries
        await cleanupExpired()
        
        // Force miss if configured
        if forceMiss {
            statistics.recordMiss()
            return nil
        }
        
        // Check if entry exists and is not expired
        guard let entry = cache[key], !entry.isExpired else {
            statistics.recordMiss()
            return nil
        }
        
        // Simulate probabilistic hit/miss based on configured ratio
        if hitRatio < 1.0 && Double.random(in: 0...1) > hitRatio {
            statistics.recordMiss()
            return nil
        }
        
        statistics.recordHit()
        return entry.value
    }
    
    func set(key: String, value: String, ttl: TimeInterval) async {
        let expiresAt = Date().addingTimeInterval(ttl)
        cache[key] = CacheEntry(value: value, expiresAt: expiresAt)
        
        // Enforce max entries
        if cache.count > maxEntries {
            // Remove oldest entries (simple FIFO for testing)
            let keysToRemove = Array(cache.keys.prefix(cache.count - maxEntries))
            for key in keysToRemove {
                cache.removeValue(forKey: key)
            }
        }
    }
    
    func exists(key: String) async -> Bool {
        await cleanupExpired()
        guard let entry = cache[key] else { return false }
        return !entry.isExpired
    }
    
    func remove(key: String) async {
        cache.removeValue(forKey: key)
    }
    
    func clear() async {
        cache.removeAll()
        statistics.reset()
    }
    
    func getStatistics() async -> CacheStatistics {
        await cleanupExpired()
        
        return CacheStatistics(
            hits: statistics.hits,
            misses: statistics.misses,
            entryCount: cache.count,
            maxEntries: maxEntries
        )
    }
    
    func cleanupExpired() async {
        let expiredKeys = cache.compactMap { key, entry in
            entry.isExpired ? key : nil
        }
        
        for key in expiredKeys {
            cache.removeValue(forKey: key)
        }
    }
    
    func count() async -> Int {
        await cleanupExpired()
        return cache.count
    }
    
    func getEntriesByType() async -> [AICacheType: [String]] {
        await cleanupExpired()
        
        var result: [AICacheType: [String]] = [:]
        
        for key in cache.keys {
            // All cache entries are rules generation type
            result[.rulesGeneration, default: []].append(key)
        }
        
        return result
    }
}

// MARK: - Service Registration Extension

extension Application.Service.Provider where ServiceType == AICacheServiceInterface {
    /// Provides a mock AI cache service for testing.
    static var mock: Self {
        .init { app in
            app.services.aiCache.use { MockAICacheService(app: $0) }
        }
    }
}