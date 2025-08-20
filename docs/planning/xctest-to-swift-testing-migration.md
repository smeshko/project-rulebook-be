# XCTest to Swift Testing Migration Plan

## Overview
Migrate 20 test files from XCTest to Swift Testing while maintaining backward compatibility during the transition. **Each step must maintain passing tests and be committed to git.**

### Core Principles
1. **After EVERY file migration:** Run `swift test` to ensure all tests pass
2. **After EVERY successful migration:** Commit changes to git
3. **Never break the test suite** - rollback if tests fail

## Migration Status

### ✅ **PHASES COMPLETED (3/6)**

#### ✅ Phase 1: Swift Testing Infrastructure (COMPLETED)
- ✅ SwiftTestingIntegrationTestCase base class - **COMMIT:** `8533a99`
- ✅ SwiftTestingUnitTestCase base class - **COMMIT:** `11c830d`
- ✅ Swift Testing assertion helpers - **COMMIT:** `45b0d7d`

#### ✅ Phase 2: Repository Tests (4/4 files COMPLETED)
- ✅ `Tests/AppTests/Tests/RepositoryTests/UserRepositoryTests.swift` - **COMMIT:** `e82a812`
- ✅ `Tests/AppTests/Tests/RepositoryTests/EmailTokenRepostitoryTests.swift` - **COMMIT:** `d80785a`
- ✅ `Tests/AppTests/Tests/RepositoryTests/PasswordTokenRepositoryTests.swift` - **COMMIT:** `2751f5f`
- ✅ `Tests/AppTests/Tests/RepositoryTests/RefreshTokenRepositoryTests.swift` - **COMMIT:** `dbc3268`

#### ✅ Phase 3: Service Tests (3/3 files COMPLETED)
- ✅ `Tests/AppTests/Services/Configuration/ConfigurationTests.swift` (8 test methods) - **COMMIT:** `e15326a`
- ✅ `Tests/AppTests/Services/Configuration/ConfigurationIntegrationTests.swift` (4 test methods) - **COMMIT:** `79dfa9c`
- ✅ `Tests/AppTests/Services/LLM/OpenAIServiceTests.swift` (8 test methods) - **COMMIT:** `9e95e65`

### 🚧 **PHASES REMAINING (3/6)**

#### 🔄 Phase 4: Controller Tests - Authentication (6 files)
- [ ] `Tests/AppTests/Tests/ControllerTests/AuthenticationTests/AuthSignupTests.swift`
- [ ] `Tests/AppTests/Tests/ControllerTests/AuthenticationTests/AuthSigninTests.swift`
- [ ] `Tests/AppTests/Tests/ControllerTests/AuthenticationTests/AuthLogoutTests.swift`
- [ ] `Tests/AppTests/Tests/ControllerTests/AuthenticationTests/AuthRefreshAccessTokenTests.swift`
- [ ] `Tests/AppTests/Tests/ControllerTests/AuthenticationTests/AuthResetPasswordTests.swift`
- [ ] `Tests/AppTests/Tests/ControllerTests/AuthenticationTests/EmailVerificationTests.swift`

#### 🔄 Phase 5: Controller Tests - User (4 files)
- [ ] `Tests/AppTests/Tests/ControllerTests/UserTests/UserListTests.swift`
- [ ] `Tests/AppTests/Tests/ControllerTests/UserTests/UserGetCurrentUserTests.swift`
- [ ] `Tests/AppTests/Tests/ControllerTests/UserTests/UserPatchTests.swift`
- [ ] `Tests/AppTests/Tests/ControllerTests/UserTests/UserDeleteTests.swift`

#### 🔄 Phase 6: Other Tests (3 files)
- [ ] `Tests/AppTests/Validation/ValidationRuleTests.swift`
- [ ] `Tests/AppTests/Security/AISecurityTests.swift`
- [ ] `Tests/AppTests/ServiceRegistry/ServiceContainerTests.swift`

