# Testing Standards and Patterns

## Overview
This document outlines the comprehensive testing infrastructure and standards established for the Project Rulebook application. The testing system provides enterprise-grade testing capabilities with full mock service integration and standardized patterns.

## Testing Architecture

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
│   └── IsolatedTestWorld.swift  # Complete test environment
├── Security/                    # AI security testing
├── Services/                    # Service layer tests
└── Tests/                       # Controller and endpoint tests
```

### Design Principles
1. **Isolation**: Each test suite runs in a clean, predictable environment
2. **Mocking**: All external services are mocked for reliability
3. **Performance**: Fast test execution with in-memory databases
4. **Standardization**: Consistent patterns across all test types
5. **Comprehensiveness**: Unit, integration, and performance testing

## Test Case Types

### 1. Integration Testing (`IntegrationTestCase`)
**Purpose**: Test HTTP endpoints and full application stack
**Use Case**: Controller testing, API validation, end-to-end flows

```swift
import Testing
import XCTVapor

@Suite(.serialized)
struct AuthenticationEndpointTests {
    let testWorld: IsolatedTestWorld

    init() async throws {
        testWorld = try await IsolatedTestWorld()
    }

    @Test("User login with valid credentials succeeds")
    func testUserLogin() async throws {
        // Given: Valid user exists
        let user = try await testWorld.createUserWithTokens(
            email: "test@example.com",
            isVerified: true
        )

        // When: POST to sign-in endpoint
        try await testWorld.app.test(.POST, "/api/auth/sign-in") { request in
            try request.content.encode([
                "email": "test@example.com",
                "password": "ValidPass123!"
            ])
        } afterResponse: { response in
            // Then: Success with tokens
            #expect(response.status == .ok)

            let authResponse = try response.content.decode(AuthResponse.self)
            #expect(authResponse.accessToken != nil)
            #expect(authResponse.refreshToken != nil)
        }
    }
}
```

**Key Features**:
- Full application stack testing
- HTTP request/response validation
- Access to `IsolatedTestWorld` for setup
- Automatic cleanup via suite isolation

### 2. Unit Testing (`UnitTestCase`)
**Purpose**: Test individual services and business logic
**Use Case**: Service testing, repository testing, business logic validation

```swift
import Testing
import Vapor

@Suite(.serialized)
struct ConfigurationServiceTests {
    let testWorld: IsolatedTestWorld

    init() async throws {
        testWorld = try await IsolatedTestWorld()
    }

    @Test("Configuration service loads development settings")
    func testDevelopmentConfiguration() async throws {
        // Access service via property accessor
        let configService = testWorld.app.configurationService

        let config = try await configService.getDevelopmentConfiguration()

        #expect(config.environment == .development)
        #expect(config.database.host == "localhost")
        #expect(config.features.enableDetailedLogging == true)
    }
}
```

**Key Features**:
- Lightweight application setup
- Service access via property injection
- Service-level testing
- Minimal overhead for fast execution

### 3. Performance Testing (`PerformanceTestCase`)
**Purpose**: Benchmark performance and identify bottlenecks
**Use Case**: Performance regression testing, optimization validation

```swift
import Testing
import Vapor

@Suite(.serialized)
struct CachePerformanceTests {
    let testWorld: IsolatedTestWorld

    init() async throws {
        testWorld = try await IsolatedTestWorld()
    }

    @Test("AI cache performance meets SLA requirements")
    func testCachePerformance() async throws {
        let cacheService = testWorld.app.aiCacheService

        // Measure cache retrieval
        let start = Date()
        for _ in 0..<1000 {
            _ = await cacheService.get("test-key", as: String.self)
        }
        let elapsed = Date().timeIntervalSince(start)

        // Average should be < 1ms
        let avgTime = elapsed / 1000.0
        #expect(avgTime < 0.001)
    }
}
```

**Key Features**:
- Built-in performance measurement
- Statistical analysis (average, min, max, std deviation)
- Async operation support
- Comprehensive metrics reporting

## IsolatedTestWorld - Central Test Environment

### Overview
`IsolatedTestWorld` provides a complete, isolated testing environment with all necessary mocks and utilities configured. Each test suite gets a fresh Application instance.

```swift
class IsolatedTestWorld {
    let app: Application
    let dataFactory: TestDataFactory

    // Mock Services (injected via property accessors)
    // Access via app.llmService, app.aiCacheService, etc.

    // Test Repositories (injected via property accessors)
    // Access via app.userRepository, app.refreshTokenRepository, etc.
}
```

### Key Capabilities

#### 1. Service Configuration
```swift
// Access mock services through Application properties
let llmService = testWorld.app.llmService as! FakeLLMService
llmService.configureResponse(
    for: "Monopoly",
    response: FakeLLMService.rulesGenerationResponse
)

