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
        // Register fresh repositories in service registry
        app.serviceRegistry.register((any UserRepository).self) { _ in self.userRepository }
        app.serviceRegistry.register((any RefreshTokenRepository).self) { _ in self.tokenRepository }
        app.serviceRegistry.register((any EmailTokenRepository).self) { _ in self.emailTokenRepository }
        app.serviceRegistry.register((any PasswordTokenRepository).self) { _ in self.passwordTokenRepository }
        
        // Configure plaintext password hasher for consistent testing
        app.passwords.use(.plaintext)
        
        // Register fresh mock services
        app.serviceRegistry.register(EmailService.self) { _ in FakeEmailProvider() }
        app.serviceRegistry.register(LLMService.self) { _ in self.fakeLLMService }
        app.serviceRegistry.register(AICacheServiceInterface.self) { _ in self.mockAICacheService }
        app.serviceRegistry.register(CacheService.self) { _ in InMemoryTestCacheService() }
        app.serviceRegistry.register(RandomGeneratorService.self) { _ in RiggedRandomGeneratorService(value: "test_random_value") }
        app.serviceRegistry.register(UUIDGeneratorService.self) { _ in self.constantUUIDGenerator }
        
        // Use production implementations for utility services (safe for testing)
        app.serviceRegistry.register(IPExtractorService.self) { app in DefaultIPExtractorService(app: app) }
        app.serviceRegistry.register(CacheKeyGeneratorServiceInterface.self) { app in DefaultCacheKeyGeneratorService(app: app) }
        app.serviceRegistry.register(PromptSanitizerServiceInterface.self) { app in DefaultPromptSanitizerService(app: app) }
        app.serviceRegistry.register(AIInputValidatorServiceInterface.self) { app in DefaultAIInputValidatorService(app: app) }
        
        // Configure JWT
        try app.jwt.signers.use(.es256(key: .generate()))
        
        // Initialize configuration first (required by setupServiceRegistry)
        try app.initializeConfiguration()
        
        // Initialize ServiceCache after all services are registered
        try await app.setupServiceRegistry()
        
        // Configure manually for testing to avoid service registry conflicts
        try await configureForTestingOnly(app)
    }
    
    /// Test-specific configuration that avoids the service registry setup conflicts.
    ///
    /// This method performs only the essential configuration needed for testing
    /// without triggering the full service registry setup that can cause deadlocks.
    private func configureForTestingOnly(_ app: Application) async throws {
        // Essential configuration only - avoid setupServices() call
        // Configuration already initialized before setupServiceRegistry
        // Database already configured as SQLite in-memory in createIsolatedApplication
        try app.setupJWT()
        // Skip Redis setup for testing
        // Skip service registry setup - already done manually above
        try app.setupMiddleware()
        try app.setupModules()
        
        // Health check endpoint for Railway
        app.get("health") { req -> [String: String] in
            return ["status": "healthy"]
        }
        
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