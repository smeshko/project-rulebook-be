# Story 1.2: Implement Remote Config Endpoint

Status: done
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

- [x] Create Config module structure (AC: 3, 4)
  - [x] Create `Sources/App/Modules/Config/ConfigModule.swift`
  - [x] Create `Sources/App/Modules/Config/ConfigRouter.swift`
  - [x] Create `Sources/App/Modules/Config/ConfigController.swift`
  - [x] Create `Sources/App/Modules/Config/Models/Config+Model.swift` (DTOs)
  - [x] Create `Sources/App/Modules/Config/Database/Models/ConfigEntryModel.swift`
  - [x] Create `Sources/App/Modules/Config/Database/Migrations/ConfigMigrations.swift`
  - [x] Create `Sources/App/Modules/Config/Repositories/ConfigRepository.swift`
- [x] Implement database model for config entries (AC: 3, 4)
  - [x] Define `ConfigEntryModel` with fields: `id`, `key`, `value` (JSONB), `type`, `createdAt`, `updatedAt`
  - [x] Create v1 migration with unique constraint on `key`
  - [x] Create seed migration with initial feature flags and settings
- [x] Implement config repository (AC: 3, 6)
  - [x] Define `ConfigRepository` protocol
  - [x] Implement `DatabaseConfigRepository` with CRUD operations
  - [x] Add `findAll()` method for fetching all config entries
  - [x] Register repository in `Application+Repository.swift` and `Application-Setup.swift`
- [x] Implement public config endpoint (AC: 1, 2, 6)
  - [x] Implement `GET /api/v1/config` route (no auth required)
  - [x] Fetch config from Redis cache first
  - [x] On cache miss, fetch from PostgreSQL and cache result
  - [x] Transform database entries into response DTO format
- [x] Implement Redis caching layer (AC: 3, 6)
  - [x] Use existing `CacheService` (RedisCacheService)
  - [x] Set cache key: `config:all`
  - [x] Set TTL: 300 seconds (5 minutes)
  - [x] Serialize response DTO as JSON for cache storage
- [x] Implement admin config endpoints (AC: 5)
  - [x] Implement `GET /api/v1/admin/config` - list all config entries with metadata
  - [x] Implement `PUT /api/v1/admin/config/{key}` - update config value
  - [x] Implement `POST /api/v1/admin/config` - create new config entry
  - [x] Implement `DELETE /api/v1/admin/config/{key}` - delete config entry
  - [x] Invalidate Redis cache on any admin write operation
  - [x] Require admin authentication via `EnsureAdminUserMiddleware`
- [x] Register ConfigModule in Application-Setup.swift (AC: all)
  - [x] Add `ConfigModule()` to modules array in `setupModules()`
- [x] Write comprehensive tests (AC: all)
  - [x] Test public config endpoint returns valid JSON
  - [x] Test public endpoint requires no authentication
  - [x] Test old unversioned route returns 404
  - [x] Test admin endpoints require authentication
  - [x] Test cache invalidation on admin update
  - [x] Test cache hit returns data without DB query

---

## Relevant Feature Documentation

**docs/features/api-versioning.md** (matched: "When adding new API endpoints", "When creating new modules with public routes")

Key patterns from API versioning:

**Router Update Pattern:**
```swift
func boot(routes: RoutesBuilder) throws {
    let api = routes
        .grouped("api")
        .grouped("v1")           // REQUIRED: Version prefix
        .grouped("config")
        .groupedOpenAPI(tags: .init(name: "Config", description: "..."))

    // Define routes under the api group
    api.get(use: controller.getConfig)
}
```

**Testing Pattern:**
```swift
@Test("Endpoint accessible with v1 prefix")
func testVersionedEndpoint() async throws {
    try await app.test(.GET, "api/v1/config") { req in
        // Test implementation
    } afterResponse: { response in
        #expect(response.status == .ok)
    }
}

@Test("Old unversioned route returns 404")
func oldRouteReturns404() async throws {
    try await app.test(.GET, "api/config") { req in
        // Test implementation
    } afterResponse: { response in
        #expect(response.status == .notFound)
    }
}
```

---

## Developer Context

### Technical Requirements

