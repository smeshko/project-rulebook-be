# Testing Standards and Patterns

## Overview
This document outlines the comprehensive testing infrastructure and standards established for the Project Rulebook application. The testing system provides enterprise-grade testing capabilities with full mock service integration and standardized patterns.

## 🏗️ Testing Architecture

### Infrastructure Layout
```
Tests/AppTests/
├── Framework/                    # Core testing infrastructure
│   ├── Base/                     # Base test case classes
│   │   ├── IntegrationTestCase   # HTTP endpoint testing
│   │   ├── UnitTestCase         # Service/business logic testing
│   │   └── PerformanceTestCase  # Benchmarking and performance
│   ├── Builders/                # Test data generation
│   │   ├── TestDataFactory      # Centralized test data creation
│   │   ├── TokenBuilder         # JWT token generation
│   │   └── UserBuilder          # User entity creation
│   ├── Helpers/                 # Testing utilities
│   ├── Mocks/                   # Mock implementations
│   └── TestWorld.swift          # Complete test environment
├── Security/                    # AI security testing
├── Services/                    # Service layer tests
└── Tests/                       # Controller and endpoint tests
```

### Design Principles
1. **Isolation**: Each test runs in a clean, predictable environment
2. **Mocking**: All external services are mocked for reliability
3. **Performance**: Fast test execution with in-memory databases
4. **Standardization**: Consistent patterns across all test types
5. **Comprehensiveness**: Unit, integration, and performance testing

## 📋 Test Case Types

### 1. Integration Testing (`IntegrationTestCase`)
**Purpose**: Test HTTP endpoints and full application stack  
**Use Case**: Controller testing, API validation, end-to-end flows

```swift
import XCTVapor
import XCTest

final class AuthenticationEndpointTests: XCTestCase {
    func testUserLogin() async throws {
        let testCase = try IntegrationTestCase()
        
        // Configure test environment
        let user = try testCase.world.createUserWithTokens(
            email: "test@example.com", 
            isVerified: true
        )
        
        // Test the endpoint
        try await testCase.test(.POST, "/api/auth/sign-in") { request in
            try request.content.encode([
                "email": "test@example.com",
                "password": "ValidPass123!"
            ])
        } afterResponse: { response in
            XCTAssertEqual(response.status, .ok)
            
            let authResponse = try response.content.decode(AuthResponse.self)
            XCTAssertNotNil(authResponse.accessToken)
            XCTAssertNotNil(authResponse.refreshToken)
        }
    }
}
```

**Key Features**:
- Full application stack testing
- HTTP request/response validation
- Access to `TestWorld` for setup
- Automatic cleanup and teardown

### 2. Unit Testing (`UnitTestCase`)
**Purpose**: Test individual services and business logic  
**Use Case**: Service testing, repository testing, business logic validation

```swift
import Testing
import Vapor

final class ConfigurationServiceTests {
    private let testCase: UnitTestCase
    
    init() async throws {
        self.testCase = try UnitTestCase()
    }
    
    deinit {
        // testCase handles cleanup automatically
    }
    
    @Test("Configuration service loads development settings")
    func testDevelopmentConfiguration() async throws {
        let request = testCase.makeMockRequest()
        let configService = request.application.services.configuration.service
        
        let config = try await configService.getDevelopmentConfiguration()
        
        XCTAssertEqual(config.environment, .development)
        XCTAssertEqual(config.database.host, "localhost")
        XCTAssertTrue(config.features.enableDetailedLogging)
    }
}
```

**Key Features**:
- Lightweight application setup
- Mock request creation
- Service-level testing
- Minimal overhead for fast execution

### 3. Performance Testing (`PerformanceTestCase`)
**Purpose**: Benchmark performance and identify bottlenecks  
**Use Case**: Performance regression testing, optimization validation

