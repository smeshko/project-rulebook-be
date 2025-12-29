# Story 1.2: Implement Remote Config Endpoint

Status: ready-for-dev
Linear Issue: RULE-123
Epic: 1 - API Versioning & Stability
Created: 2025-12-29

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
  - [x] Create `Sources/App/Modules/Config/Controllers/ConfigController.swift`
  - [x] Create `Sources/App/Modules/Config/Models/Config+Model.swift` (Request/Response DTOs)
  - [x] Create `Sources/App/Modules/Config/Database/Models/ConfigEntryModel.swift`
  - [x] Create `Sources/App/Modules/Config/Database/Migrations/ConfigMigrations.swift`
  - [x] Create `Sources/App/Modules/Config/Repositories/ConfigRepository.swift`

- [x] Implement database model and migration (AC: 3, 4)
  - [x] Define `config_entries` table with: `id`, `key`, `value` (JSON), `value_type`, `created_at`, `updated_at`
  - [x] Add unique constraint on `key` field
  - [x] Register migration in ConfigModule

- [x] Implement repository with caching (AC: 3, 6)
  - [x] Create ConfigRepository protocol with CRUD methods
  - [x] Implement DatabaseConfigRepository
  - [x] Add cache-through pattern: read from Redis, fallback to PostgreSQL
  - [x] Set 5-minute TTL on cached config values

- [x] Implement public GET endpoint (AC: 1, 2)
  - [x] Register public route at `/api/v1/config`
  - [x] Implement controller method to fetch all config entries
  - [x] Transform database entries into structured JSON response
  - [x] Group by key prefix (featureFlags.*, settings.*)

- [x] Implement admin PUT endpoint (AC: 5)
  - [x] Register admin route at `/api/v1/admin/config`
  - [x] Apply `UserAccountModel.guard()` and `EnsureAdminUserMiddleware()`
  - [x] Implement PATCH/PUT for updating config values
  - [x] Invalidate Redis cache on update

- [ ] Register module and repository (AC: 3)
  - [ ] Add ConfigModule to `setupModules()` in Application-Setup.swift
  - [ ] Add `configRepository` property to Application
  - [ ] Add repository accessor to Application.Repositories extension

- [ ] Create comprehensive tests
  - [ ] Integration tests for GET /api/v1/config
  - [ ] Integration tests for admin PATCH endpoint
  - [ ] Test cache hit/miss scenarios
  - [ ] Test cache invalidation on update
  - [ ] Test authentication requirement for admin endpoint

---

## Relevant Feature Documentation

**API Versioning (from docs/features/api-versioning.md):**

All new endpoints MUST use the `/api/v1/` prefix pattern established in Story 1.1:

```swift
// Standard versioned router pattern
func boot(routes: RoutesBuilder) throws {
    let api = routes
        .grouped("api")
        .grouped("v1")           // ← Version prefix REQUIRED
        .grouped("config")
        .groupedOpenAPI(tags: .init(name: "Config", description: "Remote configuration"))

    api.get(use: controller.getConfig)
}
```

---

## Developer Context

### Technical Requirements

**Swift 6 Concurrency:**
- Use `async/await` for all database and cache operations
- Ensure repository is marked `Sendable`
- ConfigEntryModel must be `@unchecked Sendable` per existing patterns

**Database Schema:**
```sql
CREATE TABLE config_entries (
    id UUID PRIMARY KEY,
    key VARCHAR NOT NULL UNIQUE,
    value JSONB NOT NULL,
    value_type VARCHAR NOT NULL, -- 'boolean', 'integer', 'string', 'object'
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ
);
```

**Cache Strategy:**
- Redis key pattern: `config:all` for full config response
- TTL: 300 seconds (5 minutes)
- Invalidation: DELETE key on any config update

### Architecture Compliance

**From Technical Architecture (docs/architecture/technical-architecture.md):**

1. **Module Structure Pattern** - MUST follow:
```
Sources/App/Modules/Config/
├── ConfigModule.swift         # Module registration
├── ConfigRouter.swift         # Route definitions
├── Controllers/
│   └── ConfigController.swift # HTTP endpoints + business logic
├── Models/
│   └── Config+Model.swift     # Request/Response Codable types
├── Database/
│   ├── Models/
│   │   └── ConfigEntryModel.swift
│   └── Migrations/
│       └── ConfigMigrations.swift
└── Repositories/
    └── ConfigRepository.swift
```

2. **Controller-Centric Design** - Business logic lives IN the controller, NOT in separate use case files

3. **Property-Based DI** - Access via `req.repositories.config` pattern:
```swift
// In ConfigRepository.swift - add extension
extension Application.Repositories {
    var config: any ConfigRepository {
        application.configRepository
    }
}

// In Request extension
extension Request.Repositories {
    var config: any ConfigRepository {
        application.repositories.config
    }
}
```

4. **Error Handling** - All errors MUST conform to `AppError`:
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

