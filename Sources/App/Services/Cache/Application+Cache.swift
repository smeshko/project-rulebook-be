import Vapor

extension Application {
    // MARK: - AI Cache Service Storage
    
    private struct AICacheKey: StorageKey {
        typealias Value = AICacheServiceInterface
    }
    
    public var aiCache: AICacheServiceInterface {
        get {
            guard let cache = storage[AICacheKey.self] else {
                fatalError("AICacheService not configured. Please call app.setupAICache() during startup.")
            }
            return cache
        }
        set {
            storage[AICacheKey.self] = newValue
        }
    }
    
    // MARK: - Setup Method
    
    /// Configures and initializes the AI cache service
    public func setupAICache() throws {
        let cacheConfig = try configuration.cache
        
        // Convert CacheConfig to CacheConfiguration
        let configuration = CacheConfiguration(
            maxEntries: cacheConfig.maxEntries,
            rulesGenerationTTL: cacheConfig.rulesGenerationTTL,
            imageAnalysisTTL: cacheConfig.imageAnalysisTTL,
            cleanupInterval: cacheConfig.cleanupInterval,
            enableLogging: cacheConfig.enableLogging
        )
        
        // Create the cache service
        let cacheService = InMemoryAICacheService(
            configuration: configuration,
            logger: logger
        )
        
        // Register the service
        aiCache = cacheService
        
        // Start the cleanup task asynchronously
        Task {
            await cacheService.setupCleanupTask()
        }
        
        logger.info("AI Cache Service configured", metadata: [
            "max_entries": .string("\(configuration.maxEntries)"),
            "rules_ttl": .string("\(configuration.rulesGenerationTTL)s"),
            "image_ttl": .string("\(configuration.imageAnalysisTTL)s"),
            "cleanup_interval": .string("\(configuration.cleanupInterval)s"),
            "logging_enabled": .string("\(configuration.enableLogging)")
        ])
    }
}

extension Request {
    /// Provides access to the AI cache service from request context
    public var aiCache: AICacheServiceInterface {
        return application.aiCache
    }
}