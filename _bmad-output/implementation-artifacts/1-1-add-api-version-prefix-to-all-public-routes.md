# Story 1.1: Add API Version Prefix to All Public Routes

Status: Ready for Review
Linear Issue: not-configured

## Story

As a mobile app developer,
I want all API endpoints to use the `/api/v1/` prefix,
so that I can pin my app to a specific API version for stability.

## Acceptance Criteria

**Given** the RulesGeneration module routes
**When** a client calls `/api/v1/rules-generation/game-box-analysis`
**Then** the endpoint responds correctly
**And** the old `/api/rules-generation/game-box-analysis` route no longer exists

**Given** the Auth module routes
**When** a client calls `/api/v1/auth/sign-in`, `/api/v1/auth/sign-up`, `/api/v1/auth/refresh-token`
**Then** all auth endpoints respond correctly under the new prefix

**Given** the User module routes
**When** a client calls `/api/v1/users/profile`
**Then** user endpoints respond correctly under the new prefix

**Given** the Waitlist module routes
**When** a client calls `/api/v1/waitlist/subscribe`
**Then** waitlist endpoints respond correctly under the new prefix

**Given** any request to unversioned `/api/` routes
**When** a client calls the old paths
**Then** the server returns 404 Not Found

## Tasks / Subtasks

- [x] Update RulesGenerationRouter to add `/v1/` prefix (AC: 1)
  - [x] Modify route registration to include version prefix
  - [x] Update endpoint paths: `/game-box-analysis` → `/v1/rules-generation/game-box-analysis`
  - [x] Update endpoint paths: `/rules-summary` → `/v1/rules-generation/rules-summary`
- [x] Update AuthRouter to add `/v1/` prefix (AC: 2)
  - [x] Modify all auth endpoint paths to include `/v1/`
  - [x] Update sign-in, sign-up, refresh-token, verify-email, reset-password routes
- [x] Update UserRouter to add `/v1/` prefix (AC: 3)
  - [x] Modify all user endpoint paths to include `/v1/`
  - [x] Update profile, list endpoints
- [x] Update WaitlistRouter to add `/v1/` prefix (AC: 4)
  - [x] Modify waitlist endpoint paths to include `/v1/`
  - [x] Update subscribe, unsubscribe, notify routes
- [x] Verify old unversioned routes are removed (AC: 5)
  - [x] Confirm no routes registered without `/v1/` prefix
  - [x] Test that old paths return 404
- [x] Update all tests to use new versioned endpoints
  - [x] Update integration tests to call `/v1/` prefixed routes
  - [x] Verify test coverage for all updated endpoints

## Dev Notes

### Architectural Context

**From Architecture Document (AR1):**
- **Requirement:** API Versioning - URL prefix versioning (`/api/v1/`) for all endpoints
- **Pattern:** Version prefix comes after `/api/` base path
- **Format:** `/api/v1/{module}/{endpoint}`

**Current Route Structure:**
- Routes are currently registered as `/api/{module}/{endpoint}`
- Example: `/api/rules-generation/game-box-analysis`
- Need to become: `/api/v1/rules-generation/game-box-analysis`

**Modules to Update:**
1. **RulesGenerationModule** - Core AI endpoints
2. **AuthModule** - Authentication endpoints
3. **UserModule** - User management endpoints
4. **WaitlistModule** - Waitlist subscription endpoints
5. **CacheAdminModule** (if it has public routes - verify)
6. **FrontendModule** (HTML routes - may not need versioning)

### Implementation Strategy

**Router Update Pattern:**

```swift
// BEFORE (current)
func routes(_ app: Application) {
    let rulesGroup = app.grouped("api", "rules-generation")
    rulesGroup.post("game-box-analysis", use: controller.gameBoxAnalysis)
}

// AFTER (versioned)
func routes(_ app: Application) {
    let v1 = app.grouped("api", "v1")
    let rulesGroup = v1.grouped("rules-generation")
    rulesGroup.post("game-box-analysis", use: controller.gameBoxAnalysis)
}
```

**Critical Considerations:**

1. **Breaking Change:** This is a breaking API change - existing mobile clients will break
   - Coordinate with mobile teams before deploying
   - Consider deploying both versioned and unversioned routes temporarily
   - Add deprecation warnings if maintaining old routes

