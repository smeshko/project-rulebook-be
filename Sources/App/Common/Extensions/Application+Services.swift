import Vapor

// MARK: - Service Storage Container

/// Thread-safe container for storing services and repositories in Application storage.
/// Uses @unchecked Sendable because services are initialized once during startup
/// and accessed read-only during request processing.
final class ServiceStorageContainer: @unchecked Sendable {

    // MARK: - Services

    var llmService: LLMService?
    var primaryLLMService: LLMService?
    var secondaryLLMService: LLMService?
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
    var remoteConfigCacheService: RemoteConfigCacheService?
    var appStoreValidationService: AppStoreValidationService?
    var playStoreValidationService: PlayStoreValidationService?
    var appleNotificationService: AppleNotificationService?
    var googleNotificationService: GoogleNotificationService?
    var pendingValidationJob: PendingValidationJob?
    var cacheWarmingJob: CacheWarmingJob?

    // MARK: - Repositories

    var userRepository: (any UserRepository)?
    var refreshTokenRepository: (any RefreshTokenRepository)?
    var emailTokenRepository: (any EmailTokenRepository)?
    var passwordTokenRepository: (any PasswordTokenRepository)?
    var generatedRuleRepository: (any GeneratedRuleRepository)?
    var waitlistRepository: (any WaitlistRepository)?
    var remoteConfigRepository: (any RemoteConfigRepository)?
    var receiptsRepository: (any ReceiptsRepository)?
    var feedbackRepository: (any FeedbackRepository)?
    var gameRequestStatsRepository: (any GameRequestStatsRepository)?

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

    /// The primary LLM service used by the fallback orchestrator.
    ///
    /// Exposed so admin endpoints or background jobs can bypass the fallback
    /// and target a specific model if a need arises. Production controllers
    /// should continue to use `llmService` (the fallback-wrapped accessor).
    var primaryLLMService: LLMService {
        get { serviceStorage.primaryLLMService! }
        set { serviceStorage.primaryLLMService = newValue }
    }

    /// The secondary (fallback) LLM service used by the fallback orchestrator.
    var secondaryLLMService: LLMService {
        get { serviceStorage.secondaryLLMService! }
        set { serviceStorage.secondaryLLMService = newValue }
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

    var appStoreValidationService: AppStoreValidationService {
        get { serviceStorage.appStoreValidationService! }
        set { serviceStorage.appStoreValidationService = newValue }
    }

    var playStoreValidationService: PlayStoreValidationService {
        get { serviceStorage.playStoreValidationService! }
        set { serviceStorage.playStoreValidationService = newValue }
    }

    var appleNotificationService: AppleNotificationService {
        get { serviceStorage.appleNotificationService! }
        set { serviceStorage.appleNotificationService = newValue }
    }

    var googleNotificationService: GoogleNotificationService {
        get { serviceStorage.googleNotificationService! }
        set { serviceStorage.googleNotificationService = newValue }
    }

    // MARK: - Background Jobs

    var pendingValidationJob: PendingValidationJob? {
        get { serviceStorage.pendingValidationJob }
        set { serviceStorage.pendingValidationJob = newValue }
    }

    var cacheWarmingJob: CacheWarmingJob? {
        get { serviceStorage.cacheWarmingJob }
        set { serviceStorage.cacheWarmingJob = newValue }
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

    var receiptsRepository: any ReceiptsRepository {
        get { serviceStorage.receiptsRepository! }
        set { serviceStorage.receiptsRepository = newValue }
    }

    var feedbackRepository: any FeedbackRepository {
        get { serviceStorage.feedbackRepository! }
        set { serviceStorage.feedbackRepository = newValue }
    }

    var gameRequestStatsRepository: any GameRequestStatsRepository {
        get { serviceStorage.gameRequestStatsRepository! }
        set { serviceStorage.gameRequestStatsRepository = newValue }
    }
}