```swift
import Testing
import Vapor

final class CachePerformanceTests {
    private let testCase: PerformanceTestCase
    
    init() async throws {
        self.testCase = try PerformanceTestCase()
    }
    
    @Test("AI cache performance meets SLA requirements")
    func testCachePerformance() async throws {
        let metrics = await testCase.measure(
            "AI Cache Retrieval",
            iterations: 1000
        ) {
            // Simulate cache operation
            let request = testCase.application.services.aiCache.service
            _ = await request.get("test-key", as: String.self)
        }
        
        // Verify performance requirements
        XCTAssertLessThan(metrics.averageTime, 0.001) // < 1ms average
        XCTAssertLessThan(metrics.maximumTime, 0.005) // < 5ms max
        
        print(metrics.summary)
    }
}
```

**Key Features**:
- Built-in performance measurement
- Statistical analysis (average, min, max, std deviation)
- Async and sync operation support
- Comprehensive metrics reporting

## 🌍 TestWorld - Central Test Environment

### Overview
`TestWorld` provides a complete, isolated testing environment with all necessary mocks and utilities configured.

```swift
class TestWorld {
    let app: Application
    let dataFactory: TestDataFactory
    
    // Mock Services
    var llm: FakeLLMService
    var aiCache: MockAICacheService
    var rateLimit: MockRateLimitService
    
    // Test Repositories
    var users: TestUserRepository
    var refreshTokens: TestRefreshTokenRepository
    var emailTokens: TestEmailTokenRepository
    var passwordTokens: TestPasswordTokenRepository
}
```

### Key Capabilities

#### 1. Service Configuration
```swift
// Configure AI responses
testWorld.llm.configureResponse(
    for: "Monopoly", 
    response: FakeLLMService.rulesGenerationResponse
)

// Set cache behavior
testWorld.aiCache.configureHitRatio(0.8) // 80% cache hits
testWorld.aiCache.configureLatency(0.001) // 1ms response time

// Configure rate limiting
await testWorld.rateLimit.setLimit(
    for: "rules_generation", 
    limit: 5, 
    window: .hour
)
```

#### 2. Test Data Creation
```swift
// Create complete user with tokens
let userWithTokens = try testWorld.createUserWithTokens(
    email: "test@example.com",
    isVerified: true
)

// Create individual entities
let user = testWorld.dataFactory.createUser()
let tokens = testWorld.dataFactory.createTokens(for: user)
```

#### 3. Environment Reset
```swift
// Clean slate between tests
await testWorld.resetAll()

// Specialized configurations
testWorld.configureForAITesting()
testWorld.configureForAuthTesting()
```

## 🔧 ServiceRegistry Testing Patterns (Phase 4.1)

### ServiceRegistry Integration Testing

The ServiceRegistry system provides comprehensive testing support with dedicated test patterns and mock integration.

#### Unit Testing with ServiceRegistry

```swift
final class ServiceContainerTests: XCTestCase {
    var testCase: UnitTestCase!
    var app: Application { testCase.application }
    
    override func setUp() async throws {
        testCase = try await UnitTestCase()
    }
    
    override func tearDown() async throws {
        try await testCase.shutdown()
        testCase = nil
    }
    
    func testServiceRegistryBasics() async throws {
        // Test basic service registration and resolution
        let registry = ServiceContainer(application: app)
        
        // Register demo service
        try await DemoServiceProvider.register(in: registry, app: app)
        
        // Test service resolution
        let demoService = try await registry.resolveRequired(DemoService.self)
        let message = demoService.getMessage()
        
        XCTAssertEqual(message, "Demo Service: ServiceRegistry is working!")
    }
    
    func testServiceLifecycle() async throws {
        let registry = ServiceContainer(application: app)
        
        // Register service with lifecycle
        try await LifecycleServiceProvider.register(in: registry, app: app)
        
        // Test startup
        try await registry.startupAll(app)
        
        // Verify service is accessible after startup
        let service = try await registry.resolveRequired(LifecycleService.self)
        XCTAssertTrue(service.isStarted)
        
        // Test shutdown
        try await registry.shutdownAll(app)
        XCTAssertTrue(service.isShutdown)
    }
    
    func testHealthChecks() async throws {
        let registry = ServiceContainer(application: app)
        
        // Register service with health check
        try await HealthCheckServiceProvider.register(in: registry, app: app)
        
        // Ensure service is instantiated
        _ = try await registry.resolveRequired(HealthCheckService.self)
        
        // Test health checks
        let healthChecks = await registry.healthCheckAll()
        XCTAssertEqual(healthChecks.count, 1)
        XCTAssertTrue(healthChecks.first?.healthy ?? false)
    }
}
```

