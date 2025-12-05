@testable import App
import Fluent
import FluentSQLiteDriver
import VaporTesting

/// Shared test repositories that get used across the application
private final class SharedTestRepositories: @unchecked Sendable {
    static let shared = SharedTestRepositories()
    
    let tokenRepository: TestRefreshTokenRepository = .init()
    let userRepository: TestUserRepository = .init()
    let emailTokenRepository: TestEmailTokenRepository = .init()
    let passwordTokenRepository: TestPasswordTokenRepository = .init()
    let generatedRuleRepository: TestGeneratedRuleRepository = .init()
    
    private init() {}
    
    func reset() async {
        await tokenRepository.reset()
        await userRepository.reset()
        await emailTokenRepository.reset()
        await passwordTokenRepository.reset()
        await generatedRuleRepository.reset()
    }
    
    func resetSync() {
        Task {
            await reset()
        }
    }
}

/// Global shared test application to prevent resource exhaustion
/// Only creates a single Application instance for all tests
private actor SharedTestApplication {
    static let shared = SharedTestApplication()
    private var _app: Application?
    
    private init() {}
    
    func getSharedApp() async throws -> Application {
        if let app = _app {
            return app
        }
        
        let app = try await Application.make(.testing)
        
        // Pre-configure test repositories and services BEFORE running configure()
        let testWorld = try TestWorldPreConfiguration(app: app)
        testWorld.setupTestRepositories() 
        testWorld.setupTestServices()
        
        try configure(app)
        self._app = app
        
        // Reset repositories for clean test state
        await SharedTestRepositories.shared.reset()
        
        return app
    }
    
    func resetRepositories() async {
        await SharedTestRepositories.shared.reset()
    }
}

/// Helper class to set up test repositories before configure() runs
private class TestWorldPreConfiguration {
    let app: Application
    
    init(app: Application) throws {
        self.app = app
    }
    
    func setupTestRepositories() {
        let shared = SharedTestRepositories.shared

        // Assign test repositories directly to Application storage
        app.userRepository = shared.userRepository
        app.refreshTokenRepository = shared.tokenRepository
        app.emailTokenRepository = shared.emailTokenRepository
        app.passwordTokenRepository = shared.passwordTokenRepository
        app.generatedRuleRepository = shared.generatedRuleRepository
    }

    func setupTestServices() {
        // Configure plaintext password hasher for consistent testing
        app.passwords.use(.plaintext)

        // Assign mock/test services directly to Application storage
        app.emailService = FakeEmailProvider()
        app.llmService = FakeLLMService(app: app)
        app.aiCacheService = MockAICacheService(app: app)
        app.cacheService = InMemoryTestCacheService()
        app.randomGeneratorService = RiggedRandomGeneratorService(value: "test_random_value")
        app.uuidGeneratorService = ConstantUUIDGeneratorService(app: app)

        // Use production implementations for utility services (safe for testing)
        app.ipExtractorService = DefaultIPExtractorService(app: app)
        app.cacheKeyGeneratorService = DefaultCacheKeyGeneratorService(app: app)
        app.promptSanitizerService = DefaultPromptSanitizerService(app: app)
        app.aiInputValidatorService = DefaultAIInputValidatorService(app: app)
        app.aiResponseValidatorService = DefaultAIResponseValidationService()
    }
}

/// ⚠️ DEPRECATED: Use IsolatedTestWorld instead for new tests.
///
/// This TestWorld class uses shared singletons that can cause test interference
/// between concurrent Swift Testing suites. For new tests, use IsolatedTestWorld
/// which provides complete suite-level isolation.
///
/// @deprecated Use IsolatedTestWorld for new tests
/// Enhanced test world for comprehensive testing with mock services and repositories.
///
/// TestWorld provides a complete testing environment with all necessary mock services
/// and repositories configured for predictable test execution. It includes:
/// - Mock repositories for database operations
/// - Mock services for external integrations
/// - Test data factory for creating test objects
/// - Utilities for common testing scenarios
class TestWorld: @unchecked Sendable {
    let app: Application
    
    // MARK: - Test Repositories (shared across the application)
    private let sharedRepositories = SharedTestRepositories.shared
    
    // MARK: - Mock Services
    private let fakeLLMService: FakeLLMService
    private let mockAICacheService: MockAICacheService
    private let constantUUIDGenerator: ConstantUUIDGeneratorService
    
    // MARK: - Test Data Factory
    let dataFactory: TestDataFactory
    
    /// Initialize TestWorld with comprehensive mock services.
    ///
    /// Uses a shared application instance to prevent resource exhaustion
    /// and ensures clean test state through repository resets.
    ///
    /// - Throws: Configuration errors
    init() async throws {
        // Use shared application to prevent resource exhaustion
        self.app = try await SharedTestApplication.shared.getSharedApp()
        
        // Reset shared repositories to ensure clean state for each test
        await SharedTestApplication.shared.resetRepositories()
        
        // Initialize mock services
        self.fakeLLMService = FakeLLMService(app: app)
        self.mockAICacheService = MockAICacheService(app: app)
        self.constantUUIDGenerator = ConstantUUIDGeneratorService(app: app)
        
        // Initialize data factory
        self.dataFactory = TestDataFactory(app: app)
        
        try await setupJWT()
        setupRepositories()
    }
    