1. **New Module Creation**: Create a complete `Config` module following the vertical slice architecture pattern
2. **Public + Admin Endpoints**: Implement both public (no auth) and admin (auth required) routes
3. **PostgreSQL Storage**: Store config entries in database with typed values
4. **Redis Caching**: Cache aggregated config response with 5-minute TTL
5. **Cache Invalidation**: Clear cache on any admin write operation

### Architecture Compliance

**Module Structure (MUST FOLLOW):**
```
Sources/App/Modules/Config/
├── ConfigModule.swift          # Module registration
├── ConfigRouter.swift          # Route definitions
├── ConfigController.swift      # Request handlers
├── Models/
│   └── Config+Model.swift      # Request/Response DTOs
├── Database/
│   ├── Models/
│   │   └── ConfigEntryModel.swift
│   └── Migrations/
│       └── ConfigMigrations.swift
└── Repositories/
    └── ConfigRepository.swift
```

**Naming Conventions:**
| Area | Convention | Example |
|------|------------|---------|
| Database table | snake_case, plural | `config_entries` |
| Database columns | snake_case | `created_at`, `config_key` |
| API endpoints | kebab-case with `/v1/` prefix | `/api/v1/config` |
| Swift types | PascalCase | `ConfigController`, `ConfigEntryModel` |
| Swift properties | camelCase | `featureFlags`, `createdAt` |

**Error Handling Pattern:**
```swift
enum ConfigError: AppError {
    case notFound(String)
    case invalidValue(String)

    var status: HTTPResponseStatus {
        switch self {
        case .notFound: return .notFound
        case .invalidValue: return .badRequest
        }
    }

    var reason: String {
        switch self {
        case .notFound(let key): return "Config key '\(key)' not found"
        case .invalidValue(let msg): return msg
        }
    }

    var identifier: String {
        switch self {
        case .notFound: return "config_not_found"
        case .invalidValue: return "config_invalid_value"
        }
    }
}
```

### Library & Framework Requirements

**Swift 6 Concurrency:**
- Use `async/await` for all async operations
- Mark services and models with appropriate `Sendable` conformance
- Access services via `req.services.*` pattern

**Vapor 4.110+:**
```swift
// Correct async route handler pattern
func getConfig(req: Request) async throws -> Config.Response {
    // Implementation
}
```

**Fluent 4.8+ (PostgreSQL):**
```swift
// Database model pattern
final class ConfigEntryModel: @unchecked Sendable, DatabaseModelInterface {
    typealias Module = ConfigModule
    static var schema: String { "config_entries" }

    @ID() var id: UUID?
    @Field(key: FieldKeys.v1.key) var key: String
    @Field(key: FieldKeys.v1.value) var value: String  // JSON string
    @Field(key: FieldKeys.v1.type) var type: String    // "boolean", "integer", "string", "json"
    @Timestamp(key: FieldKeys.v1.createdAt, on: .create) var createdAt: Date?
    @Timestamp(key: FieldKeys.v1.updatedAt, on: .update) var updatedAt: Date?
}
```

**Redis Caching Pattern (from existing RedisCacheService):**
```swift
// Cache key pattern
let cacheKey = "config:all"
let ttl: TimeInterval = 300  // 5 minutes

// Get from cache
if let cached = try await cacheService.get(cacheKey, as: Config.Response.self) {
    return cached
}

// Cache miss - fetch from DB and cache
let config = try await buildConfigResponse(from: entries)
try await cacheService.set(cacheKey, value: config, ttl: ttl)
return config

// Invalidate on write
try await cacheService.delete(cacheKey)
```

### File Structure Requirements

**Files to Create:**
1. `Sources/App/Modules/Config/ConfigModule.swift`
2. `Sources/App/Modules/Config/ConfigRouter.swift`
3. `Sources/App/Modules/Config/ConfigController.swift`
4. `Sources/App/Modules/Config/Models/Config+Model.swift`
5. `Sources/App/Modules/Config/Database/Models/ConfigEntryModel.swift`
6. `Sources/App/Modules/Config/Database/Migrations/ConfigMigrations.swift`
7. `Sources/App/Modules/Config/Repositories/ConfigRepository.swift`

**Files to Modify:**
1. `Sources/App/Entrypoint/Application-Setup.swift` - Add `ConfigModule()` to modules array
2. `Sources/App/Services/Repositories/Application+Repository.swift` - Add configRepository accessor
3. `Sources/App/Common/Extensions/Application+Services.swift` - Add configRepository property