#### Mock Service Registration for Testing

```swift
// Create mock services for testing
final class MockUserService: UserService {
    var users: [UUID: User] = [:]
    
    func createUser(_ user: User) async throws -> User {
        users[user.id] = user
        return user
    }
    
    func findUser(id: UUID) async throws -> User? {
        return users[id]
    }
}

// Register mock in test setup
struct TestServiceProvider: ServiceProvider {
    static func register(in registry: ServiceContainer, app: Application) async throws {
        // Register mock services
        registry.register(UserService.self, instance: MockUserService())
        registry.register(EmailService.self, instance: MockEmailService())
        
        // Register real services that work in test environment
        registry.register(ConfigurationService.self) { app in
            return ConfigurationService(app: app)
        }
    }
}

// Usage in tests
func testControllerWithMockServices() async throws {
    let testCase = try await IntegrationTestCase()
    
    // Register test services
    try await TestServiceProvider.register(in: testCase.application.serviceRegistry, app: testCase.application)
    
    // Test endpoint using mock services
    try await testCase.test(.POST, "/api/users") { request in
        try request.content.encode(["email": "test@example.com"])
    } afterResponse: { response in
        XCTAssertEqual(response.status, .created)
    }
}
```

#### Request-based Service Testing

```swift
func testRequestServiceResolution() async throws {
    // Test Application.setupServiceRegistry integration
    try await app.setupServiceRegistry()
    
    // Register services in the app's registry
    try await TestServiceProvider.register(in: app.serviceRegistry, app: app)
    
    // Create a mock request
    let request = Request(application: app, on: app.eventLoopGroup.next())
    
    // Test service resolution through Request extension
    let userService = try await request.resolveService(UserService.self)
    let emailService = try await request.resolveServiceOptional(EmailService.self)
    
    XCTAssertNotNil(userService)
    XCTAssertNotNil(emailService)
}
```

#### Error Handling Testing

```swift
func testServiceRegistryErrorHandling() async throws {
    let registry = ServiceContainer(application: app)
    
    // Test resolving non-existent service
    let nonExistentService = try await registry.resolve(NonExistentService.self)
    XCTAssertNil(nonExistentService)
    
    // Test requiring non-existent service throws appropriate error
    do {
        _ = try await registry.resolveRequired(NonExistentService.self)
        XCTFail("Should have thrown ServiceRegistryError.serviceNotFound")
    } catch let error as ServiceRegistryError {
        if case .serviceNotFound(let type) = error {
            XCTAssertTrue(type.contains("NonExistentService"))
        } else {
            XCTFail("Wrong error type: \(error)")
        }
    }
}
```

#### Performance Testing with ServiceRegistry

```swift
func testServiceResolutionPerformance() async throws {
    let testCase = try await PerformanceTestCase()
    let registry = testCase.application.serviceRegistry
    
    // Register services
    try await TestServiceProvider.register(in: registry, app: testCase.application)
    
    // Measure service resolution performance
    let metrics = await testCase.measure(
        "Service Resolution",
        iterations: 1000
    ) {
        _ = try? await registry.resolveRequired(UserService.self)
    }
    
    // Verify performance requirements
    XCTAssertLessThan(metrics.averageTime, 0.001) // < 1ms average resolution
}
```

