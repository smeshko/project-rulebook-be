# Story 1.2: Implement Remote Config Endpoint

Status: complete
Linear Issue: RULE-151
Epic: 1 - API Versioning & Stability
Created: 2025-12-28

---

## Story

As a mobile app,
I want to fetch feature flags and configuration from the backend,
so that app behavior can be controlled remotely without app updates.

## Acceptance Criteria

**Given** a GET request to `/api/v1/config`
**When** the request is made
**Then** response returns a JSON dictionary of configuration values:
```json
{
  "featureFlags": {
    "enableNewScanner": true,
    "showPromotion": false
  },
  "settings": {
    "maxRetries": 3,
    "cacheTimeoutSeconds": 300
  },
  "version": "1.0.0"
}
```

**Given** the config endpoint
**When** it is called
**Then** it does NOT require authentication (public endpoint)

**Given** configuration data
**When** stored in the system
**Then** it is persisted in PostgreSQL with Redis caching (5 min TTL)

**Given** configuration values
**When** defining them
**Then** they support typed values: boolean, integer, string, JSON object

**Given** an admin endpoint `/api/v1/admin/config`
**When** an authenticated admin updates configuration
**Then** the cache is invalidated and new values take effect immediately

**Given** a cache miss
**When** Redis cache expires
**Then** configuration is re-fetched from PostgreSQL and cached

## Tasks / Subtasks

- [x] Create Config module structure following established patterns (AC: all)
  - [x] Create `Sources/App/Modules/Config/` directory
  - [x] Create `ConfigModule.swift` for registration
  - [x] Create `ConfigRouter.swift` for route definitions
  - [x] Create `Controller/ConfigController.swift`
  - [x] Create `Models/Config+Model.swift` for request/response DTOs
  - [x] Create `Database/Models/ConfigValueModel.swift`
  - [x] Create `Database/Migrations/ConfigMigrations.swift`
  - [x] Create `Repositories/ConfigRepository.swift`

- [x] Implement database model for config values (AC: 4)
  - [x] Define ConfigValueModel with fields: id, key, value (JSON), type, createdAt, updatedAt
  - [x] Create migration with unique constraint on key
  - [x] Support types: boolean, integer, string, json

- [x] Implement config repository (AC: 3, 6)
  - [x] Define ConfigRepository protocol
  - [x] Implement DatabaseConfigRepository with CRUD operations
  - [x] Add method to get all config values
  - [x] Register repository in Application-Setup.swift

- [x] Implement public GET /api/v1/config endpoint (AC: 1, 2)
  - [x] Return structured response with featureFlags, settings, version
  - [x] No authentication required (public endpoint)
  - [x] Transform database values into nested response structure

- [x] Implement Redis caching for config (AC: 3, 6)
  - [x] Cache entire config response in Redis with 5-minute TTL
  - [x] Check cache first before database query
  - [x] Re-cache on miss

- [x] Implement admin PUT /api/v1/admin/config endpoint (AC: 5)
  - [x] Require admin authentication (EnsureAdminUserMiddleware)
  - [x] Accept config key-value updates
  - [x] Invalidate Redis cache on update
  - [x] Return updated config

- [x] Register module in Application-Setup.swift
  - [x] Add ConfigModule() to modules array
  - [x] Register ConfigRepository

- [x] Write comprehensive tests
  - [x] Test public endpoint returns config without auth
  - [x] Test config structure matches expected format
  - [x] Test admin endpoint requires authentication
  - [x] Test cache invalidation on update
  - [x] Test typed value handling (boolean, integer, string, JSON)

---

## Relevant Feature Documentation

### API Versioning Strategy
[Source: docs/features/api-versioning.md]

**Key Patterns to Follow:**

```swift
// Standard versioned router pattern
func boot(routes: RoutesBuilder) throws {
    let api = routes
        .grouped("api")
        .grouped("v1")           // REQUIRED: Version prefix
        .grouped("config")
        .groupedOpenAPI(tags: .init(name: "Config", description: "Remote configuration"))

    // Define routes under the api group
    api.get(use: controller.getConfig)
}
```

