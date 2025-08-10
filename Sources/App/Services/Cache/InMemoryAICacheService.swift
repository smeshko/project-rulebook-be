import Foundation
import Vapor

extension Application.Service.Provider where ServiceType == AICacheServiceInterface {
    static var inMemory: Self {
        .init {
            $0.services.aiCache.use { app in
                do {
                    let cacheConfig = try app.configuration.cache
                    
                    // Convert CacheConfig to CacheConfiguration
                    let configuration = CacheConfiguration(
                        maxEntries: cacheConfig.maxEntries,
                        rulesGenerationTTL: cacheConfig.rulesGenerationTTL,
                        imageAnalysisTTL: cacheConfig.imageAnalysisTTL,
                        cleanupInterval: cacheConfig.cleanupInterval,
                        enableLogging: cacheConfig.enableLogging
                    )
                    
                    // Create the cache service
                    let keyGenerator = DefaultCacheKeyGeneratorService(app: app)
                    let cacheService = InMemoryAICacheService(
                        configuration: configuration,
                        logger: app.logger,
                        keyGenerator: keyGenerator
                    )
                    
                    // Start the cleanup task asynchronously
                    Task {
                        await cacheService.setupCleanupTask()
                    }
                    
                    app.logger.info("AI Cache Service configured", metadata: [
                        "max_entries": .string("\(configuration.maxEntries)"),
                        "rules_ttl": .string("\(configuration.rulesGenerationTTL)s"),
                        "image_ttl": .string("\(configuration.imageAnalysisTTL)s"),
                        "cleanup_interval": .string("\(configuration.cleanupInterval)s"),
                        "logging_enabled": .string("\(configuration.enableLogging)")
                    ])
                    
                    return cacheService
                    
                } catch {
                    app.logger.error("Failed to load cache configuration: \(error)")
                    
                    // Fallback configuration
                    let fallbackConfiguration = CacheConfiguration(
                        maxEntries: 1000,
                        rulesGenerationTTL: 3600,
                        imageAnalysisTTL: 1800,
                        cleanupInterval: 600,
                        enableLogging: true
                    )
                    
                    app.logger.warning("Using fallback cache configuration", metadata: [
                        "max_entries": .string("\(fallbackConfiguration.maxEntries)"),
                        "rules_ttl": .string("\(fallbackConfiguration.rulesGenerationTTL)s"),
                        "image_ttl": .string("\(fallbackConfiguration.imageAnalysisTTL)s"),
                        "cleanup_interval": .string("\(fallbackConfiguration.cleanupInterval)s")
                    ])
                    
                    let keyGenerator = DefaultCacheKeyGeneratorService(app: app)
                    return InMemoryAICacheService(
                        configuration: fallbackConfiguration,
                        logger: app.logger,
                        keyGenerator: keyGenerator
                    )
                }
            }
        }
    }
}