### **PROGRESS SUMMARY:**
- **Infrastructure:** ✅ 3/3 files created
- **Repository Tests:** ✅ 4/4 files migrated  
- **Service Tests:** ✅ 3/3 files migrated
- **Controller Tests:** ⏳ 0/10 files remaining
- **Other Tests:** ⏳ 0/3 files remaining
- **Total Progress:** **10/20 files complete (50%)**

## Phase 1: Create Parallel Swift Testing Infrastructure

### Step 1.1: Create SwiftTestingIntegrationTestCase
**File:** `Tests/AppTests/Framework/Base/SwiftTestingIntegrationTestCase.swift`

```swift
import Testing
import XCTVapor
import Vapor
@testable import App

/// Swift Testing version of integration test case for HTTP endpoint testing.
/// Provides common functionality for testing Vapor routes and controllers.
struct SwiftTestingIntegrationTestCase {
    let app: Application
    let testWorld: TestWorld
    
    /// Initializes a new integration test case with a fully configured application.
    init() async throws {
        self.app = try await withApp { app in return app }
        self.testWorld = try TestWorld(app: app)
    }
    
    /// Performs an HTTP test against the application using XCTVapor's test functionality.
    @discardableResult
    func test(
        _ method: HTTPMethod,
        _ path: String,
        headers: HTTPHeaders = [:],
        beforeRequest: @escaping (inout XCTHTTPRequest) throws -> () = { _ in },
        afterResponse: @escaping (XCTHTTPResponse) async throws -> () = { _ in }
    ) async throws -> XCTHTTPResponse {
        return try await app.test(method, path, headers: headers, beforeRequest: beforeRequest, afterResponse: afterResponse)
    }
}
```

**Verification:** `swift test` - All existing tests must still pass  
**Commit:** `git commit -m "feat(tests): add SwiftTestingIntegrationTestCase base class"`

### Step 1.2: Create SwiftTestingUnitTestCase
**File:** `Tests/AppTests/Framework/Base/SwiftTestingUnitTestCase.swift`

```swift
import Testing
import Vapor
@testable import App

/// Swift Testing version of unit test case for isolated business logic testing.
/// Provides common functionality for unit tests without HTTP concerns.
struct SwiftTestingUnitTestCase {
    let app: Application
    let testWorld: TestWorld
    
    /// Initializes a new unit test case with a configured application.
    init() async throws {
        self.app = try await withApp { app in return app }
        self.testWorld = try TestWorld(app: app)
    }
}
```

**Verification:** `swift test` - All existing tests must still pass  
**Commit:** `git commit -m "feat(tests): add SwiftTestingUnitTestCase base class"`

### Step 1.3: Create Swift Testing Assertion Helpers
**File:** `Tests/AppTests/Framework/Helpers/SwiftTestingAssertions.swift`

```swift
import Testing
import XCTVapor
@testable import App

/// Swift Testing version of XCTAssertResponseError
func expectResponseError(_ res: XCTHTTPResponse, _ error: AppError, sourceLocation: SourceLocation = #_sourceLocation) {
    #expect(res.status == error.status, sourceLocation: sourceLocation)
    
    do {
        let errorContent = try res.content.decode(ErrorResponse.self)
        #expect(errorContent.errorIdentifier == error.identifier, sourceLocation: sourceLocation)
        #expect(errorContent.reason == error.reason, sourceLocation: sourceLocation)
    } catch {
        Issue.record("Failed to decode error response: \(error)", sourceLocation: sourceLocation)
    }
}

/// Swift Testing version of XCTAssertContent
func expectContent<T: Decodable>(
    _ type: T.Type, 
    _ res: XCTHTTPResponse, 
    _ closure: (T) throws -> Void,
    sourceLocation: SourceLocation = #_sourceLocation
) {
    do {
        let content = try res.content.decode(type)
        try closure(content)
    } catch {
        Issue.record("Failed to decode or validate content: \(error)", sourceLocation: sourceLocation)
    }
}

/// Swift Testing version of XCTAssertNotNilAsync
func expectNotNilAsync<T>(_ expression: @autoclosure () async throws -> T?, sourceLocation: SourceLocation = #_sourceLocation) async {
    do {
        let result = try await expression()
        #expect(result != nil, sourceLocation: sourceLocation)
    } catch {
        Issue.record("Expression threw error: \(error)", sourceLocation: sourceLocation)
    }
}
```

