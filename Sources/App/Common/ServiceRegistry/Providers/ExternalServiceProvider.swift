import Vapor

public struct ExternalServiceProvider: ServiceProvider {
    public static func register(in registry: ServiceContainer, app: Application) async throws {
        // Foundation Services (no dependencies)
        
        // Random Generator Service
        registry.register(RandomGeneratorService.self) { app in
            RealRandomGeneratorService(app: app)
        }
        
        // UUID Generator Service
        registry.register(UUIDGeneratorService.self) { app in
            RealUUIDGeneratorService(app: app)
        }
        
        // IP Extractor Service
        registry.register(IPExtractorService.self) { app in
            DefaultIPExtractorService(app: app)
        }
        
        // Cache Key Generator Service (no dependencies)
        registry.register(CacheKeyGeneratorServiceInterface.self) { app in
            DefaultCacheKeyGeneratorService(app: app)
        }
        
        // Prompt Sanitizer Service (no dependencies)
        registry.register(PromptSanitizerServiceInterface.self) { app in
            DefaultPromptSanitizerService(app: app)
        }
        
        // AI Input Validator Service (no dependencies)
        registry.register(AIInputValidatorServiceInterface.self) { app in
            DefaultAIInputValidatorService(app: app)
        }
        
        // Services with dependencies resolved through ServiceRegistry
        
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
        
        // Email Service
        registry.register(EmailService.self) { app in
            BrevoClient(app: app)
        }
        
        // LLM Service - requires configuration and other services
        registry.register(LLMService.self) { app in
            OpenAIService(app: app)
        }
    }
}