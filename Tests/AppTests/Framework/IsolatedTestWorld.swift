@testable import App
import Fluent
import FluentSQLiteDriver
import VaporTesting

/// Simple in-memory cache service for testing
final class InMemoryTestCacheService: CacheService, @unchecked Sendable {
    private var storage: [String: Any] = [:]
    private let queue = DispatchQueue(label: "test-cache", attributes: .concurrent)
    
    func get<T>(_ key: String, as type: T.Type) async throws -> T? where T: Codable {
        return queue.sync {
            storage[key] as? T
        }
    }
    
    func set<T>(_ key: String, value: T, ttl: TimeInterval?) async throws where T: Codable {
        queue.async(flags: .barrier) { [weak self] in
            self?.storage[key] = value
        }
    }
    
    func delete(_ key: String) async throws {
        queue.async(flags: .barrier) { [weak self] in
            self?.storage.removeValue(forKey: key)
        }
    }
    
    func flush() async throws {
        queue.async(flags: .barrier) { [weak self] in
            self?.storage.removeAll()
        }
    }
    
    func exists(_ key: String) async throws -> Bool {
        return queue.sync {
            storage[key] != nil
        }
    }
    
    func keys(matching pattern: String) async throws -> [String] {
        return queue.sync {
            Array(storage.keys)
        }
    }
    
    func ttl(_ key: String) async throws -> TimeInterval? {
        return nil // TTL not supported in this test implementation
    }
}

/// Isolated test world that provides complete suite-level isolation for Swift Testing.
///
/// Unlike the shared singleton approach in TestWorld, IsolatedTestWorld creates
/// fresh instances for each test suite, preventing shared state contamination
/// between concurrent test suites in Swift Testing.
///
/// ## Key Features
/// - **Suite Isolation**: Each suite gets its own isolated Application and repositories
/// - **No Shared State**: Fresh repositories prevent data contamination
/// - **Proper Cleanup**: Application shutdown in deinit ensures clean resource management
/// - **Swift Testing Compatible**: Designed for Swift Testing's concurrency model
///
/// ## Usage Pattern
/// ```swift
/// @Suite(.serialized)
/// struct AuthSignupTests {
///     let world: IsolatedTestWorld
///     
///     init() async throws {
///         world = try await IsolatedTestWorld()
///     }
/// }
/// ```
final class IsolatedTestWorld: @unchecked Sendable {
    let app: Application
    
    // MARK: - Test Repositories (suite-local)
    private let userRepository: TestUserRepository
    private let tokenRepository: TestRefreshTokenRepository
    private let emailTokenRepository: TestEmailTokenRepository
    private let passwordTokenRepository: TestPasswordTokenRepository
    private let generatedRuleRepository: TestGeneratedRuleRepository
    private let configRepository: TestConfigRepository
    
    // MARK: - Mock Services
    private let fakeLLMService: FakeLLMService
    private let mockAICacheService: MockAICacheService
    private let constantUUIDGenerator: ConstantUUIDGeneratorService
    
    // MARK: - Test Data Factory
    let dataFactory: TestDataFactory
    
    /// Initialize IsolatedTestWorld with complete suite-level isolation.
    ///
    /// Creates fresh Application instance and repositories for this suite only.
    /// No shared state with other test suites.
    ///
    /// - Throws: Configuration errors
    init() async throws {
        // Create fresh application for this suite
        let createdApp = try await Self.createIsolatedApplication()
        self.app = createdApp
        
        // Create fresh repository instances (no shared state)
        self.userRepository = TestUserRepository()
        self.tokenRepository = TestRefreshTokenRepository()
        self.emailTokenRepository = TestEmailTokenRepository()
        self.passwordTokenRepository = TestPasswordTokenRepository()
        self.generatedRuleRepository = TestGeneratedRuleRepository()
        self.configRepository = TestConfigRepository()
        
        // Create fresh service instances
        self.fakeLLMService = FakeLLMService(app: app)
        self.mockAICacheService = MockAICacheService(app: app)
        self.constantUUIDGenerator = ConstantUUIDGeneratorService(app: app)
        
        // Initialize data factory
        self.dataFactory = TestDataFactory(app: app)
        
        // Configure the application for testing
        try await configureForTesting()
    }
    
    /// Clean shutdown of the application instance when test suite completes.
    deinit {
        app.shutdown()
    }
    
    // MARK: - Private Setup Methods
    
    /// Creates a fresh Application instance with proper test configuration.
    private static func createIsolatedApplication() async throws -> Application {
        let app = try await Application.make(.testing)
        
        // Use in-memory SQLite for complete isolation
        app.databases.use(.sqlite(.memory), as: .sqlite)
        
        return app
    }
    
