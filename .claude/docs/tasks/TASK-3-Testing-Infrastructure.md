# Task 3: Testing Infrastructure Fix

**Branch:** `bugfix/test-infrastructure`  
**Effort:** 2-3 days | **Priority:** 🔴 CRITICAL  
**Dependencies:** None (can run in parallel with other tasks)

## 🎯 Objective

Fix broken testing infrastructure by resolving compilation errors in TestWorld, removing references to missing repositories, and establishing robust testing utilities for future development.

## 🔍 Current Testing Issues

### Critical Problems
1. **TestWorld Compilation Errors** - References 4 missing repository types:
   - `TestPostRepository` - Not implemented
   - `TestMediaRepository` - Not implemented  
   - `TestCommentRepository` - Not implemented
   - `TestBusinessRepository` - Not implemented

2. **Repository Service Registration Issues** - TestWorld tries to register non-existent services:
   ```swift
   app.repositories.use { _ in self.postRepository }
   app.repositories.use { _ in self.mediaRepository }
   app.repositories.use { _ in self.commentRepository }
   app.repositories.use { _ in self.businessRepository }
   ```

3. **Missing Test Utilities** - No integration test helpers or data factories

4. **Service Registration Mismatch** - TestWorld references services that don't exist:
   ```swift
   app.services.fileStorage.use(.fake) // FileStorage service doesn't exist
   ```

## 🔍 Domain Analysis

Based on codebase analysis, the current domain includes:
- **Users** ✅ (TestUserRepository exists)
- **Authentication** ✅ (Email, Password, Refresh token repos exist)
- **Rules Generation** ✅ (No persistent storage needed)
- **Frontend** ✅ (No persistent storage needed)

Missing repositories appear to be for planned but unimplemented features.

## 🏗 Solution Architecture

### Approach 1: Clean Removal (Recommended)
Remove references to unimplemented domains and focus on existing functionality.

### Approach 2: Stub Implementation
Create minimal stub implementations for future extensibility.

**Recommendation:** Use Approach 1 for immediate fix, with clear extension points for future domains.

## 📋 Implementation Steps

### Step 1: Fix TestWorld Core Issues

**File:** `Tests/AppTests/Framework/TestWorld.swift` (Major Refactor)

```swift
@testable import App
import Fluent
import FluentSQLiteDriver
import XCTVapor

class TestWorld {
    let app: Application
    
    // Existing repositories (working)
    private let refreshTokenRepository: TestRefreshTokenRepository = .init()
    private let userRepository: TestUserRepository = .init()
    private let emailTokenRepository: TestEmailTokenRepository = .init()
    private let passwordTokenRepository: TestPasswordTokenRepository = .init()
    
    init(app: Application) throws {
        self.app = app
        
        // JWT setup for testing
        try app.jwt.signers.use(.es256(key: .generate()))
        
        // Register existing repositories
        app.repositories.refreshTokensService.use { _ in self.refreshTokenRepository }
        app.repositories.usersService.use { _ in self.userRepository }
        app.repositories.emailTokensService.use { _ in self.emailTokenRepository }
        app.repositories.passwordTokensService.use { _ in self.passwordTokenRepository }
        
        // Register mock services
        app.services.email.use(.fake)
        app.services.randomGenerator.use(.rigged(value: "test-token"))
        app.services.uuidGenerator.use(.constant(UUID()))
        app.services.llm.use(.fake)
    }
}

// Extension for future domain additions
extension TestWorld {
    /// Add new domain repositories here as they are implemented
    /// Example:
    /// func addPostRepository(_ repository: TestPostRepository) {
    ///     app.repositories.postsService.use { _ in repository }
    /// }
}
```

### Step 2: Create Missing Service Mocks

**File:** `Tests/AppTests/Framework/Mocks/Services/FakeLLMService.swift`

```swift
@testable import App
import Vapor

extension Application.Service.Provider where ServiceType == LLMService {
    static var fake: Self {
        .init {
            $0.services.llm.use { FakeLLMService(app: $0) }
        }
    }
}

struct FakeLLMService: LLMService {
    let app: Application
    
    func generate(input: [OpenAIRequest.Message]) async throws -> String {
        // Return predictable fake responses for testing
        return """
        {
            "guessedTitle": "Test Game",
            "confidence": 95,
            "alternativeTitles": ["Another Game"],
            "keywordsDetected": ["test", "game"],
            "notes": "This is a test response"
        }
        """
    }
    
    func `for`(_ request: Request) -> LLMService {
        Self(app: request.application)
    }
}
```

**File:** `Tests/AppTests/Framework/Mocks/Services/ConstantUUIDGeneratorService.swift`