// Configure cache behavior
let cacheService = testWorld.app.aiCacheService as! MockAICacheService
cacheService.configureHitRatio(0.8) // 80% cache hits
cacheService.configureLatency(0.001) // 1ms response time
```

#### 2. Test Data Creation
```swift
// Create complete user with tokens
let userWithTokens = try await testWorld.createUserWithTokens(
    email: "test@example.com",
    isVerified: true
)

// Create individual entities
let user = testWorld.dataFactory.createUser()
let tokens = testWorld.dataFactory.createTokens(for: user)
```

#### 3. Mock Service Injection
```swift
// Replace services for testing
testWorld.app.llmService = FakeLLMService()
testWorld.app.userRepository = MockUserRepository()
```

## Controller Testing Patterns

Controllers contain business logic and are the primary focus of testing. Tests validate HTTP concerns and business logic together.

```swift
@Suite(.serialized)
struct AuthControllerTests {
    let testWorld: IsolatedTestWorld

    init() async throws {
        testWorld = try await IsolatedTestWorld()
    }

    @Test("Sign-in with valid credentials returns tokens")
    func testSignInEndpoint() async throws {
        // Given: Valid user credentials
        let user = try await testWorld.createTestUser(password: "ValidPass123!")

        // When: POST to sign-in endpoint
        try await testWorld.app.test(.POST, "api/auth/sign-in") { request in
            try request.content.encode([
                "email": user.email,
                "password": "ValidPass123!"
            ])
        } afterResponse: { response in
            // Then: Successful response with tokens
            #expect(response.status == .ok)

            let authResponse = try response.content.decode(AuthResponse.self)
            #expect(authResponse.accessToken != nil)
            #expect(authResponse.refreshToken != nil)
            #expect(authResponse.user.id == user.id)
        }
    }

    @Test("Sign-in with invalid credentials returns unauthorized")
    func testSignInWithInvalidCredentials() async throws {
        try await testWorld.app.test(.POST, "api/auth/sign-in") { request in
            try request.content.encode([
                "email": "nonexistent@example.com",
                "password": "WrongPassword"
            ])
        } afterResponse: { response in
            #expect(response.status == .unauthorized)
        }
    }
}
```

## Service Testing Patterns

Test services in isolation using mock dependencies injected via Application properties.

```swift
@Suite(.serialized)
struct RulesGenerationServiceTests {
    let testWorld: IsolatedTestWorld

    init() async throws {
        testWorld = try await IsolatedTestWorld()
    }

    @Test("Rules generation with cache hit returns cached response")
    func testRulesGenerationWithCacheHit() async throws {
        // Given: Cached rules for the game
        let mockCache = testWorld.app.aiCacheService as! MockAICacheService
        mockCache.configureCacheHit(value: sampleRulesResponse)

        // When: Requesting rules via controller/service
        try await testWorld.app.test(.POST, "api/rules-generation/rules-summary") { request in
            try request.content.encode(["gameTitle": "Monopoly"])
        } afterResponse: { response in
            // Then: Response returned from cache
            #expect(response.status == .ok)

            // And: AI service was not called
            let mockLLM = testWorld.app.llmService as! FakeLLMService
            #expect(mockLLM.wasGenerateOptimizedCalled == false)
        }
    }
}
```

## Mock Service System

### Available Mock Services

#### 1. FakeLLMService
Simulates OpenAI API responses with configurable behavior.

```swift
let mockLLM = testWorld.app.llmService as! FakeLLMService