**Testing Pattern:**
```swift
@Test("Config endpoint accessible with v1 prefix")
func testVersionedEndpoint() async throws {
    try await app.test(.GET, "api/v1/config") { req in
        // No auth required
    } afterResponse: { response in
        #expect(response.status == .ok)
    }
}
```

---

## Developer Context

### Technical Requirements

**Swift 6 Concurrency:**
- All handlers MUST use `async/await`
- Mark actors and sendable types correctly
- Services accessed via `req` are already on correct isolation
- NO `DispatchQueue` for async work

**Module Boundaries:**
- Each module owns its Router, Controller, Models, Repository
- NEVER import one module's internal types into another
- Cross-module communication through Services only
- Controllers call Services, Services call Repositories

**Error Handling:**
- All errors MUST conform to `AppError` enum pattern
- DO NOT throw raw `Abort(.badRequest)` directly

### Architecture Compliance

**Module Structure (MUST FOLLOW):**
```
Modules/Config/
├── ConfigModule.swift         # Module registration (see WaitlistModule pattern)
├── ConfigRouter.swift         # Route definitions (see WaitlistRouter pattern)
├── Controller/
│   └── ConfigController.swift # HTTP endpoints + business logic
├── Models/
│   └── Config+Model.swift     # Request/Response Codable types
├── Database/
│   ├── Models/
│   │   └── ConfigValueModel.swift  # Fluent @Model class
│   └── Migrations/
│       └── ConfigMigrations.swift  # Migration definition
└── Repositories/
    └── ConfigRepository.swift # Protocol + Database implementation
```

**Service Access Pattern:**
```swift
// In controllers - use req.repositories.*
func getConfig(_ req: Request) async throws -> Config.Response {
    let repository = req.repositories.config
    let values = try await repository.all()
    return Config.Response(from: values)
}
```

**Database Model Pattern (from WaitlistEntryModel):**
```swift
final class ConfigValueModel: @unchecked Sendable, DatabaseModelInterface {
    typealias Module = ConfigModule
    static var schema: String { "config_values" }

    @ID()
    var id: UUID?

    @Field(key: FieldKeys.v1.key)
    var key: String

    @Field(key: FieldKeys.v1.value)
    var value: String  // JSON encoded

    @Field(key: FieldKeys.v1.valueType)
    var valueType: String  // boolean, integer, string, json

    @Timestamp(key: FieldKeys.v1.createdAt, on: .create)
    var createdAt: Date?

    @Timestamp(key: FieldKeys.v1.updatedAt, on: .update)
    var updatedAt: Date?
}
```

### Library & Framework Requirements

**Vapor 4.110+ with Swift 6.0:**
- Use `RoutesBuilder.grouped()` for route prefixes
- Use `VaporToOpenAPI` for OpenAPI documentation
- Use Fluent 4.8+ for database operations
- Use Redis via `RedisCacheService` pattern

**Redis Caching Pattern (from RedisCacheService):**
```swift
// Get with TTL
let cached = try await req.cacheService.get("config:all", as: ConfigResponse.self)
if let cached = cached { return cached }

// Set with 5-minute TTL
try await req.cacheService.set("config:all", value: response, ttl: 300)
```

**Admin Authentication (from CacheAdminRouter):**
```swift
let adminAPI = api
    .grouped(UserAccountModel.guard())
    .grouped(EnsureAdminUserMiddleware())
```

### File Structure Requirements

**Files to Create:**
```
Sources/App/Modules/Config/
├── ConfigModule.swift
├── ConfigRouter.swift
├── Controller/
│   └── ConfigController.swift
├── Models/
│   └── Config+Model.swift
├── Database/
│   ├── Models/
│   │   └── ConfigValueModel.swift
│   └── Migrations/
│       └── ConfigMigrations.swift
└── Repositories/
    └── ConfigRepository.swift

Tests/AppTests/Tests/ControllerTests/ConfigTests/
├── ConfigGetTests.swift
└── ConfigAdminTests.swift
```