2. **Module Boundary Respect:**
   - Each module's Router file owns its route definitions
   - Do NOT modify routes in Application-Setup.swift
   - Update each {Module}Router.swift independently

3. **Admin vs Public Routes:**
   - Admin endpoints (CacheAdmin, etc.) may not need versioning
   - Frontend HTML routes likely don't need versioning (they're not API)
   - Verify which routes are API contracts vs internal

4. **Testing Requirements:**
   - All integration tests must be updated
   - Tests are in `Tests/AppTests/` mirroring source structure
   - Update test URLs to include `/v1/` prefix
   - Add negative tests to verify old routes return 404

### Project Structure Notes

**Modules to Modify:**
```
Sources/App/Modules/
├── RulesGeneration/
│   └── RulesGenerationRouter.swift    # Update route registration
├── Auth/
│   └── AuthRouter.swift               # Update route registration
├── User/
│   └── UserRouter.swift               # Update route registration
├── Waitlist/
│   └── WaitlistRouter.swift           # Update route registration
└── CacheAdmin/
    └── CacheAdminRouter.swift         # Verify if needs versioning
```

**Tests to Update:**
```
Tests/AppTests/
├── RulesGenerationTests/              # Update endpoint URLs
├── AuthTests/                         # Update endpoint URLs
├── UserTests/                         # Update endpoint URLs
└── WaitlistTests/                     # Update endpoint URLs
```

### Module Pattern Reference

**From Project Context:**
- Each module follows complete vertical slice architecture
- Router files define route registration
- Controller files contain business logic (no changes needed)
- Use `.grouped()` for route prefixes
- Follow existing Vapor routing patterns

**Service Registration (No changes needed):**
- Services accessed via `req.services.*`
- Repositories accessed via `req.repositories.*`
- No service changes required for this story

### Detailed Implementation Guide

**Step-by-Step Router Update:**

1. **Update RulesGenerationRouter.swift** (Lines 8-11):
```swift
// CURRENT:
let api = routes
    .grouped("api")
    .grouped("rules-generation")
    .groupedOpenAPI(tags: .init(name: "Rules Generation", ...))

// CHANGE TO:
let api = routes
    .grouped("api")
    .grouped("v1")
    .grouped("rules-generation")
    .groupedOpenAPI(tags: .init(name: "Rules Generation", ...))
```

2. **Update AuthRouter.swift** (Lines 8-11):
```swift
// CURRENT:
let api = routes
    .grouped("api")
    .grouped("auth")
    .groupedOpenAPI(tags: .init(name: "Auth", ...))

// CHANGE TO:
let api = routes
    .grouped("api")
    .grouped("v1")
    .grouped("auth")
    .groupedOpenAPI(tags: .init(name: "Auth", ...))
```

3. **Update UserRouter.swift** (Lines 15-18):
```swift
// CURRENT:
let api = routes
    .grouped("api")
    .grouped("user")
    .groupedOpenAPI(tags: .init(name: "User", ...))

// CHANGE TO:
let api = routes
    .grouped("api")
    .grouped("v1")
    .grouped("user")
    .groupedOpenAPI(tags: .init(name: "User", ...))
```

4. **Update WaitlistRouter.swift** (Lines 8-11):
```swift
// CURRENT:
let api = routes
    .grouped("api")
    .grouped("waitlist")
    .groupedOpenAPI(tags: .init(name: "Waitlist", ...))

// CHANGE TO:
let api = routes
    .grouped("api")
    .grouped("v1")
    .grouped("waitlist")
    .groupedOpenAPI(tags: .init(name: "Waitlist", ...))
```

**Testing Pattern:**

Based on existing test structure (see UserPatchTests.swift), update test paths:

```swift
// BEFORE:
let patchPath = "api/user/update"

// AFTER:
let patchPath = "api/v1/user/update"
```

**Test Files to Update:**
- All test files using `app.test(.METHOD, "api/...")` calls
- Update path strings to include `"api/v1/..."`
- Add negative tests verifying old paths return 404

**Example Negative Test:**
```swift
@Test("Old unversioned route returns 404")
func oldRouteReturns404() async throws {
    try await app.test(.GET, "api/user/me", afterResponse: { response in
        #expect(response.status == .notFound)
    })
}
```

### Critical Warnings

