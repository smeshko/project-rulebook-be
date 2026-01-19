# Testing Framework

Production-grade testing infrastructure for the project-rulebook-be Vapor application.

## Table of Contents

- [Quick Start](#quick-start)
- [Architecture](#architecture)
- [Test Organization](#test-organization)
- [Writing Tests](#writing-tests)
- [Test Tags & Prioritization](#test-tags--prioritization)
- [Mock Services](#mock-services)
- [Assertions](#assertions)
- [CI Pipeline](#ci-pipeline)
- [Best Practices](#best-practices)

---

## Quick Start

### Running Tests

```bash
# Run all tests
swift test

# Run P0 critical tests only (fast gate)
swift test --filter "p0Critical"

# Run P0 + P1 core tests (PR check)
swift test --filter "p0Critical|p1Core"

# Run specific test suite
swift test --filter "AuthSignupTests"

# Run with parallel execution
swift test --parallel
```

### Creating a New Test

```swift
import Testing
import VaporTesting
@testable import App

@Suite(.serialized)
struct MyFeatureTests {
    let app: Application
    let testWorld: IsolatedTestWorld

    init() async throws {
        testWorld = try await IsolatedTestWorld()
        app = testWorld.app
    }

    @Test("Feature works correctly", .tags(.p1Core, .integration))
    func featureHappyPath() async throws {
        await testWorld.resetAll()

        try await app.test(.GET, "/api/v1/my-endpoint") { res async throws in
            #expect(res.status == .ok)
        }
    }
}
```

---

## Architecture

```
Tests/AppTests/
├── Framework/                      # Test infrastructure
│   ├── Base/                      # Base test case classes
│   │   ├── IntegrationTestCase.swift
│   │   └── UnitTestCase.swift
│   ├── Builders/                  # Test data factories
│   │   ├── TestDataFactory.swift
│   │   └── UserBuilder.swift
│   ├── Helpers/                   # Assertion utilities
│   │   ├── Assertions.swift
│   │   └── SchemaValidation.swift
│   ├── Mocks/                     # Mock implementations
│   │   ├── Services/
│   │   └── Repositories/
│   ├── IsolatedTestWorld.swift    # Per-suite isolation (RECOMMENDED)
│   ├── TestWorld.swift            # Shared singleton (DEPRECATED)
│   ├── TestTags.swift             # Test categorization
│   └── TestConfiguration.swift    # CI stage configs
├── Tests/                         # Actual test suites
│   ├── ControllerTests/
│   ├── ServiceTests/
│   └── RepositoryTests/
└── README.md                      # This file
```

### Key Components

| Component | Purpose |
|-----------|---------|
| `IsolatedTestWorld` | Per-suite isolation with fresh app instance |
| `TestTags` | P0-P3 prioritization and domain tagging |
| `TestDataFactory` | Create test users, tokens, and entities |
| `FakeLLMService` | Mock LLM responses for AI testing |
| `FailableHTTPClient` | Simulate network failures |
| `APISchemaValidator` | Validate API response contracts |

---

## Test Organization

### Test Levels

| Level | Location | Purpose | Tags |
|-------|----------|---------|------|
| Unit | `Tests/ServiceTests/` | Isolated business logic | `.unit` |
| Integration | `Tests/ControllerTests/` | HTTP endpoints with full stack | `.integration` |
| Contract | `Tests/ContractTests/` | API schema validation | `.contract` |
| Performance | `Tests/Performance/` | Timing and throughput | `.performance` |

### Naming Conventions

```swift
// Test suite: {Feature}Tests
struct AuthSignupTests { }

// Test method: descriptive action + expected outcome
@Test("User registration succeeds with valid data")
func registerHappyPath() { }

@Test("Registration fails with duplicate email")
func duplicateEmailRejected() { }

@Test("Registration fails with invalid password format")
func invalidPasswordRejected() { }
```

---

## Writing Tests

### Using IsolatedTestWorld (Recommended)

```swift
@Suite(.serialized)
struct MyTests {
    let app: Application
    let testWorld: IsolatedTestWorld

    init() async throws {
        testWorld = try await IsolatedTestWorld()
        app = testWorld.app
    }

    @Test("Test something", .tags(.p1Core))
    func testSomething() async throws {
        // Reset state for clean test
        await testWorld.resetAll()

        // Create test data
        let user = try await testWorld.createUserWithTokens()

        // Configure mocks
        testWorld.llm.configureResponse(for: "game", response: "Mock response")

        // Execute test
        try await app.test(.GET, "/api/v1/endpoint", user: user.user) { res async throws in
            #expect(res.status == .ok)
        }
    }
}
```

### HTTP Request Testing

```swift
// Simple GET request
try await app.test(.GET, "/api/v1/health") { res async throws in
    #expect(res.status == .ok)
}

// POST with JSON body
let requestData = MyRequest(field: "value")
try await app.test(.POST, "/api/v1/resource", beforeRequest: { req in
    try req.content.encode(requestData)
}, afterResponse: { res async throws in
    #expect(res.status == .created)

    let response = try res.content.decode(MyResponse.self)
    #expect(response.id != nil)
})

// Authenticated request
let user = try await testWorld.createUserWithTokens()
try await app.test(.GET, "/api/v1/me", user: user.user) { res async throws in
    #expect(res.status == .ok)
}
```

### Database Verification

```swift
@Test("User is persisted to database")
func userPersistence() async throws {
    let signupData = Auth.SignUp.Request(email: "test@example.com", password: "password123")

    try await app.test(.POST, "/api/v1/auth/sign-up", beforeRequest: { req in
        try req.content.encode(signupData)
    }, afterResponse: { res async throws in
        #expect(res.status == .ok)

        // Verify in database
        let user = try await UserAccountModel.query(on: app.db)
            .filter(\.$email == "test@example.com")
            .first()

        #expect(user != nil)
        #expect(user?.isEmailVerified == false)
    })
}
```

---

## Test Tags & Prioritization

### Priority Tags

| Tag | Description | When to Use |
|-----|-------------|-------------|
| `.p0Critical` | Must pass before merge | Core user journeys, auth, payments |
| `.p1Core` | Run on every PR | Important features, CRUD operations |
| `.p2Extended` | Run nightly | Edge cases, comprehensive coverage |
| `.p3Edge` | Run weekly | Rare scenarios, unicode, boundaries |

### Domain Tags

| Tag | Domain |
|-----|--------|
| `.auth` | Authentication & authorization |
| `.rulesGeneration` | AI rules generation |
| `.aiServices` | LLM/AI integrations |
| `.database` | Database operations |
| `.caching` | Cache operations |

### Usage

```swift
@Test("Critical signup flow", .tags(.p0Critical, .auth, .integration))
func signupCriticalPath() async throws { }

@Test("Unicode email handling", .tags(.p3Edge, .auth))
func unicodeEmailEdgeCase() async throws { }
```

### Running by Tag

```bash
# P0 only (fast gate)
swift test --filter "p0Critical"

# Auth tests only
swift test --filter "auth"

# P0 + P1 excluding flaky
swift test --filter "p0Critical|p1Core" --skip "flaky"
```

---

## Mock Services

### FakeLLMService

```swift
// Configure specific response
testWorld.llm.configureResponse(for: "game rules", response: """
    {"title": "Chess", "rules": ["Move pieces", "Checkmate wins"]}
    """)

// Set default response
testWorld.llm.setDefaultResponse("Default AI response")

// Reset between tests
testWorld.llm.reset()
```

### MockAICacheService

```swift
// Force cache misses
testWorld.aiCache.configureForceMiss(true)

// Set hit ratio (for probabilistic testing)
testWorld.aiCache.configureHitRatio(0.8)  // 80% cache hits

// Pre-populate cache
testWorld.aiCache.setTestEntry(key: "game:chess", value: "cached rules", ttl: 3600)
```

### FailableHTTPClient

```swift
// Create failable client
let failableClient = FailableHTTPClient(wrapping: app.client, eventLoop: app.eventLoopGroup.next())

// Simulate timeout
failableClient.configure(.timeout)

// Simulate intermittent failures
failableClient.configure(.intermittent(failEvery: 3))

// Simulate rate limiting
failableClient.configure(.rateLimited(retryAfter: 60))

// Simulate server error
failableClient.configure(.serverError(.internalServerError))
```

### ConstantUUIDGeneratorService

```swift
// Predictable UUIDs for deterministic testing
testWorld.uuidGenerator.reset()  // Start from UUID index 0

// UUIDs are: 00000000-0000-0000-0000-000000000001, ...000002, etc.
```

---

## Assertions

### Response Assertions

```swift
// Validate success response
try expectSuccess(response, status: .ok, as: MyResponse.self) { content in
    #expect(content.field == "expected")
}

// Validate error response
expectError(response, status: .badRequest, identifier: "invalid_input")

// Validate response matches AppError
expectResponseError(response, MyError.invalidInput("Bad data"))
```

### Schema Validation

```swift
// Validate success schema
try APISchemaValidator.validateSuccess(response, as: User.Response.self) { user in
    #expect(user.id != nil)
}

// Validate error schema
APISchemaValidator.validateBadRequest(response, identifier: "validation_error")

// Validate list response
try APISchemaValidator.validateList(response, of: Game.self, minCount: 1)
```

### Database Assertions

```swift
// Verify entity exists
let user = try await expectExists(UserAccountModel.self, id: userId, on: app.db)

// Verify entity was deleted
try await expectNotExists(UserAccountModel.self, id: userId, on: app.db)

// Verify count
try await expectCount(UserAccountModel.self, equals: 5, on: app.db)
```

### Timing Assertions

```swift
// Verify operation completes within time limit
try await expectCompletes(within: 2.0) {
    try await service.performOperation()
}

// Verify operation takes minimum time (rate limiting)
try await expectTakesAtLeast(1.0) {
    try await rateLimitedOperation()
}
```

---

## CI Pipeline

### Pipeline Stages

```
PR Opened
    │
    ▼
┌─────────────────┐
│   Fast Gate     │  P0 Critical, < 2 min
│   (Required)    │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│   PR Check      │  P0 + P1 Core, < 10 min
│   (Required)    │
└────────┬────────┘
         │
         ▼
      Merge
         │
         ▼
┌─────────────────┐
│   Nightly       │  All tests + burn-in
│   (Scheduled)   │
└─────────────────┘
```

### Running Locally

```bash
# Simulate fast gate
TEST_STAGE=fastGate swift test --filter "p0Critical"

# Simulate PR check
TEST_STAGE=prCheck swift test --filter "p0Critical|p1Core"

# Burn-in a specific test (run 10 times)
for i in {1..10}; do swift test --filter "MyFlakyTest" || exit 1; done
```

### Environment Variables

| Variable | Description |
|----------|-------------|
| `CI=true` | Indicates CI environment |
| `TEST_STAGE` | Current test stage (fastGate, prCheck, nightly) |
| `SKIP_SLOW_TESTS=true` | Skip tests tagged with `.slow` |
| `SKIP_NETWORK_TESTS=true` | Skip tests tagged with `.requiresNetwork` |

---

## Best Practices

### DO

- **Always use `IsolatedTestWorld`** for new tests
- **Tag every test** with priority (P0-P3) and domain
- **Call `resetAll()`** at the start of tests that modify state
- **Use `@Suite(.serialized)`** for tests that share database state
- **Test error cases**, not just happy paths
- **Use descriptive test names** that explain the scenario

### DON'T

- **Don't use `TestWorld`** (deprecated shared singleton)
- **Don't skip `resetAll()`** if previous tests might have modified state
- **Don't hardcode UUIDs** — use `ConstantUUIDGeneratorService`
- **Don't test implementation details** — test behavior
- **Don't ignore flaky tests** — tag them and investigate

### Test Isolation Checklist

- [ ] Uses `IsolatedTestWorld` (not `TestWorld`)
- [ ] Calls `resetAll()` if state matters
- [ ] Uses `@Suite(.serialized)` for database tests
- [ ] Doesn't depend on test execution order
- [ ] Cleans up any created resources

### Flaky Test Protocol

1. **Identify**: Mark with `.tags(.flaky)`
2. **Isolate**: Run burn-in to reproduce
3. **Investigate**: Check for race conditions, timing issues
4. **Fix**: Address root cause
5. **Verify**: Run burn-in (10+ iterations) to confirm fix
6. **Remove tag**: Remove `.flaky` tag once stable

---

## Migration Guide

### From TestWorld to IsolatedTestWorld

```swift
// OLD (deprecated)
@Suite(.serialized)
struct MyTests {
    @Test func test() async throws {
        let testWorld = try await TestWorld()
        let app = testWorld.app
        // ...
    }
}

// NEW (recommended)
@Suite(.serialized)
struct MyTests {
    let app: Application
    let testWorld: IsolatedTestWorld

    init() async throws {
        testWorld = try await IsolatedTestWorld()
        app = testWorld.app
    }

    @Test func test() async throws {
        await testWorld.resetAll()
        // ...
    }
}
```

---

## Troubleshooting

### Tests Fail in CI but Pass Locally

1. Check for timing dependencies — use `expectCompletes` with reasonable timeouts
2. Check for environment dependencies — mock external services
3. Run with `--parallel` locally to reproduce concurrency issues

### Database State Contamination

1. Ensure using `IsolatedTestWorld` (not shared `TestWorld`)
2. Call `resetAll()` at test start
3. Use `@Suite(.serialized)` for database tests

### Flaky Tests

1. Tag with `.flaky` to exclude from PR checks
2. Run burn-in: `for i in {1..25}; do swift test --filter "TestName"; done`
3. Check for race conditions, timing issues, or shared state

---

*Test Framework Documentation — project-rulebook-be*
*Last Updated: 2025-01-19*