**Test Files to Create:**
1. `Tests/AppTests/Tests/ControllerTests/ConfigTests/ConfigPublicEndpointTests.swift`
2. `Tests/AppTests/Tests/ControllerTests/ConfigTests/ConfigAdminEndpointTests.swift`
3. `Tests/AppTests/Tests/ControllerTests/ConfigTests/ConfigCachingTests.swift`

### Testing Requirements

**Testing Framework:** Swift Testing with `@Test` and `#expect`

**Test Structure Pattern:**
```swift
@testable import App
import VaporTesting
import Testing

@Suite(.serialized)
struct ConfigPublicEndpointTests {
    let app: Application
    let testWorld: IsolatedTestWorld

    init() async throws {
        testWorld = try await IsolatedTestWorld()
        app = testWorld.app
    }

    @Test("Public config endpoint returns JSON")
    func publicConfigReturnsJSON() async throws {
        await testWorld.resetAll()

        try await app.test(.GET, "api/v1/config", afterResponse: { response in
            #expect(response.status == .ok)
            let config = try response.content.decode(Config.Response.self)
            #expect(config.version != nil)
        })
    }

    @Test("Public config endpoint requires no authentication")
    func publicConfigNoAuth() async throws {
        await testWorld.resetAll()

        try await app.test(.GET, "api/v1/config", afterResponse: { response in
            #expect(response.status != .unauthorized)
        })
    }

    @Test("Old unversioned config route returns 404")
    func oldConfigRouteReturns404() async throws {
        await testWorld.resetAll()

        try await app.test(.GET, "api/config", afterResponse: { response in
            #expect(response.status == .notFound)
        })
    }
}
```

**Mock Repository for Testing:**
```swift
final class MockConfigRepository: ConfigRepository {
    var entries: [ConfigEntryModel] = []

    func findAll() async throws -> [ConfigEntryModel] {
        return entries
    }

    // ... other methods
}
```

---

## Previous Story Intelligence

**From Story 1.1 (Add API Version Prefix):**

### Key Learnings Applied:
1. **Router Pattern Verified**: Add `.grouped("v1")` after `.grouped("api")` before module group
2. **Rate Limit Configuration**: May need to add config-specific rate limits to `RateLimitConfiguration.swift` if desired
3. **Test Path Format**: Always use `"api/v1/config"` in tests (not `/api/v1/config`)

### Files Modified in 1.1 (patterns to follow):
- Router files: Line ~10 adds `.grouped("v1")` to route chain
- All tests updated to use versioned paths
- Route versioning tests added for negative test cases

### Completion Notes from 1.1:
- Rate limit configuration needed waitlist properties added
- MockRateLimitService needed updates for new rate limit types
- OpenAPI integration worked automatically with versioned routes

---

## Git Intelligence

**Recent Commits (from Story 1.1 merge):**
```
4a42d69 Merge PR #26: Story 1.1: Add v1 prefix to all API endpoints
```

**Files Modified in 1.1 PR:**
- `Sources/App/Modules/Auth/AuthRouter.swift` - Added `.grouped("v1")`
- `Sources/App/Modules/User/UserRouter.swift` - Added `.grouped("v1")`
- `Sources/App/Modules/RulesGeneration/RulesGenerationRouter.swift` - Added `.grouped("v1")`
- `Sources/App/Modules/Waitlist/WaitlistRouter.swift` - Added `.grouped("v1")`
- `Sources/App/Middlewares/Security/RateLimit/RateLimitConfiguration.swift` - Extended for waitlist
- `Tests/AppTests/Framework/Mocks/Services/MockRateLimitService.swift` - Updated for new types

**Established Patterns:**
- All new API modules MUST include `/v1/` prefix
- Test files follow pattern: `Tests/AppTests/Tests/ControllerTests/{Module}Tests/`
- Module registration in `Application-Setup.swift` at line ~83-89

---

## Latest Technical Information

**Vapor Redis Integration (2025):**
- Use `vapor/redis` package 4.x with RediStack driver
- TTL set via `redis.setex(key, to: data, expirationInSeconds: Int(ttl))`
- Existing `RedisCacheService` provides all needed operations
- Cache key pattern: Use descriptive prefix like `config:all`