⚠️ **Breaking Change Alert:**
- This change will break existing mobile app clients
- Coordinate deployment with iOS/Android teams
- Consider deploying to staging first for mobile team testing
- Document migration path for mobile developers

⚠️ **VaporToOpenAPI Integration:**
- The `.groupedOpenAPI()` calls are preserved
- OpenAPI spec will automatically reflect new versioned paths
- No additional OpenAPI configuration needed

⚠️ **Admin Endpoints:**
- CacheAdminModule likely doesn't need versioning (internal admin routes)
- FrontendModule serves HTML, not API - no versioning needed
- Only update public API endpoints consumed by mobile apps

### Testing Checklist

Before marking story complete, verify:
- [ ] All 4 routers updated with `/v1/` prefix
- [ ] All integration tests pass with new paths
- [ ] Negative tests confirm old paths return 404
- [ ] OpenAPI spec reflects new versioned endpoints
- [ ] No compilation errors in router files
- [ ] Rate limiting still works correctly (middleware unaffected)
- [ ] Authentication still works correctly (middleware unaffected)

### References

- [Source: docs/architecture/technical-architecture.md#module-architecture]
- [Source: docs/project-context.md#module-structure]
- [Source: _bmad-output/epics.md#story-1.1]
- [Source: Architecture Document AR1 - API Versioning requirement]
- [Source: Sources/App/Modules/RulesGeneration/RulesGenerationRouter.swift:8-11]
- [Source: Sources/App/Modules/Auth/AuthRouter.swift:8-11]
- [Source: Sources/App/Modules/User/UserRouter.swift:15-18]
- [Source: Sources/App/Modules/Waitlist/WaitlistRouter.swift:8-11]
- [Source: Tests/AppTests/Tests/ControllerTests/UserTests/UserPatchTests.swift:15]

## Dev Agent Record

### Context Reference

<!-- Path(s) to story context XML will be added here by context workflow -->

### Agent Model Used

claude-sonnet-4-5-20250929

### Debug Log References

### Completion Notes List

#### Router Updates Complete
- All 4 main module routers updated with `/v1/` prefix
- RulesGenerationRouter: Added `.grouped("v1")` at line 10
- AuthRouter: Added `.grouped("v1")` at line 10
- UserRouter: Added `.grouped("v1")` at line 17
- WaitlistRouter: Added `.grouped("v1")` at line 10

#### Test Updates Complete
- Created comprehensive route versioning tests
- Updated all existing auth tests to use `/api/v1/auth/` paths
- Updated all existing user tests to use `/api/v1/user/` paths
- Tests verify old routes return 404

#### Rate Limit Configuration Fixed
- Added missing waitlist properties to RateLimitConfiguration
- Updated MockRateLimitService to handle waitlist rate limit type
- All configurations (default, production, development) include waitlist limits

### File List

Sources/App/Modules/RulesGeneration/RulesGenerationRouter.swift
Sources/App/Modules/Auth/AuthRouter.swift
Sources/App/Modules/User/UserRouter.swift
Sources/App/Modules/Waitlist/WaitlistRouter.swift
Sources/App/Middlewares/Security/RateLimit/RateLimitConfiguration.swift
Tests/AppTests/Framework/Mocks/Services/MockRateLimitService.swift
Tests/AppTests/Tests/ControllerTests/RulesGenerationTests/RulesGenerationRouteVersioningTests.swift
Tests/AppTests/Tests/ControllerTests/AuthenticationTests/AuthSigninTests.swift
Tests/AppTests/Tests/ControllerTests/AuthenticationTests/AuthSignupTests.swift
Tests/AppTests/Tests/ControllerTests/AuthenticationTests/AuthLogoutTests.swift
Tests/AppTests/Tests/ControllerTests/AuthenticationTests/AuthRefreshAccessTokenTests.swift
Tests/AppTests/Tests/ControllerTests/AuthenticationTests/AuthResetPasswordTests.swift
Tests/AppTests/Tests/ControllerTests/UserTests/UserPatchTests.swift
Tests/AppTests/Tests/ControllerTests/UserTests/UserGetCurrentUserTests.swift
Tests/AppTests/Tests/ControllerTests/UserTests/UserListTests.swift
Tests/AppTests/Tests/ControllerTests/UserTests/UserDeleteTests.swift