**Files to Modify:**
- `Sources/App/Entrypoint/Application-Setup.swift` - Add ConfigModule to modules array, register repository

### Testing Requirements

**IsolatedTestWorld Pattern:**
```swift
@Suite(.serialized)
struct ConfigGetTests {
    let testWorld: IsolatedTestWorld

    init() async throws {
        testWorld = try await IsolatedTestWorld()
    }

    @Test func testConfigEndpoint() async throws {
        try await testWorld.app.test(.GET, "api/v1/config") { res in
            #expect(res.status == .ok)
        }
    }
}
```

**Test Cases Required:**
1. Public endpoint returns 200 without authentication
2. Response structure matches expected JSON format
3. Admin endpoint returns 401 without authentication
4. Admin endpoint returns 200 with valid admin token
5. Cache is populated on first request
6. Cache is invalidated after admin update
7. Different value types (boolean, integer, string, JSON) serialize correctly

---

## Previous Story Intelligence

### Story 1.1 Learnings
[Source: _bmad-output/implementation-artifacts/1-1-add-api-version-prefix-to-all-public-routes.md]

**Router Updates Pattern:**
- All 4 main module routers use `.grouped("v1")` at line 10
- Pattern: `.grouped("api").grouped("v1").grouped("{module-name}")`
- VaporToOpenAPI `.groupedOpenAPI()` comes AFTER version prefix

**Test Updates Pattern:**
- All test paths use `/api/v1/` prefix
- Negative tests verify old routes return 404
- Use `app.test(.METHOD, "api/v1/...")` pattern

**Rate Limit Configuration:**
- If adding new rate limit type, update `RateLimitConfiguration.swift`
- Update `MockRateLimitService` for testing
- All configurations (default, production, development) must include new limit type

**Files Changed in Story 1.1:**
- `Sources/App/Modules/*/Router.swift` - Added `.grouped("v1")`
- `Sources/App/Middlewares/Security/RateLimit/RateLimitConfiguration.swift`
- `Tests/AppTests/Framework/Mocks/Services/MockRateLimitService.swift`
- Various test files updated to use versioned paths

---

## Git Intelligence

### Recent Commits (from main branch)
- `4a42d69` - Merge PR #26: Story 1.1 - Add v1 prefix to all routes

**Patterns Observed:**
- API versioning is complete and all routes use `/api/v1/` prefix
- Rate limiting is configured per-operation type
- IsolatedTestWorld pattern used for testing

---

## Latest Technical Information

**Vapor 4.x / Swift 6.0:**
- Strict concurrency checking enabled
- All async operations must use `async/await`
- `@unchecked Sendable` needed for database models with property wrappers

**Fluent 4.8+:**
- Use `@Field`, `@ID`, `@Timestamp` property wrappers
- Migrations use `AsyncMigration` protocol
- Database operations are fully async

**Redis Integration:**
- Use `RedisCacheService` from `Sources/App/Services/Cache/`
- TTL specified in seconds as `TimeInterval`
- JSON encoding/decoding handled automatically

---

## Project Context Reference

See: docs/project-context.md

Key patterns and rules from project context:

**Naming Conventions:**
| Area | Convention | Example |
|------|------------|---------|
| Database tables | snake_case, plural | `config_values` |
| Database columns | snake_case | `created_at`, `value_type` |
| API endpoints | kebab-case with `/v1/` | `/api/v1/config`, `/api/v1/admin/config` |
| Swift types | PascalCase | `ConfigController`, `ConfigValueModel` |
| Swift properties | camelCase | `valueType`, `createdAt` |
| Protocols | PascalCase | `ConfigRepository` |

**Anti-Patterns (NEVER DO):**
- `DispatchQueue.global().async` - Use `async/await`
- `try! force unwrap` - Handle errors properly
- Raw `Abort()` throws - Use `AppError` enum
- Hardcoded secrets - Use environment variables
- Creating new patterns - Follow existing patterns

