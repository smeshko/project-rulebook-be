@testable import App
import Fluent
import FluentSQLiteDriver
import XCTVapor

/// Shared test repositories that get used across the application
private final class SharedTestRepositories: @unchecked Sendable {
    static let shared = SharedTestRepositories()
    
    let tokenRepository: TestRefreshTokenRepository = .init()
    let userRepository: TestUserRepository = .init()
    let emailTokenRepository: TestEmailTokenRepository = .init()
    let passwordTokenRepository: TestPasswordTokenRepository = .init()
    
    private init() {}
    
    func reset() async {
        await tokenRepository.reset()
        await userRepository.reset()
        await emailTokenRepository.reset()
        await passwordTokenRepository.reset()
    }
    
    func resetSync() {
        Task {
            await reset()
        }
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
        
        // Register test repositories in service registry BEFORE it gets finalized
        // This ensures all services use test repositories
        app.serviceRegistry.register((any UserRepository).self) { _ in shared.userRepository }
        app.serviceRegistry.register((any RefreshTokenRepository).self) { _ in shared.tokenRepository }
        app.serviceRegistry.register((any EmailTokenRepository).self) { _ in shared.emailTokenRepository }
        app.serviceRegistry.register((any PasswordTokenRepository).self) { _ in shared.passwordTokenRepository }
    }
}

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
    /// Sets up all necessary mocks and configures the application for testing.
    /// This includes JWT configuration, repository mocks, and service mocks.
    ///
    /// - Parameter app: The Vapor application to configure
    /// - Throws: Configuration errors
    init(app: Application) throws {
        self.app = app
        
        // Reset shared repositories to ensure clean state for each test
        SharedTestRepositories.shared.resetSync()
        
        // Initialize mock services
        self.fakeLLMService = FakeLLMService(app: app)
        self.mockAICacheService = MockAICacheService(app: app)
        self.constantUUIDGenerator = ConstantUUIDGeneratorService(app: app)
        
        // Initialize data factory
        self.dataFactory = TestDataFactory(app: app)
        
        try setupJWT()
        setupRepositories()
        setupServices()
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
    func createUserWithTokens(email: String = "test@example.com", isVerified: Bool = true) throws -> UserWithTokens {
        return try dataFactory.createUserWithTokens(email: email, isVerified: isVerified)
    }
    
    // MARK: - Private Setup Methods
    
    private func setupJWT() throws {
        try app.jwt.signers.use(.es256(key: .generate()))
    }
    
    private func setupRepositories() {
        // Override old Vapor service system repositories
        app.repositories.refreshTokensService.use { _ in self.sharedRepositories.tokenRepository }
        app.repositories.usersService.use { _ in self.sharedRepositories.userRepository }
        app.repositories.emailTokensService.use { _ in self.sharedRepositories.emailTokenRepository }
        app.repositories.passwordTokensService.use { _ in self.sharedRepositories.passwordTokenRepository }
        
        // Note: Service registry repositories are already set up in TestWorldPreConfiguration
        // before configure() runs, so we don't need to register them again here
    }
    
    private func setupServices() {
        // Mock external services
        app.services.email.use(.fake)
        app.services.llm.use(.fake)
        app.services.aiCache.use(.mock)
        app.services.uuidGenerator.use(.constant)
        app.services.randomGenerator.use(.rigged(value: "test_random_value"))
        
        // Additional services can be configured here as needed
        // app.services.ipExtractor.use(.mock) // If we create a mock IP extractor
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
        
        // Pre-configure test repositories BEFORE running configure()
        // This ensures the service registry uses test repositories
        let testWorld = try TestWorldPreConfiguration(app: app)
        testWorld.setupTestRepositories()
        
        try configure(app)
        return app
    }
    
    /// Creates a TestWorld with a new async application.
    ///
    /// - Returns: TestWorld instance with async application
    /// - Throws: Configuration or setup errors
    static func make() async throws -> TestWorld {
        let app = try await makeTestApp()
        return try TestWorld(app: app)
    }
}