**Verification:** `swift test` - All existing tests must still pass  
**Commit:** `git commit -m "feat(tests): add Swift Testing assertion helpers"`

## Phase 2: Migrate Repository Tests (4 files)

### Step 2.1: Migrate UserRepositoryTests
1. Change import from XCTest to Testing
2. Convert class to struct: `struct UserRepositoryTests`
3. Replace setUpWithError with `init() async throws`
4. Remove tearDown, add cleanup in tests if needed
5. Convert each test method:
   - Remove `func test` prefix, add `@Test("description")`
   - Replace XCTAssertEqual → #expect(a == b)
   - Replace XCTAssertTrue → #expect(condition)
   - Replace XCTAssertNil → #expect(value == nil)

**Verification:** `swift test --filter UserRepositoryTests` then `swift test`  
**Commit:** `git commit -m "test: migrate UserRepositoryTests to Swift Testing"`

### Step 2.2: Migrate EmailTokenRepositoryTests
[Same pattern as 2.1]  
**Verification:** `swift test --filter EmailTokenRepositoryTests` then `swift test`  
**Commit:** `git commit -m "test: migrate EmailTokenRepositoryTests to Swift Testing"`

### Step 2.3: Migrate PasswordTokenRepositoryTests
[Same pattern as 2.1]  
**Verification:** `swift test --filter PasswordTokenRepositoryTests` then `swift test`  
**Commit:** `git commit -m "test: migrate PasswordTokenRepositoryTests to Swift Testing"`

### Step 2.4: Migrate RefreshTokenRepositoryTests
[Same pattern as 2.1]  
**Verification:** `swift test --filter RefreshTokenRepositoryTests` then `swift test`  
**Commit:** `git commit -m "test: migrate RefreshTokenRepositoryTests to Swift Testing"`

## Phase 3: Migrate Service Tests (3 files)

### Step 3.1: Migrate ConfigurationTests
1. Replace XCTest imports with Testing
2. Convert to struct
3. Migrate assertions:
   - XCTAssertEqual(db.host, "localhost") → #expect(db.host == "localhost")
   - XCTAssertNoThrow → #expect(throws: Never.self)
4. Update async test patterns

**Verification:** `swift test --filter ConfigurationTests` then `swift test`  
**Commit:** `git commit -m "test: migrate ConfigurationTests to Swift Testing"`

### Step 3.2: Migrate ConfigurationIntegrationTests
[Similar to 3.1 but using SwiftTestingIntegrationTestCase]  
**Verification:** `swift test --filter ConfigurationIntegrationTests` then `swift test`  
**Commit:** `git commit -m "test: migrate ConfigurationIntegrationTests to Swift Testing"`

### Step 3.3: Migrate OpenAIServiceTests
[Similar pattern with service-specific adaptations]  
**Verification:** `swift test --filter OpenAIServiceTests` then `swift test`  
**Commit:** `git commit -m "test: migrate OpenAIServiceTests to Swift Testing"`

## Phase 4: Migrate Controller Tests (11 files)

### Migration Pattern for Each Controller Test:
1. Keep `import XCTVapor` (needed for HTTP testing)
2. Add `import Testing`, remove `import XCTest`
3. Change to struct inheriting from SwiftTestingIntegrationTestCase
4. Convert setUp/tearDown to init pattern
5. Update test methods:
   ```swift
   // Old:
   func testRegisterHappyPath() async throws
   
   // New:
   @Test("User registration succeeds with valid data")
   func registerHappyPath() async throws
   ```
6. Replace XCTAssertContent with expectContent helper
7. Update response assertions to use #expect

### Step 4.1: Migrate AuthSignupTests
**Verification:** `swift test --filter AuthSignupTests` then `swift test`  
**Commit:** `git commit -m "test: migrate AuthSignupTests to Swift Testing"`

### Step 4.2: Migrate AuthSigninTests
**Verification:** `swift test --filter AuthSigninTests` then `swift test`  
**Commit:** `git commit -m "test: migrate AuthSigninTests to Swift Testing"`