    /// Configures the application for testing with fresh repositories and services.
    private func configureForTesting() async throws {
        // Configure plaintext password hasher for consistent testing
        app.passwords.use(.plaintext)

        // Assign repositories directly to Application storage
        app.userRepository = self.userRepository
        app.refreshTokenRepository = self.tokenRepository
        app.emailTokenRepository = self.emailTokenRepository
        app.passwordTokenRepository = self.passwordTokenRepository
        app.generatedRuleRepository = self.generatedRuleRepository
        app.configRepository = self.configRepository

        // Assign mock services directly to Application storage
        app.emailService = FakeEmailProvider()
        app.llmService = self.fakeLLMService
        app.aiCacheService = self.mockAICacheService
        app.cacheService = InMemoryTestCacheService()
        app.randomGeneratorService = RiggedRandomGeneratorService(value: "test_random_value")
        app.uuidGeneratorService = self.constantUUIDGenerator

        // Use production implementations for utility services (safe for testing)
        app.ipExtractorService = DefaultIPExtractorService(app: app)
        app.cacheKeyGeneratorService = DefaultCacheKeyGeneratorService(app: app)
        app.promptSanitizerService = DefaultPromptSanitizerService(app: app)
        app.aiInputValidatorService = DefaultAIInputValidatorService(app: app)
        app.aiResponseValidatorService = DefaultAIResponseValidationService()

        // Configure JWT
        try app.jwt.signers.use(.es256(key: .generate()))

        // Initialize configuration first
        try app.initializeConfiguration()

        // Configure manually for testing
        try await configureForTestingOnly(app)
    }
    
    /// Test-specific configuration for essential Vapor setup.
    ///
    /// This method performs only the essential configuration needed for testing.
    /// Services and repositories are already assigned via direct property access.
    private func configureForTestingOnly(_ app: Application) async throws {
        // Essential configuration only - avoid setupServices() call
        // Services and repositories already assigned directly to Application storage
        // Database already configured as SQLite in-memory in createIsolatedApplication
        try app.setupJWT()
        // Skip Redis setup for testing
        try app.setupMiddleware()
        try app.setupModules()

        // Run migrations asynchronously to avoid deadlock in Swift Testing
        _ = try await app.autoMigrate().get()
    }
    
    // MARK: - Public Access to Repositories
    
    /// Access to the isolated user repository.
    var users: TestUserRepository {
        userRepository
    }
    
    /// Access to the isolated refresh token repository.
    var refreshTokens: TestRefreshTokenRepository {
        tokenRepository
    }
    
    /// Access to the isolated email token repository.
    var emailTokens: TestEmailTokenRepository {
        emailTokenRepository
    }
    
    /// Access to the isolated password token repository.
    var passwordTokens: TestPasswordTokenRepository {
        passwordTokenRepository
    }

    /// Access to the isolated generated rule repository.
    var generatedRules: TestGeneratedRuleRepository {
        generatedRuleRepository
    }

    /// Access to the isolated config repository.
    var configs: TestConfigRepository {
        configRepository
    }

    // MARK: - Public Access to Mock Services
    
    /// Access to the isolated LLM service for configuring AI responses.
    var llm: FakeLLMService {
        fakeLLMService
    }
    
    /// Access to the isolated AI cache service for testing cache scenarios.
    var aiCache: MockAICacheService {
        mockAICacheService
    }
    
    /// Access to the isolated UUID generator for predictable UUIDs.
    var uuidGenerator: ConstantUUIDGeneratorService {
        constantUUIDGenerator
    }
    
    /// Access to the isolated rate limit service for testing rate limiting.
    var rateLimit: MockRateLimitService {
        app.mockRateLimit
    }
    
    // MARK: - Test Utilities
    
    /// Reset all repositories and services to their initial state.
    ///
    /// This method is typically not needed since each suite has its own
    /// isolated instances, but can be useful for tests within a suite
    /// that need to reset state between individual test cases.
    func resetAll() async {
        // Reset repositories
        await userRepository.reset()
        await tokenRepository.reset()
        await emailTokenRepository.reset()
        await passwordTokenRepository.reset()
        await generatedRuleRepository.reset()
        await configRepository.reset()
        
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
    
    // MARK: - HTTP Testing Helpers
    
    /// Performs an HTTP test against the isolated application.
    ///
    /// This is a convenience method that wraps Vapor's testing functionality
    /// with proper application lifecycle management for the isolated instance.
    ///
    /// - Parameters:
    ///   - method: HTTP method to use
    ///   - path: URL path to test
    ///   - headers: HTTP headers to include
    ///   - beforeRequest: Optional closure to configure the request
    ///   - afterResponse: Closure to validate the response
    /// - Throws: Any errors from the test execution
    @discardableResult
    func test(
        _ method: HTTPMethod,
        _ path: String,
        headers: HTTPHeaders = [:],
        beforeRequest: @escaping (inout TestingHTTPRequest) throws -> () = { _ in },
        afterResponse: @escaping (TestingHTTPResponse) async throws -> () = { _ in }
    ) async throws -> TestingApplicationTester {
        return try await app.test(
            method,
            path,
            headers: headers,
            beforeRequest: beforeRequest,
            afterResponse: afterResponse
        )
    }
}