### ServiceRegistry Testing Best Practices

1. **Service Isolation**: Always register mock services for testing to avoid external dependencies
2. **Lifecycle Testing**: Test service startup and shutdown hooks to ensure proper resource management
3. **Health Check Validation**: Verify health check implementations for service monitoring
4. **Error Scenarios**: Test service resolution failures and error handling
5. **Performance Validation**: Ensure service resolution meets performance requirements
6. **Thread Safety**: Test concurrent service resolution to validate thread safety

## 🎭 Mock Service System

### Available Mock Services

#### 1. FakeLLMService
Simulates OpenAI API responses with configurable behavior.

```swift
// Configure specific responses
testWorld.llm.configureResponse(
    for: "game box analysis",
    response: """
    {
        "guessedTitle": "Monopoly",
        "confidence": 95,
        "alternativeTitles": ["Monopoly Classic"],
        "keywordsDetected": ["Parker Brothers", "Real Estate"],
        "notes": "High confidence match"
    }
    """
)

// Configure error responses
testWorld.llm.configureError(
    for: "invalid input",
    error: .rateLimitExceeded
)

// Simulate API latency
testWorld.llm.configureLatency(0.5) // 500ms delay
```

#### 2. MockAICacheService
In-memory cache implementation with controllable behavior.

```swift
// Set cache hit ratio for testing
testWorld.aiCache.configureHitRatio(0.75) // 75% hits

// Preload cache entries
testWorld.aiCache.preload(key: "rules:Monopoly", value: cachedRules)

// Configure cache statistics
testWorld.aiCache.configurateStatistics(
    hitCount: 100,
    missCount: 25,
    totalRequests: 125
)
```

#### 3. MockRateLimitService
Rate limiting simulation with configurable limits.

```swift
// Configure rate limits
await testWorld.rateLimit.setLimit(
    for: "image_analysis",
    limit: 5,
    window: .hour
)

// Simulate limit exceeded
await testWorld.rateLimit.simulateLimitExceeded(for: "rules_generation")

// Reset all limits
await testWorld.rateLimit.resetAllRateLimits()
```

### Mock Repositories
All repository operations use in-memory implementations for predictable testing.

```swift
// User repository operations
await testWorld.users.create(user)
let foundUser = await testWorld.users.find(byEmail: "test@example.com")

// Token repository operations
await testWorld.refreshTokens.create(token)
await testWorld.emailTokens.verify(token: "verification-token")
```

## 🏭 Test Data Factory

### Purpose
Centralized creation of test entities with consistent, valid data.

```swift
class TestDataFactory {
    func createUser(
        email: String = "test@example.com",
        isVerified: Bool = true,
        role: User.Role = .user
    ) -> User
    
    func createUserWithTokens(
        email: String = "test@example.com",
        isVerified: Bool = true
    ) throws -> UserWithTokens
    
    func createRefreshToken(
        for user: User,
        expiresAt: Date = Date().addingTimeInterval(86400)
    ) -> RefreshToken
}
```

### Usage Examples

```swift
// Basic user creation
let user = testWorld.dataFactory.createUser()

// Customized user
let admin = testWorld.dataFactory.createUser(
    email: "admin@example.com",
    role: .admin
)

// Complete user with authentication tokens
let userWithTokens = try testWorld.dataFactory.createUserWithTokens(
    email: "verified@example.com",
    isVerified: true
)

// Access created entities
let user = userWithTokens.user
let accessToken = userWithTokens.accessToken
let refreshToken = userWithTokens.refreshToken
```

## 📏 Testing Standards

### 1. Test Organization
```swift
// Group related tests in descriptive test classes
final class UserAuthenticationTests: XCTestCase {
    // Test user authentication scenarios
}

final class AISecurityValidationTests: XCTestCase {
    // Test AI security features
}

final class CachePerformanceTests: XCTestCase {
    // Test caching performance
}
```

