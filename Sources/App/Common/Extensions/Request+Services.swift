import Vapor

// MARK: - Request Service Accessors

/// Service accessor infrastructure for simplified architecture.
/// This provides `req.services.*` access pattern for accessing services
/// and complements `req.repositories.*` (defined in Request+Repository.swift).

extension Request {

    /// Access services via `req.services.llm`, `req.services.email`, etc.
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

    var purchaseValidator: PurchaseValidatorService {
        app.purchaseValidatorService
    }
}
