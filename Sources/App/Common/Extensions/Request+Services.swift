import Vapor

// MARK: - Request Service Accessors

/// New service accessor infrastructure for simplified architecture.
/// This provides `req.services.*` access pattern alongside the existing
/// `req.repositories.*` pattern (defined in Request+Repository.swift).
///
/// During migration, both patterns coexist:
/// - Old: `req.application.serviceCache.llmService`
/// - New: `req.services.llm`
///
/// After migration completes, the ServiceCache will be removed.

extension Request {

    /// Access services via `req.services.llm`, `req.services.email`, etc.
    /// This is the new simplified accessor pattern replacing ServiceRegistry.
    var services: RequestServices {
        RequestServices(app: application)
    }
}

// MARK: - Services Accessor Struct

/// Provides synchronous access to all services via the Application storage.
/// Named `RequestServices` to avoid conflict with any existing `Services` types.
struct RequestServices: @unchecked Sendable {
    let app: Application

    var llm: LLMService {
        app.llmService
    }

    var email: EmailService {
        app.emailService
    }

    var aiCache: AICacheServiceInterface {
        app.aiCacheService
    }

    var cache: CacheService {
        app.cacheService
    }

    var ipExtractor: IPExtractorService {
        app.ipExtractorService
    }

    var aiInputValidator: AIInputValidatorServiceInterface {
        app.aiInputValidatorService
    }

    var promptSanitizer: PromptSanitizerServiceInterface {
        app.promptSanitizerService
    }

    var cacheKeyGenerator: CacheKeyGeneratorServiceInterface {
        app.cacheKeyGeneratorService
    }

    var randomGenerator: RandomGeneratorService {
        app.randomGeneratorService
    }

    var uuidGenerator: UUIDGeneratorService {
        app.uuidGeneratorService
    }

    var aiResponseValidator: AIResponseValidationService {
        app.aiResponseValidatorService
    }
}