### 2. Test Naming Convention
```swift
// Pattern: test[Feature][Scenario][ExpectedResult]
func testUserLoginWithValidCredentialsSucceeds() { }
func testAIInputValidationWithInjectionAttemptsBlocks() { }
func testCacheRetrievalWithPopulatedCacheReturnsValue() { }
```

### 3. Test Structure (AAA Pattern)
```swift
func testServiceBehavior() async throws {
    // ARRANGE: Set up test environment
    let testCase = try IntegrationTestCase()
    testCase.world.configureForAITesting()
    
    // ACT: Perform the action being tested
    try await testCase.test(.POST, "/api/endpoint") { request in
        try request.content.encode(testData)
    } afterResponse: { response in
        // ASSERT: Verify the results
        XCTAssertEqual(response.status, .ok)
        let result = try response.content.decode(ExpectedType.self)
        XCTAssertEqual(result.property, expectedValue)
    }
}
```

### 4. Error Testing
```swift
func testServiceWithInvalidInputThrowsError() async throws {
    let testCase = try UnitTestCase()
    let service = testCase.application.services.targetService.service
    
    await XCTAssertThrowsError(
        try await service.processInvalidInput(),
        "Service should throw error for invalid input"
    ) { error in
        XCTAssertTrue(error is ValidationError)
    }
}
```

### 5. Async Testing
```swift
func testAsyncServiceOperation() async throws {
    let testCase = try UnitTestCase()
    let request = testCase.makeMockRequest()
    
    let result = try await request.application
        .services
        .asyncService
        .service
        .performAsyncOperation()
    
    XCTAssertNotNil(result)
}
```

## 🎯 Testing Best Practices

### 1. Test Isolation
- Always use `TestWorld` for comprehensive setup
- Reset test environment between tests
- Avoid shared state between test methods

### 2. Mock Configuration
- Configure mocks at the beginning of each test
- Use realistic mock data
- Test both success and failure scenarios

### 3. Performance Testing
- Set realistic performance expectations
- Test with varying load conditions
- Monitor for performance regressions

### 4. Security Testing
- Test input validation thoroughly
- Verify authentication and authorization
- Test rate limiting and security headers

### 5. Maintainability
- Keep tests simple and focused
- Use descriptive test names
- Document complex test scenarios
- Regularly review and update tests

## 🚀 Running Tests

### Command Line Testing
```bash
# Run all tests
swift test

# Run specific test categories
swift test --filter AuthenticationTests
swift test --filter SecurityTests
swift test --filter PerformanceTests

# Run tests with verbose output
swift test --verbose
```

### Test Environment Configuration
Tests automatically configure:
- In-memory SQLite database
- Mock external services
- Isolated JWT signers
- Test-specific logging levels

### CI/CD Integration
The testing infrastructure is designed for continuous integration:
- Fast execution (< 30 seconds for full suite)
- Deterministic results
- Comprehensive coverage reporting
- Performance regression detection

## 📊 Testing Metrics

### Current Status
- **Test Classes**: 15+ comprehensive test suites
- **Mock Services**: 8 fully-featured mock implementations  
- **Coverage Areas**: Authentication, AI Security, Caching, Configuration
- **Performance Tests**: Cache operations, API endpoints, database queries
- **Build Time**: Project compiles successfully
- **Test Infrastructure**: Fully functional and ready for development

### Quality Metrics
- **Isolation**: ✅ All tests run in isolated environments
- **Reliability**: ✅ Predictable mock service behavior
- **Performance**: ✅ Fast execution with in-memory databases
- **Maintainability**: ✅ Standardized patterns and utilities
- **Comprehensiveness**: ✅ Unit, integration, and performance testing

The testing infrastructure provides a solid foundation for confident development and deployment of the Project Rulebook application.