```swift
@testable import App
import Vapor
import Foundation

extension Application.Service.Provider where ServiceType == UUIDGeneratorService {
    static func constant(_ uuid: UUID) -> Self {
        .init {
            $0.services.uuidGenerator.use { ConstantUUIDGeneratorService(app: $0, uuid: uuid) }
        }
    }
}

struct ConstantUUIDGeneratorService: UUIDGeneratorService {
    let app: Application
    let uuid: UUID
    
    func generate() -> UUID {
        uuid
    }
    
    func `for`(_ request: Request) -> UUIDGeneratorService {
        Self(app: request.application, uuid: uuid)
    }
}
```

### Step 3: Enhanced Test Utilities

**File:** `Tests/AppTests/Framework/Helpers/TestDataFactory.swift`

```swift
@testable import App
import Vapor
import Fluent
import Foundation

struct TestDataFactory {
    static func createUser(
        email: String = "test@example.com",
        password: String = "password123",
        isEmailVerified: Bool = true,
        isAdmin: Bool = false
    ) -> UserAccountModel {
        UserAccountModel(
            email: email,
            password: password,
            firstName: "Test",
            lastName: "User",
            isAdmin: isAdmin,
            isEmailVerified: isEmailVerified
        )
    }
    
    static func createEmailToken(
        userID: UUID,
        value: String = "test-token"
    ) -> EmailTokenModel {
        EmailTokenModel(
            userID: userID,
            value: value,
            expiresAt: Date().addingTimeInterval(15.minutes)
        )
    }
    
    static func createRefreshToken(
        userID: UUID,
        value: String = "refresh-token"
    ) -> RefreshTokenModel {
        RefreshTokenModel(
            value: value,
            userID: userID,
            expiresAt: Date().addingTimeInterval(7.days)
        )
    }
    
    static func createPasswordToken(
        userID: UUID,
        value: String = "password-token"
    ) -> PasswordTokenModel {
        PasswordTokenModel(
            userID: userID,
            value: value,
            expiresAt: Date().addingTimeInterval(1.hour)
        )
    }
}
```

**File:** `Tests/AppTests/Framework/Helpers/TestAssertions.swift`

```swift
import XCTest
import Vapor
@testable import App

// Enhanced assertion helpers
func XCTAssertValidUser(_ user: User.Detail.Response, file: StaticString = #file, line: UInt = #line) {
    XCTAssertFalse(user.email.isEmpty, "User email should not be empty", file: file, line: line)
    XCTAssertNotNil(user.id, "User ID should not be nil", file: file, line: line)
}

func XCTAssertValidToken(_ token: Token.Detail.Response, file: StaticString = #file, line: UInt = #line) {
    XCTAssertFalse(token.value.isEmpty, "Token value should not be empty", file: file, line: line)
    XCTAssertTrue(token.expiresAt > Date(), "Token should not be expired", file: file, line: line)
}

func XCTAssertAuthenticationError(_ response: XCTHTTPResponse, _ expectedError: AuthenticationError, file: StaticString = #file, line: UInt = #line) {
    XCTAssertEqual(response.status, expectedError.status, file: file, line: line)
    XCTAssertContent(ErrorResponse.self, response) { errorContent in
        XCTAssertEqual(errorContent.errorIdentifier, expectedError.identifier, file: file, line: line)
    }
}
```

### Step 4: Integration Test Helpers

**File:** `Tests/AppTests/Framework/Helpers/IntegrationTestCase.swift`

```swift
import XCTVapor
@testable import App

class IntegrationTestCase: XCTestCase {
    var app: Application!
    var testWorld: TestWorld!
    
    override func setUpWithError() throws {
        app = Application(.testing)
        try configure(app)
        testWorld = try TestWorld(app: app)
    }
    
    override func tearDown() {
        app.shutdown()
    }
    
    // Helper methods for common test operations
    func createAuthenticatedUser() async throws -> (user: UserAccountModel, token: String) {
        let user = TestDataFactory.createUser()
        try await testWorld.userRepository.create(user)
        
        let payload = TokenPayload(userID: try user.requireID(), isAdmin: user.isAdmin)
        let token = try app.jwt.signers.sign(payload)
        
        return (user, token)
    }
    
    func authenticatedRequest(_ method: HTTPMethod, _ path: String, token: String) -> XCTHTTPRequest {
        var request = XCTHTTPRequest(method: method, url: URI(string: path))
        request.headers.bearerAuthorization = BearerAuthorization(token: token)
        return request
    }
}
```

### Step 5: Fix Existing Test Compilation Issues

**Files to Update:**
- All test files that reference missing repositories
- Any tests that use hardcoded values instead of TestDataFactory
- Tests with broken assertions

**Example Fix in AuthSignupTests.swift:**