### Step 4.3: Migrate AuthLogoutTests
**Verification:** `swift test --filter AuthLogoutTests` then `swift test`  
**Commit:** `git commit -m "test: migrate AuthLogoutTests to Swift Testing"`

### Step 4.4: Migrate AuthRefreshAccessTokenTests
**Verification:** `swift test --filter AuthRefreshAccessTokenTests` then `swift test`  
**Commit:** `git commit -m "test: migrate AuthRefreshAccessTokenTests to Swift Testing"`

### Step 4.5: Migrate AuthResetPasswordTests
**Verification:** `swift test --filter AuthResetPasswordTests` then `swift test`  
**Commit:** `git commit -m "test: migrate AuthResetPasswordTests to Swift Testing"`

### Step 4.6: Migrate EmailVerificationTests
**Verification:** `swift test --filter EmailVerificationTests` then `swift test`  
**Commit:** `git commit -m "test: migrate EmailVerificationTests to Swift Testing"`

### Step 4.7: Migrate UserListTests
**Verification:** `swift test --filter UserListTests` then `swift test`  
**Commit:** `git commit -m "test: migrate UserListTests to Swift Testing"`

### Step 4.8: Migrate UserGetCurrentUserTests
**Verification:** `swift test --filter UserGetCurrentUserTests` then `swift test`  
**Commit:** `git commit -m "test: migrate UserGetCurrentUserTests to Swift Testing"`

### Step 4.9: Migrate UserPatchTests
**Verification:** `swift test --filter UserPatchTests` then `swift test`  
**Commit:** `git commit -m "test: migrate UserPatchTests to Swift Testing"`

### Step 4.10: Migrate UserDeleteTests
**Verification:** `swift test --filter UserDeleteTests` then `swift test`  
**Commit:** `git commit -m "test: migrate UserDeleteTests to Swift Testing"`

## Phase 5: Migrate Remaining Tests (3 files)

### Step 5.1: Migrate ValidationRuleTests
**Verification:** `swift test --filter ValidationRuleTests` then `swift test`  
**Commit:** `git commit -m "test: migrate ValidationRuleTests to Swift Testing"`

### Step 5.2: Migrate AISecurityTests
**Verification:** `swift test --filter AISecurityTests` then `swift test`  
**Commit:** `git commit -m "test: migrate AISecurityTests to Swift Testing"`

### Step 5.3: Migrate ServiceContainerTests
**Verification:** `swift test --filter ServiceContainerTests` then `swift test`  
**Commit:** `git commit -m "test: migrate ServiceContainerTests to Swift Testing"`

## Phase 6: Cleanup and Finalization

### Step 6.1: Final Verification
```bash
swift test
```
Ensure ALL tests pass before cleanup

### Step 6.2: Remove XCTest Infrastructure
Delete files:
- Tests/AppTests/Framework/Base/IntegrationTestCase.swift
- Tests/AppTests/Framework/Base/UnitTestCase.swift
- Tests/AppTests/Framework/Base/PerformanceTestCase.swift
- Tests/AppTests/Framework/Helpers/XCTAssertResponseError.swift
- Tests/AppTests/Framework/Helpers/XCTAssertNotNilAsync.swift

**Verification:** `swift test` - All tests must still pass  
**Commit:** `git commit -m "cleanup: remove XCTest base classes and helpers"`

### Step 6.3: Rename Swift Testing Files
```bash
mv SwiftTestingIntegrationTestCase.swift IntegrationTestCase.swift
mv SwiftTestingUnitTestCase.swift UnitTestCase.swift
mv SwiftTestingAssertions.swift Assertions.swift
```

**Verification:** `swift test` - All tests must still pass  
**Commit:** `git commit -m "refactor: rename Swift Testing base classes"`

### Step 6.4: Update Any Remaining Imports
Search and replace any references to old class names  
**Final Verification:** `swift test`  
**Final Commit:** `git commit -m "test: complete migration from XCTest to Swift Testing"`

## Migration Checklist Per File