| Library | Version | Usage |
|---------|---------|-------|
| Vapor | 4.110+ | HTTP framework |
| Fluent | 4.8+ | ORM for PostgreSQL |
| FluentPostgresDriver | - | PostgreSQL driver |
| Redis | Railway managed | Response caching |
| VaporToOpenAPI | - | API documentation |

**Redis Cache Integration:**
```swift
// Use existing CacheService pattern
let cacheService = req.application.cacheService

// Get cached config
if let cached = try await cacheService.get("config:all", as: Config.Response.self) {
    return cached
}

// Cache miss - fetch from DB and cache
let config = try await buildConfigResponse(req)
try await cacheService.set("config:all", value: config, ttl: 300)
return config
```

**VaporToOpenAPI Pattern (from WaitlistRouter):**
```swift
api
    .get(use: controller.getConfig)
    .openAPI(
        description: "Get all remote configuration values",
        response: .type(Config.Response.self)
    )
```

### File Structure Requirements

**Files to Create:**
1. `Sources/App/Modules/Config/ConfigModule.swift`
2. `Sources/App/Modules/Config/ConfigRouter.swift`
3. `Sources/App/Modules/Config/Controllers/ConfigController.swift`
4. `Sources/App/Modules/Config/Models/Config+Model.swift`
5. `Sources/App/Modules/Config/Database/Models/ConfigEntryModel.swift`
6. `Sources/App/Modules/Config/Database/Migrations/ConfigMigrations.swift`
7. `Sources/App/Modules/Config/Repositories/ConfigRepository.swift`

**Files to Modify:**
1. `Sources/App/Entrypoint/Application-Setup.swift`:
   - Add `ConfigModule()` to modules array in `setupModules()`
   - Add `configRepository = DatabaseConfigRepository(database: db)` in `setupServices()`

**Naming Conventions:**
- Database table: `config_entries` (snake_case, plural)
- Database columns: `key`, `value`, `value_type`, `created_at`, `updated_at` (snake_case)
- API endpoint: `/api/v1/config` (kebab-case with v1 prefix)
- Swift types: `ConfigController`, `ConfigEntryModel`, `ConfigRepository` (PascalCase)

### Testing Requirements

**Test Structure (mirror source):**
```
Tests/AppTests/Tests/ControllerTests/ConfigTests/
├── ConfigGetTests.swift        # Public GET endpoint tests
├── ConfigAdminTests.swift      # Admin endpoint tests
└── ConfigCacheTests.swift      # Cache behavior tests
```

**Test Patterns (from existing tests):**
```swift
@Suite(.serialized)
struct ConfigGetTests {
    let testWorld: IsolatedTestWorld

    init() async throws {
        testWorld = try await IsolatedTestWorld()
    }

    @Test("GET /api/v1/config returns configuration")
    func getConfigReturnsData() async throws {
        // Seed test data
        let configEntry = ConfigEntryModel(
            key: "featureFlags.enableNewScanner",
            value: .bool(true),
            valueType: "boolean"
        )
        try await configEntry.create(on: testWorld.app.db)

        try await testWorld.app.test(.GET, "api/v1/config") { response in
            #expect(response.status == .ok)
            let config = try response.content.decode(Config.Response.self)
            #expect(config.featureFlags["enableNewScanner"] == true)
        }
    }

    @Test("GET /api/v1/config does not require authentication")
    func getConfigIsPublic() async throws {
        // No auth header - should still succeed
        try await testWorld.app.test(.GET, "api/v1/config") { response in
            #expect(response.status == .ok)
        }
    }
}
```

**Mock Repository for Testing:**
```swift
final class MockConfigRepository: ConfigRepository {
    var entries: [String: ConfigEntryModel] = [:]

    func findAll() async throws -> [ConfigEntryModel] {
        Array(entries.values)
    }

    func find(key: String) async throws -> ConfigEntryModel? {
        entries[key]
    }

    func save(_ model: ConfigEntryModel) async throws {
        entries[model.key] = model
    }

    func delete(key: String) async throws {
        entries.removeValue(forKey: key)
    }
}
```

---

## Previous Story Intelligence

**From Story 1.1 (Add API Version Prefix):**

1. **Router Pattern Established:**
   - All routers now use `.grouped("api").grouped("v1").grouped("{module}")` chain
   - VaporToOpenAPI tags come AFTER version grouping

2. **Test Path Updates:**
   - All test paths MUST include `/v1/` prefix: `"api/v1/config"`
   - Add negative test verifying old unversioned route returns 404

3. **Rate Limit Configuration:**
   - RateLimitConfiguration may need extension for config endpoints
   - Check if new rate limit type needed or if general API limit applies

4. **Files Modified in Story 1.1:**
   - Router files follow consistent pattern
   - Tests updated to use versioned paths
   - Rate limit config extended when needed

5. **Agent Model Used:** claude-sonnet-4-5-20250929

---

## Git Intelligence

**Recent Commits (branch: feature/story-12-implement-remote-config):**
- No story-related commits yet on this branch
- Branch created from main for this feature

**Patterns from Codebase:**
- Modules follow complete vertical slice architecture
- Controllers contain business logic directly
- Repository pattern with protocol-first design
- Database models use `@unchecked Sendable` pattern