// Configure specific responses
mockLLM.configureResponse(
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
mockLLM.configureError(
    for: "invalid input",
    error: .rateLimitExceeded
)

// Simulate API latency
mockLLM.configureLatency(0.5) // 500ms delay
```

#### 2. MockAICacheService
In-memory cache implementation with controllable behavior.

```swift
let mockCache = testWorld.app.aiCacheService as! MockAICacheService

// Set cache hit ratio for testing
mockCache.configureHitRatio(0.75) // 75% hits

// Preload cache entries
mockCache.preload(key: "rules:Monopoly", value: cachedRules)

// Configure cache statistics
mockCache.configureStatistics(
    hitCount: 100,
    missCount: 25,
    totalRequests: 125
)
```

#### 3. MockRateLimitService
Rate limiting simulation with configurable limits.

```swift
// Configure rate limits
mockRateLimit.setLimit(
    for: "image_analysis",
    limit: 5,
    window: .hour
)

// Simulate limit exceeded
mockRateLimit.simulateLimitExceeded(for: "rules_generation")

// Reset all limits
mockRateLimit.resetAllRateLimits()
```

### Mock Repositories
All repository operations use in-memory implementations for predictable testing.

```swift
// Inject mock repository
testWorld.app.userRepository = MockUserRepository()

// User repository operations
let mockUsers = testWorld.app.userRepository as! MockUserRepository
mockUsers.users["test-id"] = testUser

// Token repository operations
testWorld.app.refreshTokenRepository = MockRefreshTokenRepository()
```

## Test Data Factory

### Purpose
Centralized creation of test entities with consistent, valid data.

```swift
class TestDataFactory {
    func createUser(
        email: String = "test@example.com",
        isVerified: Bool = true,
        isAdmin: Bool = false
    ) -> UserAccountModel

    func createUserWithTokens(
        email: String = "test@example.com",
        isVerified: Bool = true
    ) throws -> UserWithTokens

    func createRefreshToken(
        for user: UserAccountModel,
        expiresAt: Date = Date().addingTimeInterval(86400)
    ) -> RefreshTokenModel
}
```

### Usage Examples

```swift
// Basic user creation
let user = testWorld.dataFactory.createUser()

// Customized user
let admin = testWorld.dataFactory.createUser(
    email: "admin@example.com",
    isAdmin: true
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

## Testing Standards

### 1. Test Organization
```swift
// Group related tests in descriptive test suites
@Suite(.serialized)
struct UserAuthenticationTests {
    // Test user authentication scenarios
}

@Suite(.serialized)
struct AISecurityValidationTests {
    // Test AI security features
}

@Suite(.serialized)
struct CachePerformanceTests {
    // Test caching performance
}
```

### 2. Test Naming Convention
```swift
// Pattern: test[Feature][Scenario][ExpectedResult]
@Test("User login with valid credentials succeeds")
func testUserLoginWithValidCredentialsSucceeds() { }

@Test("AI input validation blocks injection attempts")
func testAIInputValidationWithInjectionAttemptsBlocks() { }

@Test("Cache retrieval returns value when populated")
func testCacheRetrievalWithPopulatedCacheReturnsValue() { }
```

### 3. Test Structure (AAA Pattern)
```swift
@Test("Service behavior with valid input")
func testServiceBehavior() async throws {
    // ARRANGE: Set up test environment
    let mockService = testWorld.app.llmService as! FakeLLMService
    mockService.configureResponse(for: "test", response: expectedResponse)

    // ACT: Perform the action being tested
    try await testWorld.app.test(.POST, "/api/endpoint") { request in
        try request.content.encode(testData)
    } afterResponse: { response in
        // ASSERT: Verify the results
        #expect(response.status == .ok)
        let result = try response.content.decode(ExpectedType.self)
        #expect(result.property == expectedValue)
    }
}
```

### 4. Error Testing
```swift
@Test("Service throws error for invalid input")
func testServiceWithInvalidInputThrowsError() async throws {
    try await testWorld.app.test(.POST, "/api/endpoint") { request in
        try request.content.encode(invalidData)
    } afterResponse: { response in
        #expect(response.status == .badRequest)

        let error = try response.content.decode(ErrorResponse.self)
        #expect(error.error == "validation_failed")
    }
}
```

### 5. Async Testing
```swift
@Test("Async service operation completes successfully")
func testAsyncServiceOperation() async throws {
    let service = testWorld.app.aiCacheService

    let result = try await service.get("test-key", as: String.self)

    #expect(result != nil)
}
```

## Testing Best Practices

### 1. Test Isolation
- Each test suite creates fresh `IsolatedTestWorld`
- Mock services injected via Application properties
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

## Running Tests

### Command Line Testing
```bash
# Run all tests
swift test

# Run specific test suites
swift test --filter AuthenticationTests
swift test --filter SecurityTests
swift test --filter PerformanceTests

# Run tests with verbose output
swift test --verbose
```

### Test Environment Configuration
Tests automatically configure:
- In-memory SQLite database
- Mock external services via property injection
- Isolated JWT signers
- Test-specific logging levels

### CI/CD Integration
The testing infrastructure is designed for continuous integration:
- Fast execution (< 30 seconds for full suite)
- Deterministic results
- Comprehensive coverage reporting
- Performance regression detection

## Testing Metrics

### Current Status
- **Test Suites**: 15+ comprehensive test suites
- **Test Methods**: 150+ test methods
- **Mock Services**: 8 fully-featured mock implementations
- **Coverage Areas**: Authentication, AI Security, Caching, Controllers
- **Performance Tests**: Cache operations, API endpoints
- **Build Time**: Project compiles successfully
- **Test Infrastructure**: Fully functional and ready for development

### Quality Metrics
- **Isolation**: ✅ All test suites run in isolated environments
- **Reliability**: ✅ Predictable mock service behavior
- **Performance**: ✅ Fast execution with in-memory databases
- **Maintainability**: ✅ Standardized patterns and utilities
- **Comprehensiveness**: ✅ Unit, integration, and performance testing

The testing infrastructure provides a solid foundation for confident development and deployment of the Project Rulebook application.
