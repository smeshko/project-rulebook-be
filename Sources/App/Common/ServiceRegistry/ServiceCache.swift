import Vapor

/// Thread-safe cache for pre-resolved services enabling synchronous access patterns.
///
/// This cache stores frequently accessed services that have been pre-resolved during
/// application startup, allowing the convenient service accessors to work synchronously
/// while leveraging the ServiceRegistry for dependency injection.
///
/// ## Architecture Benefits
/// - **Synchronous Access**: Enables `request.services.llm` synchronous property access
/// - **Performance**: Eliminates repeated async resolution during request processing  
/// - **Compatibility**: Preserves existing service accessor API without breaking changes
/// - **Memory Efficiency**: Services are resolved once and reused across all requests
///
/// ## Cache Strategy
/// Services are pre-resolved during application startup and cached for immediate
/// synchronous access. This approach balances memory usage with performance while
/// maintaining API compatibility.
///
/// ## Thread Safety
/// All cache operations are thread-safe and can be accessed concurrently from
/// multiple request processing threads without synchronization concerns.
final class ServiceCache: @unchecked Sendable {
    
    // MARK: - Repository Cache
    
    /// Cached user repository for immediate synchronous access.
    private let _userRepository: any UserRepository
    
    /// Cached email token repository for immediate synchronous access.
    private let _emailTokenRepository: any EmailTokenRepository
    
    /// Cached refresh token repository for immediate synchronous access.
    private let _refreshTokenRepository: any RefreshTokenRepository
    
    /// Cached password token repository for immediate synchronous access.
    private let _passwordTokenRepository: any PasswordTokenRepository

    /// Cached generated rule repository for immediate synchronous access.
    private let _generatedRuleRepository: any GeneratedRuleRepository
    
    // MARK: - Service Cache
    
    /// Cached email service for immediate synchronous access.
    private let _emailService: EmailService
    
    /// Cached LLM service for immediate synchronous access.
    private let _llmService: LLMService
    
    /// Cached AI cache service for immediate synchronous access.
    private let _aiCacheService: AICacheServiceInterface
    
    /// Cached general cache service for immediate synchronous access.
    private let _cacheService: CacheService
    
    /// Cached random generator service for immediate synchronous access.
    private let _randomGeneratorService: RandomGeneratorService
    
    /// Cached UUID generator service for immediate synchronous access.
    private let _uuidGeneratorService: UUIDGeneratorService
    
    /// Cached IP extractor service for immediate synchronous access.
    private let _ipExtractorService: IPExtractorService
    
    /// Cached prompt sanitizer service for immediate synchronous access.
    private let _promptSanitizerService: PromptSanitizerServiceInterface
    
    /// Cached AI input validator service for immediate synchronous access.
    private let _aiInputValidatorService: AIInputValidatorServiceInterface
    
    /// Cached cache key generator service for immediate synchronous access.
    private let _cacheKeyGeneratorService: CacheKeyGeneratorServiceInterface
    
    // MARK: - Initialization
    
    /// Initializes the service cache with pre-resolved services from ServiceRegistry.
    ///
    /// This initializer should be called during application startup after all services
    /// have been registered in the ServiceRegistry. It pre-resolves all frequently
    /// accessed services and stores them for immediate synchronous access.
    ///
    /// ## Initialization Process
    /// 1. Resolves all repositories from ServiceRegistry
    /// 2. Resolves all external services from ServiceRegistry  
    /// 3. Validates all services are available and properly configured
    /// 4. Caches services for immediate synchronous access
    ///
    /// - Parameters:
    ///   - userRepository: Pre-resolved user repository
    ///   - emailTokenRepository: Pre-resolved email token repository
    ///   - refreshTokenRepository: Pre-resolved refresh token repository
    ///   - passwordTokenRepository: Pre-resolved password token repository
    ///   - emailService: Pre-resolved email service
    ///   - llmService: Pre-resolved LLM service
    ///   - aiCacheService: Pre-resolved AI cache service
    ///   - cacheService: Pre-resolved general cache service
    ///   - randomGeneratorService: Pre-resolved random generator service
    ///   - uuidGeneratorService: Pre-resolved UUID generator service
    ///   - ipExtractorService: Pre-resolved IP extractor service
    ///   - promptSanitizerService: Pre-resolved prompt sanitizer service
    ///   - aiInputValidatorService: Pre-resolved AI input validator service
    ///   - cacheKeyGeneratorService: Pre-resolved cache key generator service
    init(
        userRepository: any UserRepository,
        emailTokenRepository: any EmailTokenRepository,
        refreshTokenRepository: any RefreshTokenRepository,
        passwordTokenRepository: any PasswordTokenRepository,
        generatedRuleRepository: any GeneratedRuleRepository,
        emailService: EmailService,
        llmService: LLMService,
        aiCacheService: AICacheServiceInterface,
        cacheService: CacheService,
        randomGeneratorService: RandomGeneratorService,
        uuidGeneratorService: UUIDGeneratorService,
        ipExtractorService: IPExtractorService,
        promptSanitizerService: PromptSanitizerServiceInterface,
        aiInputValidatorService: AIInputValidatorServiceInterface,
        cacheKeyGeneratorService: CacheKeyGeneratorServiceInterface
    ) {
        self._userRepository = userRepository
        self._emailTokenRepository = emailTokenRepository
        self._refreshTokenRepository = refreshTokenRepository
        self._passwordTokenRepository = passwordTokenRepository
        self._generatedRuleRepository = generatedRuleRepository
        self._emailService = emailService
        self._llmService = llmService
        self._aiCacheService = aiCacheService
        self._cacheService = cacheService
        self._randomGeneratorService = randomGeneratorService
        self._uuidGeneratorService = uuidGeneratorService
        self._ipExtractorService = ipExtractorService
        self._promptSanitizerService = promptSanitizerService
        self._aiInputValidatorService = aiInputValidatorService
        self._cacheKeyGeneratorService = cacheKeyGeneratorService
    }
    
