import Vapor
@preconcurrency import Redis

public struct ExternalServiceProvider: ServiceProvider {
    public static func register(in registry: ServiceContainer, app: Application) async throws {
        // Foundation Services (no dependencies) - register unless already registered in testing
        
        if !registry.isRegistered(RandomGeneratorService.self) {
            // Random Generator Service
            registry.register(RandomGeneratorService.self) { app in
                RealRandomGeneratorService(app: app)
            }
        }
        
        if !registry.isRegistered(UUIDGeneratorService.self) {
            // UUID Generator Service
            registry.register(UUIDGeneratorService.self) { app in
                RealUUIDGeneratorService(app: app)
            }
        }
        
        if !registry.isRegistered(IPExtractorService.self) {
            // IP Extractor Service
            registry.register(IPExtractorService.self) { app in
                DefaultIPExtractorService(app: app)
            }
        }
        
        if !registry.isRegistered(CacheKeyGeneratorServiceInterface.self) {
            // Cache Key Generator Service (no dependencies)
            registry.register(CacheKeyGeneratorServiceInterface.self) { app in
                DefaultCacheKeyGeneratorService(app: app)
            }
        }
        
        if !registry.isRegistered(PromptSanitizerServiceInterface.self) {
            // Prompt Sanitizer Service (no dependencies)
            registry.register(PromptSanitizerServiceInterface.self) { app in
                DefaultPromptSanitizerService(app: app)
            }
        }
        
        if !registry.isRegistered(AIInputValidatorServiceInterface.self) {
            // AI Input Validator Service (no dependencies)
            registry.register(AIInputValidatorServiceInterface.self) { app in
                DefaultAIInputValidatorService(app: app)
            }
        }
        
        // Services with dependencies resolved through ServiceRegistry
        
        if !registry.isRegistered(AICacheServiceInterface.self) {
            // AI Cache Service - requires configuration, logger, and key generator
            registry.register(AICacheServiceInterface.self) { app in
                let cacheConfig = try app.configuration.cache
                let keyGenerator = try await app.serviceRegistry.resolveRequired(CacheKeyGeneratorServiceInterface.self)
                
                // Convert CacheConfig to CacheConfiguration
                let configuration = CacheConfiguration(
                    maxEntries: cacheConfig.maxEntries,
                    rulesGenerationTTL: cacheConfig.rulesGenerationTTL,
                    imageAnalysisTTL: cacheConfig.imageAnalysisTTL,
                    cleanupInterval: cacheConfig.cleanupInterval,
                    enableLogging: cacheConfig.enableLogging
                )
                
                return InMemoryAICacheService(
                    configuration: configuration,
                    logger: app.logger,
                    keyGenerator: keyGenerator
                )
            }
        }
        
        if !registry.isRegistered(EmailService.self) {
            // Email Service
            registry.register(EmailService.self) { app in
                BrevoClient(app: app)
            }
        }
        
        if !registry.isRegistered(LLMService.self) {
            // LLM Service - requires configuration and other services
            registry.register(LLMService.self) { app in
                OpenAIService(app: app)
            }
        }
        
        // Redis Cache Service - always register since there's no test implementation
        if !registry.isRegistered(CacheService.self) {
            registry.register(CacheService.self) { app in
                let redisConfig = try app.configuration.redis
                
                // Configure Redis for the application if not already configured
                if app.redis.configuration == nil {
                    app.redis.configuration = try RedisConfiguration(
                        hostname: redisConfig.host,
                        port: redisConfig.port,
                        password: redisConfig.password,
                        database: redisConfig.database,
                        pool: RedisConfiguration.PoolOptions(
                            maximumConnectionCount: .maximumActiveConnections(redisConfig.poolSize),
                            connectionRetryTimeout: .seconds(Int64(redisConfig.connectionTimeout))
                        )
                    )
                }
                
                return RedisCacheService(
                    redis: app.redis,
                    configuration: redisConfig,
                    logger: app.logger
                )
            }
        }
    }
}