    /// Legacy initializer for backward compatibility
    /// - Parameter app: The Vapor application to configure
    /// - Throws: Configuration errors
    init(app: Application) async throws {
        self.app = app
        
        // Reset shared repositories to ensure clean state for each test
        await SharedTestRepositories.shared.reset()
        
        // Initialize mock services
        self.fakeLLMService = FakeLLMService(app: app)
        self.mockAICacheService = MockAICacheService(app: app)
        self.constantUUIDGenerator = ConstantUUIDGeneratorService(app: app)
        
        // Initialize data factory
        self.dataFactory = TestDataFactory(app: app)
        
        try await setupJWT()
        setupRepositories()
    }
    
    // MARK: - Public Access to Mock Services
    
    /// Access to the fake LLM service for configuring AI responses.
    var llm: FakeLLMService {
        fakeLLMService
    }
    
    /// Access to the mock AI cache service for testing cache scenarios.
    var aiCache: MockAICacheService {
        mockAICacheService
    }
    
    /// Access to the constant UUID generator for predictable UUIDs.
    var uuidGenerator: ConstantUUIDGeneratorService {
        constantUUIDGenerator
    }
    
    /// Access to the mock rate limit service for testing rate limiting.
    var rateLimit: MockRateLimitService {
        app.mockRateLimit
    }
    
    // MARK: - Repository Access
    
    /// Access to the test user repository.
    var users: TestUserRepository {
        sharedRepositories.userRepository
    }
    
    /// Access to the test refresh token repository.
    var refreshTokens: TestRefreshTokenRepository {
        sharedRepositories.tokenRepository
    }
    
    /// Access to the test email token repository.
    var emailTokens: TestEmailTokenRepository {
        sharedRepositories.emailTokenRepository
    }
    
    /// Access to the test password token repository.
    var passwordTokens: TestPasswordTokenRepository {
        sharedRepositories.passwordTokenRepository
    }

    /// Access to the test generated rule repository.
    var generatedRules: TestGeneratedRuleRepository {
        sharedRepositories.generatedRuleRepository
    }
    
    // MARK: - Test Utilities
    
    /// Reset all mock services and repositories to their initial state.
    ///
    /// Use this method between tests to ensure clean state and avoid test pollution.
    func resetAll() async {
        // Reset repositories
        await sharedRepositories.reset()
        
        // Reset services
        fakeLLMService.reset()
        mockAICacheService.reset()
        constantUUIDGenerator.reset()
        await rateLimit.resetAllRateLimits()
    }
    
    /// Configure the test environment for AI testing scenarios.
    ///
    /// Sets up optimized responses and cache behavior for AI-related tests.
    func configureForAITesting() {
        llm.configureResponse(for: "game box", response: FakeLLMService.boxAnalysisResponse)
        llm.configureResponse(for: "rules", response: FakeLLMService.rulesGenerationResponse)
        aiCache.configureHitRatio(0.8) // 80% cache hit rate
    }
    
    /// Configure the test environment for authentication testing scenarios.
    ///
    /// Sets up predictable tokens and user states for auth tests.
    func configureForAuthTesting() {
        constantUUIDGenerator.reset()
        // Add any auth-specific configuration here
    }
    
    /// Create a complete test user with associated tokens.
    ///
    /// - Parameters:
    ///   - email: User email address
    ///   - isVerified: Whether the user's email is verified
    /// - Returns: User with associated tokens
    /// - Throws: Any errors from user or token creation
    func createUserWithTokens(email: String = "test@example.com", isVerified: Bool = true) async throws -> UserWithTokens {
        return try await dataFactory.createUserWithTokens(email: email, isVerified: isVerified)
    }
    
    // MARK: - Private Setup Methods
    
    private func setupJWT() async throws {
        try app.jwt.signers.use(.es256(key: .generate()))
        // Password hasher is now configured in TestWorldPreConfiguration
        // HTTP clients are automatically initialized when accessed
        // No explicit initialization needed
    }
    
    private func setupRepositories() {
        // Repository setup is handled through TestWorldPreConfiguration
        // Services and repositories are assigned directly to Application storage
        // No additional setup needed here
    }
    
    
    // MARK: - Static Helpers for Application Creation
    
    /// Creates a new test application using the async API.
    ///
    /// This is a helper method to migrate from the deprecated Application(.testing) 
    /// to the new Application.make(.testing) async API.
    ///
    /// - Returns: Configured test application
    /// - Throws: Configuration errors
    static func makeTestApp() async throws -> Application {
        let app = try await Application.make(.testing)
        try configure(app)
        return app
    }
    
    /// Creates a new test application synchronously for XCTest compatibility.
    ///
    /// This helper method bridges the async Application.make(.testing) API for use
    /// in synchronous XCTest setUpWithError methods.
    ///
    /// - Returns: Configured test application
    /// - Throws: Configuration errors
    static func makeTestAppSync() throws -> Application {
        let app = Application(.testing)
        
        // Pre-configure test repositories and services BEFORE running configure()
        // This ensures the service registry uses test implementations
        let testWorld = try TestWorldPreConfiguration(app: app)
        testWorld.setupTestRepositories()
        testWorld.setupTestServices()
        
        try configure(app)
        return app
    }
    
    /// Creates a TestWorld with shared application instance.
    ///
    /// - Returns: TestWorld instance with shared application
    /// - Throws: Configuration or setup errors
    static func make() async throws -> TestWorld {
        return try await TestWorld()
    }
}