**Quick Reference - Adding a new module:**
1. Create directory structure per pattern above
2. Register in `Application-Setup.swift` modules array
3. Add routes via module's router
4. Register repository in setupServices()

---

## Dev Notes

### Implementation Notes

**Response Structure Design:**
The config endpoint should return a nested structure that mobile apps can easily consume:
```swift
struct ConfigResponse: Content {
    let featureFlags: [String: Bool]
    let settings: [String: AnyCodable]  // Or use JSON encoding
    let version: String
}
```

Consider using a generic approach for the settings values since they can be boolean, integer, string, or JSON objects.

**Database Design:**
Store config values as key-value pairs in `config_values` table:
- `key`: unique string identifier (e.g., "featureFlags.enableNewScanner")
- `value`: JSON-encoded value
- `value_type`: enum/string for type validation

**Seeding Initial Config:**
Consider creating a seed migration that populates default config values, or handle missing keys gracefully in the controller.

### Project Structure Notes

- Alignment with unified project structure: Follows Modules/ pattern exactly
- No conflicts or variances detected

### References

- [Source: docs/project-context.md#module-structure]
- [Source: docs/architecture/technical-architecture.md#module-architecture]
- [Source: docs/features/api-versioning.md]
- [Source: _bmad-output/epics.md#story-1.2]
- [Source: _bmad-output/implementation-artifacts/1-1-add-api-version-prefix-to-all-public-routes.md]
- [Source: Sources/App/Modules/Waitlist/WaitlistModule.swift] - Module registration pattern
- [Source: Sources/App/Modules/Waitlist/WaitlistRouter.swift] - Router pattern
- [Source: Sources/App/Modules/Waitlist/WaitlistController.swift] - Controller pattern
- [Source: Sources/App/Modules/Waitlist/Database/Models/WaitlistEntryModel.swift] - Database model pattern
- [Source: Sources/App/Modules/Waitlist/Database/Migrations/WaitlistMigrations.swift] - Migration pattern
- [Source: Sources/App/Modules/Waitlist/Repositories/WaitlistRepository.swift] - Repository pattern
- [Source: Sources/App/Modules/CacheAdmin/CacheAdminRouter.swift] - Admin authentication pattern
- [Source: Sources/App/Services/Cache/RedisCacheService.swift] - Redis caching pattern
- [Source: Sources/App/Entrypoint/Application-Setup.swift:82-99] - Module registration

---

## Dev Agent Record

### Context Reference

Ultimate context engine analysis completed - comprehensive developer guide created.

### Agent Model Used

claude-opus-4-5-20251101

### Debug Log References

### Completion Notes List

- Exhaustive artifact analysis completed for: epics.md, project-context.md, technical-architecture.md, api-versioning.md, previous story 1-1, Application-Setup.swift, all Waitlist module files
- Previous story intelligence extracted from Story 1.1
- Git intelligence analyzed from recent commits
- Module patterns documented from existing Waitlist and CacheAdmin modules
- All acceptance criteria mapped to tasks
- Architecture compliance requirements extracted

### File List

Sources/App/Modules/Config/ConfigModule.swift
Sources/App/Modules/Config/ConfigRouter.swift
Sources/App/Modules/Config/Controller/ConfigController.swift
Sources/App/Modules/Config/Models/Config+Model.swift
Sources/App/Modules/Config/Database/Models/ConfigValueModel.swift
Sources/App/Modules/Config/Database/Migrations/ConfigMigrations.swift
Sources/App/Modules/Config/Repositories/ConfigRepository.swift
Sources/App/Entrypoint/Application-Setup.swift (modify)
Tests/AppTests/Tests/ControllerTests/ConfigTests/ConfigGetTests.swift
Tests/AppTests/Tests/ControllerTests/ConfigTests/ConfigAdminTests.swift