**Fluent PostgreSQL JSON Storage:**
- Store JSON values as String and deserialize in code
- Alternative: Use `Codable` types directly with Fluent (auto-JSONB)
- For flexibility, string storage with type metadata is safer

**Sources:**
- [Vapor Redis Documentation](https://docs.vapor.codes/redis/overview/)
- [Vapor PostgreSQL Guide](https://vaporpostgresqlguide.vercel.app/)

---

## Project Context Reference

See: docs/project-context.md

Key patterns and rules from project context:

1. **Swift 6 Concurrency**: Always use `async/await`, mark types `Sendable`
2. **Module Boundaries**: Each module owns its Router, Controller, Models, Repository
3. **Service Registration**: Register in `Application-Setup.swift`, access via `req.services.*`
4. **Error Handling**: All errors conform to `AppError` enum pattern
5. **Repository Pattern**: Protocol-first design with database implementations
6. **Testing**: Use `IsolatedTestWorld`, Swift Testing `@Test` and `#expect`

---

## Dev Notes

- Relevant architecture patterns and constraints
- Source tree components to touch
- Testing standards summary

### Project Structure Notes

- Alignment with unified project structure (paths, modules, naming)
- Detected conflicts or variances (with rationale)

### References

- [Source: docs/architecture/technical-architecture.md#module-architecture]
- [Source: docs/project-context.md#module-structure]
- [Source: docs/features/api-versioning.md#router-update-pattern]
- [Source: _bmad-output/epics.md#story-1.2]
- [Source: _bmad-output/implementation-artifacts/1-1-add-api-version-prefix-to-all-public-routes.md]
- [Source: Sources/App/Modules/Waitlist/WaitlistModule.swift] - Module pattern reference
- [Source: Sources/App/Modules/Waitlist/WaitlistController.swift] - Controller pattern reference
- [Source: Sources/App/Modules/Waitlist/WaitlistRouter.swift] - Router pattern reference
- [Source: Sources/App/Modules/CacheAdmin/CacheAdminRouter.swift] - Admin route pattern reference
- [Source: Sources/App/Services/Cache/RedisCacheService.swift] - Cache service usage
- [Source: Sources/App/Entrypoint/Application-Setup.swift:83-89] - Module registration

---

## Dev Agent Record

### Context Reference

<!-- Path(s) to story context XML will be added here by context workflow -->

### Agent Model Used

claude-opus-4-5-20251101

### Debug Log References

### Completion Notes List

- Task 1-7: Created complete Config module with module structure, database model, migrations, repository, public endpoint with caching, admin endpoints with authentication, and module registration. All existing tests pass (43 tests).
- Task 8: Created comprehensive tests for Config module including ConfigPublicEndpointTests (5 tests), ConfigAdminEndpointTests (11 tests), and ConfigCachingTests (5 tests). Tests verify public endpoint access, admin authentication, cache invalidation, and versioned route compliance. Note: Test output is affected by a pre-existing Vapor testing infrastructure issue ("ServeCommand did not shutdown before deinit") that causes crash during test shutdown, but all test assertions pass before the crash.

### File List

**Created:**
- Sources/App/Modules/Config/ConfigModule.swift
- Sources/App/Modules/Config/ConfigRouter.swift
- Sources/App/Modules/Config/ConfigController.swift
- Sources/App/Modules/Config/Models/Config+Model.swift
- Sources/App/Modules/Config/Models/ConfigError.swift
- Sources/App/Modules/Config/Database/Models/ConfigEntryModel.swift
- Sources/App/Modules/Config/Database/Migrations/ConfigMigrations.swift
- Sources/App/Modules/Config/Repositories/ConfigRepository.swift
- Tests/AppTests/Framework/Mocks/Repositories/TestConfigRepository.swift
- Tests/AppTests/Tests/ControllerTests/ConfigTests/ConfigPublicEndpointTests.swift
- Tests/AppTests/Tests/ControllerTests/ConfigTests/ConfigAdminEndpointTests.swift
- Tests/AppTests/Tests/ControllerTests/ConfigTests/ConfigCachingTests.swift

**Modified:**
- Sources/App/Common/Extensions/Application+Services.swift (added configRepository)
- Sources/App/Entrypoint/Application-Setup.swift (added ConfigModule and repository)
- Tests/AppTests/Framework/IsolatedTestWorld.swift (added configRepository)