```swift
final class AuthSignupTests: IntegrationTestCase {
    let registerPath = "api/auth/sign-up"
    
    func testRegisterHappyPath() async throws {
        let data = Auth.SignUp.Request(
            email: "test@test.com",
            password: "password123",
            firstName: "Test",
            lastName: "User"
        )
        
        try await app.test(.POST, registerPath, beforeRequest: { req in
            try req.content.encode(data)
        }, afterResponse: { res in
            XCTAssertEqual(res.status, .ok)
            try await XCTAssertContentAsync(Auth.SignUp.Response.self, res) { signup in
                XCTAssertValidUser(signup.user)
                XCTAssertValidToken(signup.token)
                
                // Verify user was created
                let model = try await self.testWorld.userRepository.find(id: signup.user.id)
                XCTAssertNotNil(model)
                XCTAssertTrue(try BCryptDigest().verify("password123", created: model!.password!))
                
                // Verify email token was created
                let emailToken = try await self.testWorld.emailTokenRepository.find(token: SHA256.hash("test-token"))
                XCTAssertEqual(emailToken?.$user.id, signup.user.id)
            }
        })
    }
}
```

### Step 6: Test Coverage Improvements

**File:** `Tests/AppTests/Framework/Helpers/TestCoverageHelper.swift`

```swift
import XCTest
@testable import App

struct TestCoverageHelper {
    /// Verify all routes are covered by tests
    static func verifyRoutesCovered(in app: Application) {
        let routes = app.routes.all
        print("Total routes: \(routes.count)")
        
        for route in routes {
            print("Route: \(route.method) \(route.path)")
        }
        
        // Add logic to track which routes have been tested
    }
    
    /// Generate test data for all domain entities
    static func generateTestSuite() {
        // Helper to generate comprehensive test data
    }
}
```

## 🧪 Testing Strategy

### Unit Tests
1. **TestWorld Functionality**
   - Verify all services are properly mocked
   - Test repository registration
   - Validate JWT setup

2. **Mock Services**
   - Test fake service implementations
   - Verify predictable responses
   - Test service integration

3. **Test Utilities**
   - Validate TestDataFactory creates valid objects
   - Test assertion helpers work correctly
   - Integration test base class functionality

### Integration Tests
1. **Complete Test Suite Compilation**
   - All existing tests compile and run
   - No missing dependencies
   - Proper service registration

2. **End-to-End Workflows**
   - User registration → login → authenticated actions
   - Email verification flow
   - Password reset flow
   - Rules generation workflow

## ✅ Success Criteria

### Compilation & Basic Functionality
- [ ] All tests compile without errors
- [ ] TestWorld initializes successfully
- [ ] All existing tests pass
- [ ] No references to unimplemented repositories
- [ ] Mock services work correctly

### Test Infrastructure Quality
- [ ] TestDataFactory provides consistent test data
- [ ] Integration test helpers reduce boilerplate
- [ ] Assertion helpers improve test readability
- [ ] Test coverage maintained or improved

### Documentation & Maintainability
- [ ] Clear extension points for future domains
- [ ] Well-documented test utilities
- [ ] Consistent testing patterns across test suite
- [ ] Easy to add new tests

## 🚀 Implementation Timeline

### Day 1: Core Fixes
- Fix TestWorld compilation errors
- Remove references to missing repositories
- Create basic mock services
- Verify existing tests run

### Day 2: Enhanced Utilities
- Implement TestDataFactory
- Create integration test helpers
- Add enhanced assertion helpers
- Update key test files to use new utilities

### Day 3: Testing & Documentation
- Comprehensive test suite validation
- Fix any remaining compilation issues
- Update testing documentation
- Performance and reliability testing

## 🎯 Definition of Done

- [ ] Zero compilation errors in test suite
- [ ] All existing tests pass
- [ ] TestWorld properly configures test environment
- [ ] Mock services provide predictable responses
- [ ] Test utilities reduce boilerplate code
- [ ] Integration test helpers work correctly
- [ ] Documentation updated with testing guidelines
- [ ] Code review completed
- [ ] Test coverage report shows maintained/improved coverage
- [ ] Merged to staging branch

## 🔄 Future Extensibility

When new domains are added (Post, Media, Comment, Business), follow this pattern:

1. **Create Repository Interface** in `Sources/App/`
2. **Create Test Repository** in `Tests/AppTests/Framework/Mocks/Repositories/`
3. **Add to TestWorld** using the extension pattern
4. **Update TestDataFactory** with new entity creators
5. **Add Domain-Specific Test Helpers** as needed

This ensures the testing infrastructure remains scalable and maintainable.

---

*Task created: 2025-01-18*  
*Estimated completion: 2025-01-21*