---

## Latest Technical Information

**Swift Configuration 1.0 (December 2025):**
While Apple released Swift Configuration 1.0 for unified config management, this story implements a simpler, project-specific solution. The Swift Configuration library may be considered for future enhancement but is NOT required for this implementation.

**Current Approach:**
- Custom PostgreSQL + Redis caching solution
- Simple key-value storage with typed values
- Immediate cache invalidation on updates
- No external dependencies beyond existing stack

---

## Project Context Reference

See: docs/project-context.md

Key patterns and rules from project context:

1. **Swift 6 Concurrency:** ALWAYS use `async/await`, never `DispatchQueue`
2. **Vapor Async:** All route handlers must be async
3. **Module Boundaries:** Each module owns its own Router, Controller, Models, Repository
4. **Service Access:** Use `req.services.*` and `req.repositories.*` patterns
5. **Error Handling:** All errors conform to `AppError` enum
6. **Testing:** Use `IsolatedTestWorld` pattern with `@Suite(.serialized)`

---

## Dev Notes

### Implementation Order

1. **Database First:** Create model, migration, repository
2. **Module Structure:** Create module and register in Application-Setup
3. **Public Endpoint:** Implement GET /api/v1/config with caching
4. **Admin Endpoint:** Implement admin update with cache invalidation
5. **Tests:** Write comprehensive integration tests

### Critical Implementation Details

**JSON Value Storage:**
Store config values as JSONB in PostgreSQL to support all types:
```swift
@Field(key: FieldKeys.v1.value)
var value: AnyCodable  // Or use JSONValue enum

enum ConfigValue: Codable {
    case bool(Bool)
    case int(Int)
    case string(String)
    case object([String: AnyCodable])
}
```

**Response Structure Building:**
Parse keys by prefix to build nested response:
```swift
// Keys like "featureFlags.enableNewScanner" → nested object
// Keys like "settings.maxRetries" → nested object
// Key "version" → top-level
```

**Cache Key Strategy:**
- Single cache key `config:all` for entire response
- Avoids multiple round-trips for individual values
- Simple invalidation on any update

### Project Structure Notes

- New module at `Sources/App/Modules/Config/`
- Follows established vertical slice pattern
- No conflicts with existing modules
- Uses existing Redis cache infrastructure

### References

- [Source: _bmad-output/epics.md#story-1.2]
- [Source: docs/project-context.md]
- [Source: docs/architecture/technical-architecture.md#module-architecture]
- [Source: docs/features/api-versioning.md]
- [Source: Sources/App/Modules/Waitlist/WaitlistModule.swift] (reference pattern)
- [Source: Sources/App/Modules/Waitlist/WaitlistRouter.swift] (router pattern)
- [Source: Sources/App/Modules/Waitlist/Database/Models/WaitlistEntryModel.swift] (model pattern)
- [Source: Sources/App/Modules/Waitlist/Repositories/WaitlistRepository.swift] (repository pattern)
- [Source: Sources/App/Entrypoint/Application-Setup.swift] (module registration)
- [Source: Sources/App/Services/Cache/CacheService.swift] (cache interface)
- [Source: _bmad-output/implementation-artifacts/1-1-add-api-version-prefix-to-all-public-routes.md] (previous story)

---

## Dev Agent Record

### Context Reference

<!-- Path(s) to story context XML will be added here by context workflow -->

### Agent Model Used

claude-opus-4-5-20251101

### Debug Log References

### Completion Notes List

- Task 1: Created complete Config module structure with ConfigModule, ConfigRouter, ConfigController, Config+Model (DTOs with Sendable conformance), ConfigEntryModel (database model), ConfigMigrations (v1 migration), and ConfigRepository (protocol + DatabaseConfigRepository implementation)
- Task 2: Database model and migration already implemented in Task 1 (config_entries table with id, key, value JSON, value_type, created_at, updated_at, unique constraint on key)
- Task 3: Repository with caching already implemented in Task 1. Cache-through pattern in ConfigController: check cache first, fallback to DB, cache result with 5-min TTL (300s)
- Task 4: Public GET endpoint already implemented in Task 1. Route at /api/v1/config, buildConfigResponse groups by key prefix
- Task 5: Fixed admin route to use /api/v1/admin/config per story requirements. Applied UserAccountModel.guard() and EnsureAdminUserMiddleware(). Cache invalidation via cache.delete()

### File List

**Created:**
- Sources/App/Modules/Config/ConfigModule.swift
- Sources/App/Modules/Config/ConfigRouter.swift
- Sources/App/Modules/Config/Controllers/ConfigController.swift
- Sources/App/Modules/Config/Models/Config+Model.swift
- Sources/App/Modules/Config/Database/Models/ConfigEntryModel.swift
- Sources/App/Modules/Config/Database/Migrations/ConfigMigrations.swift
- Sources/App/Modules/Config/Repositories/ConfigRepository.swift

**Modified:**
- Sources/App/Common/Extensions/Application+Services.swift (added configRepository)