    // MARK: - Repository Access
    
    /// Returns the cached user repository for immediate synchronous access.
    ///
    /// This method provides synchronous access to the pre-resolved user repository,
    /// enabling existing service accessor patterns to continue working without
    /// modification while using ServiceRegistry under the hood.
    ///
    /// - Returns: The cached user repository instance
    var userRepository: any UserRepository {
        _userRepository
    }
    
    /// Returns the cached email token repository for immediate synchronous access.
    ///
    /// - Returns: The cached email token repository instance
    var emailTokenRepository: any EmailTokenRepository {
        _emailTokenRepository
    }
    
    /// Returns the cached refresh token repository for immediate synchronous access.
    ///
    /// - Returns: The cached refresh token repository instance
    var refreshTokenRepository: any RefreshTokenRepository {
        _refreshTokenRepository
    }
    
    /// Returns the cached password token repository for immediate synchronous access.
    ///
    /// - Returns: The cached password token repository instance
    var passwordTokenRepository: any PasswordTokenRepository {
        _passwordTokenRepository
    }

    /// Returns the cached generated rule repository for immediate synchronous access.
    ///
    /// - Returns: The cached generated rule repository instance
    var generatedRuleRepository: any GeneratedRuleRepository {
        _generatedRuleRepository
    }
    
    // MARK: - Service Access
    
    /// Returns the cached email service for immediate synchronous access.
    ///
    /// - Returns: The cached email service instance
    var emailService: EmailService {
        _emailService
    }
    
    /// Returns the cached LLM service for immediate synchronous access.
    ///
    /// - Returns: The cached LLM service instance
    var llmService: LLMService {
        _llmService
    }
    
    /// Returns the cached AI cache service for immediate synchronous access.
    ///
    /// - Returns: The cached AI cache service instance
    var aiCacheService: AICacheServiceInterface {
        _aiCacheService
    }
    
    /// Returns the cached general cache service for immediate synchronous access.
    ///
    /// - Returns: The cached general cache service instance
    var cacheService: CacheService {
        _cacheService
    }
    
    /// Returns the cached random generator service for immediate synchronous access.
    ///
    /// - Returns: The cached random generator service instance
    var randomGeneratorService: RandomGeneratorService {
        _randomGeneratorService
    }
    
    /// Returns the cached UUID generator service for immediate synchronous access.
    ///
    /// - Returns: The cached UUID generator service instance
    var uuidGeneratorService: UUIDGeneratorService {
        _uuidGeneratorService
    }
    
    /// Returns the cached IP extractor service for immediate synchronous access.
    ///
    /// - Returns: The cached IP extractor service instance
    var ipExtractorService: IPExtractorService {
        _ipExtractorService
    }
    
    /// Returns the cached prompt sanitizer service for immediate synchronous access.
    ///
    /// - Returns: The cached prompt sanitizer service instance
    var promptSanitizerService: PromptSanitizerServiceInterface {
        _promptSanitizerService
    }
    
    /// Returns the cached AI input validator service for immediate synchronous access.
    ///
    /// - Returns: The cached AI input validator service instance
    var aiInputValidatorService: AIInputValidatorServiceInterface {
        _aiInputValidatorService
    }
    
    /// Returns the cached cache key generator service for immediate synchronous access.
    ///
    /// - Returns: The cached cache key generator service instance
    var cacheKeyGeneratorService: CacheKeyGeneratorServiceInterface {
        _cacheKeyGeneratorService
    }
}

// MARK: - Application Storage Integration

/// Storage key for the ServiceCache in Application storage.
///
/// This key enables type-safe storage and retrieval of the ServiceCache
/// instance from Vapor's Application storage system.
private struct ServiceCacheKey: StorageKey {
    typealias Value = ServiceCache
}

extension Application {
    /// Access to the pre-resolved service cache for synchronous service access.
    ///
    /// This property provides access to the ServiceCache that contains all
    /// pre-resolved services, enabling synchronous service accessor patterns
    /// while using ServiceRegistry for dependency injection.
    ///
    /// ## Usage
    /// ```swift
    /// // Access cached service synchronously
    /// let llmService = app.serviceCache.llmService
    /// let userRepo = app.serviceCache.userRepository
    /// ```
    ///
    /// ## Lifecycle
    /// The service cache is created during application startup after all services
    /// have been registered and resolved from the ServiceRegistry. It remains
    /// available throughout the application's lifetime.
    ///
    /// - Returns: The service cache containing all pre-resolved services
    /// - Precondition: ServiceCache must be initialized during application startup
    var serviceCache: ServiceCache {
        get {
            guard let cache = storage[ServiceCacheKey.self] else {
                fatalError("ServiceCache not initialized. Call setupServiceRegistry() during application startup.")
            }
            return cache
        }
        set {
            storage[ServiceCacheKey.self] = newValue
        }
    }
}
