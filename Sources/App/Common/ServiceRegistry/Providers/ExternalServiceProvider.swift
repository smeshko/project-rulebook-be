import Vapor

public struct ExternalServiceProvider: ServiceProvider {
    public static func register(in registry: ServiceContainer, app: Application) async throws {
        // Email Service
        registry.register(EmailService.self) { app in
            BrevoClient(app: app)
        }
        
        // LLM Service  
        registry.register(LLMService.self) { app in
            OpenAIService(app: app)
        }
        
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
        
        // AI Cache Service
        registry.register(AICacheServiceInterface.self) { app in
            InMemoryAICacheService(app: app)
        }
        
        // Prompt Sanitizer Service
        registry.register(PromptSanitizerServiceInterface.self) { app in
            DefaultPromptSanitizerService(app: app)
        }
        
        // AI Input Validator Service
        registry.register(AIInputValidatorServiceInterface.self) { app in
            DefaultAIInputValidatorService(app: app)
        }
        
        // Cache Key Generator Service
        registry.register(CacheKeyGeneratorServiceInterface.self) { app in
            DefaultCacheKeyGeneratorService(app: app)
        }
    }
}