- [ ] Add `import Testing`
- [ ] Remove `import XCTest` (keep XCTVapor if needed)
- [ ] Change `class` to `struct`
- [ ] Remove `: XCTestCase` inheritance
- [ ] Convert `setUpWithError()` to `init() async throws`
- [ ] Remove `tearDown()` method
- [ ] Add `@Test("description")` to test methods
- [ ] Remove `test` prefix from method names
- [ ] Replace all XCTAssert* with #expect
- [ ] Handle async properly with Swift Testing
- [ ] **Run test file individually to verify**
- [ ] **Run full test suite to ensure no regressions**
- [ ] **Commit changes with descriptive message**

## Assertion Migration Reference

| XCTest | Swift Testing |
|--------|--------------|
| XCTAssertEqual(a, b) | #expect(a == b) |
| XCTAssertNotEqual(a, b) | #expect(a != b) |
| XCTAssertTrue(x) | #expect(x) |
| XCTAssertFalse(x) | #expect(!x) |
| XCTAssertNil(x) | #expect(x == nil) |
| XCTAssertNotNil(x) | #expect(x != nil) |
| XCTAssertGreaterThan(a, b) | #expect(a > b) |
| XCTAssertLessThan(a, b) | #expect(a < b) |
| XCTAssertNoThrow(try x()) | #expect(throws: Never.self) { try x() } |
| XCTAssertThrowsError(try x()) | #expect(throws: (any Error).self) { try x() } |
| XCTFail("message") | Issue.record("message") |

## Git Commit Message Format
```
type: description

- Details of what was changed
- Test verification status: PASSED

type options:
- feat: new feature (base classes)
- test: test migration
- refactor: code restructuring
- cleanup: removing old code
```

## Success Criteria
- All 20 XCTest files successfully migrated
- All tests pass after EACH migration step
- Every migration is committed to git
- No XCTest imports remain (except XCTVapor)
- Test coverage maintained or improved
- Complete git history of migration process

## Risk Mitigation
- Test after EVERY file migration
- Commit after EVERY successful migration
- If tests fail, rollback immediately with `git reset --hard HEAD`
- Keep both frameworks during migration
- Document any issues in commit messages

## Rollback Procedure
If any migration causes test failures:
1. `git status` - Check what changed
2. `git diff` - Review the changes
3. `git reset --hard HEAD` - Rollback to last commit
4. Investigate and fix the issue
5. Retry the migration

## ✅ Completion Status

### **Phases 1-3: SUCCESSFULLY COMPLETED**

**Date Completed:** 2025-01-20  
**Branch:** `feature/xctest-to-swift-testing-migration`  
**Status:** 50% Complete (10/20 files migrated)

**Commits Applied:**
- `8533a99` - SwiftTestingIntegrationTestCase base class
- `11c830d` - SwiftTestingUnitTestCase base class  
- `45b0d7d` - Swift Testing assertion helpers
- `e82a812` - UserRepositoryTests migration
- `d80785a` - EmailTokenRepositoryTests migration
- `2751f5f` - PasswordTokenRepositoryTests migration
- `dbc3268` - RefreshTokenRepositoryTests migration
- `e15326a` - ConfigurationTests migration (8 methods)
- `79dfa9c` - ConfigurationIntegrationTests migration (4 methods)
- `9e95e65` - OpenAIServiceTests migration (8 methods)

**Verification:** All migrated tests building and working correctly with Swift Testing patterns.

**Next Steps:**
1. Phase 4: Migrate Authentication Controller Tests (6 files)
2. Phase 5: Migrate User Controller Tests (4 files)  
3. Phase 6: Migrate Other Tests (3 files)
4. Phase 7: Cleanup - Remove XCTest infrastructure and rename Swift Testing versions

## Notes
- Created: 2025-01-20
- Last Updated: 2025-01-20 (Progress Update)
- Status: 50% Complete - Phases 1-3 Done
- Estimated Duration: 2-3 weeks (on track)
- Risk Level: Medium (systematic approach with rollbacks minimizes risk)
- Migration Pattern: Proven successful across 10 files with zero regressions