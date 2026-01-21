import Vapor

// MARK: - Service Storage Container

/// Thread-safe container for storing services and repositories in Application storage.
/// Uses @unchecked Sendable because services are initialized once during startup
/// and accessed read-only during request processing.
final class ServiceStorageContainer: @unchecked Sendable {

    // MARK: - Services

    var llmService: LLMService?
    var emailService: EmailService?
    var aiCacheService: AICacheServiceInterface?
    var cacheService: CacheService?
    var ipExtractorService: IPExtractorService?
    var aiInputValidatorService: AIInputValidatorServiceInterface?
    var promptSanitizerService: PromptSanitizerServiceInterface?
    var cacheKeyGeneratorService: CacheKeyGeneratorServiceInterface?
    var randomGeneratorService: RandomGeneratorService?
    var uuidGeneratorService: UUIDGeneratorService?
    var aiResponseValidatorService: AIResponseValidationService?

    // MARK: - Repositories

    var userRepository: (any UserRepository)?
    var refreshTokenRepository: (any RefreshTokenRepository)?
    var emailTokenRepository: (any EmailTokenRepository)?
    var passwordTokenRepository: (any PasswordTokenRepository)?
    var generatedRuleRepository: (any GeneratedRuleRepository)?
    var waitlistRepository: (any WaitlistRepository)?
    var remoteConfigRepository: (any RemoteConfigRepository)?

    init() {}
}

// MARK: - Storage Key

private struct ServiceStorageContainerKey: StorageKey {
    typealias Value = ServiceStorageContainer
}

// MARK: - Application Extensions

extension Application {

    /// Internal service storage container
    var serviceStorage: ServiceStorageContainer {
        get {
            if let existing = storage[ServiceStorageContainerKey.self] {
                return existing
            }
            let container = ServiceStorageContainer()
            storage[ServiceStorageContainerKey.self] = container
            return container
        }
        set {
            storage[ServiceStorageContainerKey.self] = newValue
        }
    }

    // MARK: - Services

    var llmService: LLMService {
        get { serviceStorage.llmService! }
        set { serviceStorage.llmService = newValue }
    }

    var emailService: EmailService {
        get { serviceStorage.emailService! }
        set { serviceStorage.emailService = newValue }
    }

    var aiCacheService: AICacheServiceInterface {
        get { serviceStorage.aiCacheService! }
        set { serviceStorage.aiCacheService = newValue }
    }

    var cacheService: CacheService {
        get { serviceStorage.cacheService! }
        set { serviceStorage.cacheService = newValue }
    }

    var ipExtractorService: IPExtractorService {
        get { serviceStorage.ipExtractorService! }
        set { serviceStorage.ipExtractorService = newValue }
    }

    var aiInputValidatorService: AIInputValidatorServiceInterface {
        get { serviceStorage.aiInputValidatorService! }
        set { serviceStorage.aiInputValidatorService = newValue }
    }

    var promptSanitizerService: PromptSanitizerServiceInterface {
        get { serviceStorage.promptSanitizerService! }
        set { serviceStorage.promptSanitizerService = newValue }
    }

    var cacheKeyGeneratorService: CacheKeyGeneratorServiceInterface {
        get { serviceStorage.cacheKeyGeneratorService! }
        set { serviceStorage.cacheKeyGeneratorService = newValue }
    }

    var randomGeneratorService: RandomGeneratorService {
        get { serviceStorage.randomGeneratorService! }
        set { serviceStorage.randomGeneratorService = newValue }
    }

    var uuidGeneratorService: UUIDGeneratorService {
        get { serviceStorage.uuidGeneratorService! }
        set { serviceStorage.uuidGeneratorService = newValue }
    }

    var aiResponseValidatorService: AIResponseValidationService {
        get { serviceStorage.aiResponseValidatorService! }
        set { serviceStorage.aiResponseValidatorService = newValue }
    }

    // MARK: - Repositories

    var userRepository: any UserRepository {
        get { serviceStorage.userRepository! }
        set { serviceStorage.userRepository = newValue }
    }

    var refreshTokenRepository: any RefreshTokenRepository {
        get { serviceStorage.refreshTokenRepository! }
        set { serviceStorage.refreshTokenRepository = newValue }
    }

    var emailTokenRepository: any EmailTokenRepository {
        get { serviceStorage.emailTokenRepository! }
        set { serviceStorage.emailTokenRepository = newValue }
    }

    var passwordTokenRepository: any PasswordTokenRepository {
        get { serviceStorage.passwordTokenRepository! }
        set { serviceStorage.passwordTokenRepository = newValue }
    }

    var generatedRuleRepository: any GeneratedRuleRepository {
        get { serviceStorage.generatedRuleRepository! }
        set { serviceStorage.generatedRuleRepository = newValue }
    }

    var waitlistRepository: any WaitlistRepository {
        get { serviceStorage.waitlistRepository! }
        set { serviceStorage.waitlistRepository = newValue }
    }

    var remoteConfigRepository: any RemoteConfigRepository {
        get { serviceStorage.remoteConfigRepository! }
        set { serviceStorage.remoteConfigRepository = newValue }
    }
}