/// Thread-safe in-memory cache implementation with TTL and LRU eviction
/// This actor ensures all cache operations are thread-safe while providing high performance
actor InMemoryAICacheService: AICacheServiceInterface {
    
    // MARK: - Private Properties
    
    /// Internal storage for cache entries
    private var entries: [String: CacheEntry] = [:]
    
    /// LRU access tracking - maps keys to access order
    private var accessOrder: [String] = []
    
    /// Cache configuration
    private let configuration: CacheConfiguration
    
    /// Key generator service for cache operations
    private let keyGenerator: CacheKeyGeneratorServiceInterface
    
    /// Statistics tracking
    private var hitCount: Int = 0
    private var missCount: Int = 0
    
    /// Logger for cache operations
    private let logger: Logger
    
    /// Timer for automatic cleanup
    private var cleanupTask: Task<Void, Never>?
    
    // MARK: - Initialization
    
    /// Initializes the cache service with the given configuration
    /// - Parameters:
    ///   - configuration: Cache configuration settings
    ///   - logger: Logger for cache operations
    init(configuration: CacheConfiguration, logger: Logger, keyGenerator: CacheKeyGeneratorServiceInterface) {
        self.configuration = configuration
        self.logger = logger
        self.keyGenerator = keyGenerator
        
        if configuration.enableLogging {
            logger.info("AI Cache Service initialized", metadata: [
                "max_entries": .string("\(configuration.maxEntries)"),
                "rules_ttl": .string("\(configuration.rulesGenerationTTL)s"),
                "image_ttl": .string("\(configuration.imageAnalysisTTL)s")
            ])
        }
        
        // Cleanup task will be initialized lazily
    }
    
    /// Setup the automatic cleanup task
    func setupCleanupTask() {
        cleanupTask = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .seconds(self?.configuration.cleanupInterval ?? 600))
                    await self?.cleanupExpired()
                } catch {
                    // Task was cancelled, which is expected during shutdown
                    break
                }
            }
        }
    }
    
    deinit {
        cleanupTask?.cancel()
    }
    
    // MARK: - AICacheServiceInterface Implementation
    
    nonisolated func `for`(_ request: Request) -> AICacheServiceInterface {
        let keyGenerator = request.application.services.cacheKeyGenerator.service
        return Self(configuration: configuration, logger: request.logger, keyGenerator: keyGenerator)
    }
    
    func get(key: String) async -> String? {
        // Check if entry exists and is not expired
        guard let entry = entries[key], !entry.isExpired else {
            // Entry doesn't exist or is expired
            if entries[key] != nil {
                // Remove expired entry
                entries.removeValue(forKey: key)
                accessOrder.removeAll { $0 == key }
                
                if configuration.enableLogging {
                    logger.debug("Cache entry expired and removed", metadata: ["key": .string(key)])
                }
            }
            
            missCount += 1
            return nil
        }
        
        // Update access statistics and LRU order
        let updatedEntry = entry.recordAccess()
        entries[key] = updatedEntry
        updateAccessOrder(for: key)
        
        hitCount += 1
        
        if configuration.enableLogging {
            logger.debug("Cache hit", metadata: [
                "key": .string(key),
                "hit_count": .string("\(updatedEntry.hitCount)"),
                "age": .string(String(format: "%.1fs", updatedEntry.age))
            ])
        }
        
        return entry.value
    }
    
    func set(key: String, value: String, ttl: TimeInterval) async {
        let entry = CacheEntry(key: key, value: value, ttl: ttl)
        
        // Check if we need to evict entries to make room
        if entries.count >= configuration.maxEntries && entries[key] == nil {
            await evictLeastRecentlyUsed()
        }
        
        // Store the entry
        entries[key] = entry
        updateAccessOrder(for: key)
        
        if configuration.enableLogging {
            logger.debug("Cache entry stored", metadata: [
                "key": .string(key),
                "ttl": .string("\(ttl)s"),
                "value_size": .string("\(value.count) chars"),
                "total_entries": .string("\(entries.count)")
            ])
        }
    }
    
    func exists(key: String) async -> Bool {
        guard let entry = entries[key] else { return false }
        
        if entry.isExpired {
            entries.removeValue(forKey: key)
            accessOrder.removeAll { $0 == key }
            return false
        }
        
        return true
    }
    
    func remove(key: String) async {
        if entries.removeValue(forKey: key) != nil {
            accessOrder.removeAll { $0 == key }
            
            if configuration.enableLogging {
                logger.debug("Cache entry removed", metadata: ["key": .string(key)])
            }
        }
    }
    
    func clear() async {
        let previousCount = entries.count
        entries.removeAll()
        accessOrder.removeAll()
        
        if configuration.enableLogging {
            logger.info("Cache cleared", metadata: ["removed_entries": .string("\(previousCount)")])
        }
    }
    
    func getStatistics() async -> CacheStatistics {
        return CacheStatistics(
            hits: hitCount,
            misses: missCount,
            entryCount: entries.count,
            maxEntries: configuration.maxEntries
        )
    }
    
    func cleanupExpired() async {
        let initialCount = entries.count
        let now = Date()
        
        var expiredKeys: [String] = []
        
        for (key, entry) in entries {
            if now > entry.expiresAt {
                expiredKeys.append(key)
            }
        }
        
        for key in expiredKeys {
            entries.removeValue(forKey: key)
            accessOrder.removeAll { $0 == key }
        }
        
        let removedCount = expiredKeys.count
        
        if removedCount > 0 && configuration.enableLogging {
            logger.debug("Expired entries cleaned up", metadata: [
                "removed_count": .string("\(removedCount)"),
                "remaining_count": .string("\(entries.count)"),
                "initial_count": .string("\(initialCount)")
            ])
        }
    }
    
    func count() async -> Int {
        return entries.count
    }
    
    // MARK: - Private Helper Methods
    
    /// Updates the access order for LRU tracking
    /// - Parameter key: The cache key that was accessed
    private func updateAccessOrder(for key: String) {
        // Remove key from current position
        accessOrder.removeAll { $0 == key }
        // Add to end (most recently used)
        accessOrder.append(key)
    }
    
    /// Evicts the least recently used entries to make room for new ones
    private func evictLeastRecentlyUsed() async {
        guard !accessOrder.isEmpty else { return }
        
        // Calculate how many entries to evict (10% of max capacity or at least 1)
        let entriesToEvict = max(1, configuration.maxEntries / 10)
        let keysToEvict = Array(accessOrder.prefix(entriesToEvict))
        
        for key in keysToEvict {
            entries.removeValue(forKey: key)
        }
        
        // Remove evicted keys from access order
        accessOrder.removeFirst(keysToEvict.count)
        
        if configuration.enableLogging {
            logger.debug("LRU eviction performed", metadata: [
                "evicted_count": .string("\(keysToEvict.count)"),
                "remaining_count": .string("\(entries.count)")
            ])
        }
    }
    
    // MARK: - Additional Utility Methods
    
    /// Returns detailed cache information for debugging
    func getDetailedInfo() async -> [String: Any] {
        let stats = await getStatistics()
        
        var entryDetails: [[String: Any]] = []
        let now = Date()
        
        for entry in entries.values {
            entryDetails.append([
                "key": entry.key,
                "age": entry.age,
                "ttl_remaining": entry.timeToLive,
                "hit_count": entry.hitCount,
                "last_accessed": entry.lastAccessedAt.timeIntervalSince(now),
                "expired": entry.isExpired
            ])
        }
        
        // Sort by most recently accessed
        entryDetails.sort { lhs, rhs in
            let lhsAccessed = lhs["last_accessed"] as? TimeInterval ?? 0
            let rhsAccessed = rhs["last_accessed"] as? TimeInterval ?? 0
            return lhsAccessed > rhsAccessed
        }
        
        return [
            "statistics": [
                "hits": stats.hits,
                "misses": stats.misses,
                "hit_ratio": stats.hitRatio,
                "entry_count": stats.entryCount,
                "max_entries": stats.maxEntries,
                "utilization": stats.utilization
            ],
            "configuration": [
                "max_entries": configuration.maxEntries,
                "rules_ttl": configuration.rulesGenerationTTL,
                "image_ttl": configuration.imageAnalysisTTL,
                "cleanup_interval": configuration.cleanupInterval,
                "logging_enabled": configuration.enableLogging
            ],
            "entries": entryDetails
        ]
    }
    
    /// Returns cache entries grouped by type
    func getEntriesByType() async -> [AICacheType: [String]] {
        var result: [AICacheType: [String]] = [:]
        
        for key in entries.keys {
            if let type = keyGenerator.extractCacheType(from: key) {
                if result[type] == nil {
                    result[type] = []
                }
                result[type]?.append(key)
            }
        }
        
        return result
    }
}