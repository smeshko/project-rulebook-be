# Story 1.2: Implement Remote Config Endpoint

Status: Ready for Review
Linear Issue: not-configured

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

## Relevant Feature Documentation

### API Versioning Strategy

**Critical Pattern from Story 1.1:** All new endpoints MUST use the `/api/v1/` prefix pattern.

From `docs/features/api-versioning.md`:

**Standard Versioned Router Pattern:**
```swift
func boot(routes: RoutesBuilder) throws {
    let api = routes
        .grouped("api")
        .grouped("v1")           // ← Version prefix REQUIRED
        .grouped("{module-name}")
        .groupedOpenAPI(tags: .init(name: "{Module}", description: "..."))

    // Define routes under the api group
    api.get("{endpoint}", use: controller.method)
}
```

**URL Format for New Endpoints:**
- Pattern: `/api/v1/{module}/{endpoint}`
- This story: `/api/v1/config`
- Admin endpoint: `/api/v1/admin/config`

**Testing Requirements:**
- ✅ Test the versioned route works (`/api/v1/config`)
- ✅ Update integration tests to use versioned paths
- ✅ Verify OpenAPI spec reflects versioned endpoints

## Tasks / Subtasks

- [x] Create RemoteConfig module foundation (AC: 1, 2, 3, 4)
  - [x] Create `Modules/RemoteConfig/RemoteConfigModule.swift`
  - [x] Create `Modules/RemoteConfig/RemoteConfigRouter.swift` with `/v1/` prefix
  - [x] Create `Modules/RemoteConfig/Controller/RemoteConfigController.swift`
  - [x] Create `Modules/RemoteConfig/Models/RemoteConfig+Model.swift` for DTOs
  - [x] Register module in `Application-Setup.swift`

- [x] Create database model and migration (AC: 3, 4)
  - [x] Create `Modules/RemoteConfig/Database/Models/ConfigEntryModel.swift`
    - [x] Fields: `id`, `key`, `valueType`, `boolValue`, `intValue`, `stringValue`, `jsonValue`, `createdAt`, `updatedAt`
    - [x] Use enum for valueType: `.boolean`, `.integer`, `.string`, `.json`
  - [x] Create `Modules/RemoteConfig/Database/Migrations/RemoteConfigMigrations.swift`
  - [x] Add migration to application setup

- [x] Create repository for database access (AC: 3, 6)
  - [x] Create `Modules/RemoteConfig/Repositories/RemoteConfigRepository.swift`
  - [x] Protocol with methods: `getAllConfig()`, `getConfig(key:)`, `setConfig(key:value:type:)`, `deleteConfig(key:)`
  - [x] Database implementation using Fluent query builder
  - [x] Register repository in Application

- [x] Implement Redis caching service (AC: 3, 6)
  - [x] Create `Services/ConfigCache/ConfigCacheService.swift` protocol
  - [x] Implement with 5-minute TTL
  - [x] Cache key pattern: `config:all` for full config
  - [x] Implement cache invalidation on update
  - [x] Register service in Application

- [x] Implement public GET endpoint (AC: 1, 2)
  - [x] Add route: `GET /api/v1/config`
  - [x] No authentication required (public endpoint)
  - [x] Check Redis cache first
  - [x] On cache miss, fetch from database and cache
  - [x] Return typed JSON response matching AC format
  - [x] Handle empty config gracefully

- [x] Implement admin endpoints (AC: 5)
  - [x] Add route: `POST /api/v1/config/admin` (create/update)
  - [x] Add route: `GET /api/v1/config/admin` (list all with types)
  - [x] Add route: `DELETE /api/v1/config/admin/:key` (delete)
  - [x] Require JWT authentication (admin only)
  - [x] Invalidate cache on any mutation
  - [x] Support all value types (boolean, integer, string, JSON)

- [x] Write comprehensive tests
  - [x] Integration test: GET `/api/v1/config` returns correct structure
  - [x] Integration test: Cache hit scenario (fast response)
  - [x] Integration test: Cache miss scenario (fetch from DB)
  - [x] Integration test: Admin authentication requirements
  - [x] Integration test: Unauthenticated admin request returns 401

## Dev Notes

### Architectural Context

**Epic Context:**
This is Story 2 of Epic 1 "API Versioning & Stability". Story 1.1 established the `/v1/` prefix pattern for all public routes. This story continues that pattern by implementing the first new endpoint under the versioned API structure.

**From Architecture Document:**
- **Module Pattern:** Follow established vertical slice architecture (see technical-architecture.md:26-39)
- **Service Pattern:** Protocol-first design with dependency injection (see technical-architecture.md:144-188)
- **Repository Pattern:** Abstract database operations (see technical-architecture.md:219-261)
- **Caching Strategy:** Redis for high-performance caching with TTL (see technical-architecture.md:422-429)

**From Project Context:**
- **Swift 6 Concurrency:** Use async/await throughout (see project-context.md:29-47)
- **API Response Pattern:** Return response type directly, Vapor encodes to JSON (see project-context.md:163-176)
- **Error Handling:** All errors must conform to AppError enum (see project-context.md:68-100)
- **Naming Conventions:**
  - Database: snake_case, plural tables (project-context.md:106-115)
  - API: kebab-case with `/v1/` prefix
  - Swift: PascalCase types, camelCase properties

### Technical Requirements

**Database Schema Design:**

The config storage needs to support multiple value types while maintaining type safety:

```swift
// Database Model
final class ConfigEntryModel: Model, Content {
    static let schema = "config_entries"

    @ID(key: .id) var id: UUID?
    @Field(key: "key") var key: String
    @Field(key: "value_type") var valueType: String  // "boolean", "integer", "string", "json"

    // Type-specific storage columns (only one populated per row)
    @Field(key: "bool_value") var boolValue: Bool?
    @Field(key: "int_value") var intValue: Int?
    @Field(key: "string_value") var stringValue: String?
    @Field(key: "json_value") var jsonValue: String?  // Serialized JSON

    @Timestamp(key: "created_at", on: .create) var createdAt: Date?
    @Timestamp(key: "updated_at", on: .update) var updatedAt: Date?
}
```

**Why This Design:**
- Allows type-safe storage without JSON blob
- Enables database queries on specific value types if needed
- Maintains data integrity with proper types
- Follows PostgreSQL best practices for typed data

**Response Structure:**

The public endpoint must transform database rows into a nested structure:

```swift
struct RemoteConfigResponse: Content {
    let featureFlags: [String: Bool]
    let settings: [String: AnyCodable]  // Supports multiple types
    let version: String
}
```

**Transformation Logic:**
- Keys prefixed with `feature_` → go into `featureFlags` (boolean only)
- Keys prefixed with `setting_` → go into `settings` (any type)
- Special key `api_version` → becomes `version`
- Handle missing data gracefully (empty dictionaries, default version)

### Architecture Compliance

**Module Structure (MUST FOLLOW):**

```
Sources/App/Modules/RemoteConfig/
├── RemoteConfigModule.swift         # Module registration and boot
├── RemoteConfigRouter.swift         # Route definitions with /v1/ prefix
├── Controller/
│   └── RemoteConfigController.swift # Business logic for endpoints
├── Models/
│   └── RemoteConfig+Model.swift     # Request/Response DTOs
├── Database/
│   ├── Models/
│   │   └── ConfigEntryModel.swift   # Fluent @Model class
│   └── Migrations/
│       └── RemoteConfigMigrations.swift
└── Repositories/
    └── RemoteConfigRepository.swift # Data access abstraction
```

**Service Structure:**

```
Sources/App/Services/ConfigCache/
├── ConfigCacheService.swift         # Protocol definition
└── RedisConfigCacheService.swift    # Redis implementation
```

**Critical Pattern from Story 1.1:**

Story 1.1 successfully updated all routers to use the `/v1/` prefix pattern. This story MUST follow the exact same pattern:

```swift
// From Story 1.1 learnings (see api-versioning.md:29-45)
func boot(routes: RoutesBuilder) throws {
    let api = routes
        .grouped("api")
        .grouped("v1")              // REQUIRED: Version prefix
        .grouped("config")           // Module path
        .groupedOpenAPI(tags: .init(name: "Remote Config",
                                   description: "Remote configuration and feature flags"))

    // Public endpoint
    api.get(use: controller.getConfig)

    // Admin endpoints
    let admin = api.grouped("admin").grouped(UserPayloadAuthenticator())
    admin.post(use: controller.setConfig)
    admin.get(use: controller.getAllConfig)
    admin.delete(":key", use: controller.deleteConfig)
}
```

### Library/Framework Requirements

**Vapor 4 Dependencies:**
- Vapor 4.110+ (already in project)
- Fluent 4.8+ for PostgreSQL (already in project)
- vapor/redis 4.x for Redis caching (verify in Package.swift)

**Swift 6 Features:**
- Strict concurrency enabled (project-context.md:18)
- All services and models must be Sendable
- Use async/await throughout (NO completion handlers)

**Redis Cache Integration:**

From web research (2025 best practices):
- Vapor employs pooling strategy for RedisConnection instances
- Redis should be configured via REDIS_URL environment variable
- Cache keys should follow pattern: `config:all` for full config

```swift
// Access Redis via Application
extension Application {
    var redis: Redis {
        get { self.storage[RedisKey.self]! }
        set { self.storage[RedisKey.self] = newValue }
    }
}

// Cache operations in service
protocol ConfigCacheService: Sendable {
    func getAll() async throws -> RemoteConfigResponse?
    func set(_ config: RemoteConfigResponse) async throws
    func invalidate() async throws
}
```

**PostgreSQL via Fluent:**
- Use Fluent query builder (NO raw SQL - see project-context.md:212)
- Async operations throughout (see project-context.md:432-435)
- Proper indexing on `key` field for fast lookups

### File Structure Requirements

**Files to Create:**

1. **Module Registration:** `Sources/App/Modules/RemoteConfig/RemoteConfigModule.swift`
   - Conform to `ModuleInterface` protocol
   - Register router and migrations

2. **Router:** `Sources/App/Modules/RemoteConfig/RemoteConfigRouter.swift`
   - Import Vapor and VaporToOpenAPI
   - Follow `/v1/` prefix pattern from Story 1.1
   - Public GET endpoint (no auth)
   - Admin POST/GET/DELETE endpoints (auth required)

3. **Controller:** `Sources/App/Modules/RemoteConfig/Controller/RemoteConfigController.swift`
   - Public method: `getConfig(req: Request) async throws -> RemoteConfigResponse`
   - Admin methods: `setConfig`, `getAllConfig`, `deleteConfig`
   - Access services via `req.services.*`
   - Access repositories via `req.repositories.*`

4. **DTOs:** `Sources/App/Modules/RemoteConfig/Models/RemoteConfig+Model.swift`
   - RemoteConfigResponse (public API)
   - ConfigUpdateRequest (admin input)
   - ConfigEntry (admin list response)

5. **Database Model:** `Sources/App/Modules/RemoteConfig/Database/Models/ConfigEntryModel.swift`
   - Fluent @Model conformance
   - All fields with proper @Field/@Timestamp decorators

6. **Migration:** `Sources/App/Modules/RemoteConfig/Database/Migrations/RemoteConfigMigrations.swift`
   - Create config_entries table
   - Add index on `key` field
   - Set up proper constraints

7. **Repository:** `Sources/App/Modules/RemoteConfig/Repositories/RemoteConfigRepository.swift`
   - Protocol definition
   - Database implementation using Fluent

8. **Cache Service:** `Sources/App/Services/ConfigCache/ConfigCacheService.swift`
   - Protocol with Sendable conformance
   - Redis implementation with 5-minute TTL

9. **Application Setup:** Update `Sources/App/Application-Setup.swift`
   - Register RemoteConfigModule
   - Register ConfigCacheService
   - Register RemoteConfigRepository
   - Add migration

10. **Tests:** Create in `Tests/AppTests/Tests/ControllerTests/RemoteConfigTests/`
    - RemoteConfigGetTests.swift
    - RemoteConfigAdminTests.swift
    - RemoteConfigCacheTests.swift

### Testing Requirements

**From Project Context (project-context.md:179-200):**
- Tests in `Tests/AppTests/` mirroring source structure
- Use `@testable import App`
- Use `Application.make(.testing)` for app instance
- Mock services via protocol injection
- **ALWAYS** test error cases, not just happy paths

**Test Coverage Required:**

1. **Public Endpoint Tests:**
   - GET `/api/v1/config` returns correct structure
   - Response includes featureFlags, settings, version
   - Empty config returns empty collections (not error)
   - Cache hit scenario (verify fast response)
   - Cache miss scenario (verify DB fetch)

2. **Admin Endpoint Tests:**
   - Authenticated admin can create config
   - Authenticated admin can update config
   - Authenticated admin can list all config with types
   - Authenticated admin can delete config
   - Unauthenticated request returns 401
   - Non-admin user returns 403

3. **Caching Tests:**
   - Config is cached on first fetch
   - Subsequent fetches use cache
   - Cache invalidates on admin update
   - Cache expires after 5 minutes

4. **Type Handling Tests:**
   - Boolean values preserved correctly
   - Integer values preserved correctly
   - String values preserved correctly
   - JSON object values preserved correctly

5. **Edge Case Tests:**
   - Invalid JSON in admin request returns 400
   - Missing required fields returns 400
   - Deleting non-existent key returns 404

**Mock Pattern from Story 1.1:**

Story 1.1 successfully used IsolatedTestWorld pattern. Follow the same approach:

```swift
@Suite(.serialized)
struct RemoteConfigGetTests {
    let testWorld: IsolatedTestWorld

    init() async throws {
        testWorld = try await IsolatedTestWorld()
    }

    @Test func testGetConfig() async throws {
        try await testWorld.app.test(.GET, "api/v1/config") { req in
            // Setup
        } afterResponse: { response in
            #expect(response.status == .ok)
            let config = try response.content.decode(RemoteConfigResponse.self)
            #expect(config.featureFlags != nil)
        }
    }
}
```

### Previous Story Intelligence

**From Story 1.1 (1-1-add-api-version-prefix-to-all-public-routes.md):**

**Key Learnings:**
1. **Router Pattern Works:** The `.grouped("v1")` pattern successfully implemented in all routers
2. **Testing Pattern Established:** Integration tests use `app.test(.METHOD, "api/v1/...")` format
3. **OpenAPI Integration:** VaporToOpenAPI automatically reflects versioned paths
4. **Rate Limiting Unaffected:** Middleware continues to work with versioned routes

**Files Modified in Story 1.1:**
- RulesGenerationRouter.swift - Added `.grouped("v1")` at line 10
- AuthRouter.swift - Added `.grouped("v1")` at line 10
- UserRouter.swift - Added `.grouped("v1")` at line 17
- WaitlistRouter.swift - Added `.grouped("v1")` at line 10

**Critical Pattern to Follow:**
The router update pattern from Story 1.1 is proven and tested. Use the EXACT same pattern for RemoteConfig router:

```swift
// Proven pattern from Story 1.1
let api = routes
    .grouped("api")
    .grouped("v1")           // ← This is the critical addition
    .grouped("config")       // ← Module name
    .groupedOpenAPI(tags: .init(name: "Remote Config", description: "..."))
```

**Dev Notes from Story 1.1:**
- All integration tests updated to use `/v1/` paths
- Rate limiting configuration required update for new modules
- OpenAPI spec automatically updated (no manual changes needed)
- Breaking change documented in api-versioning.md

**Avoid These Issues from Story 1.1:**
- Don't forget to add module to rate limit configuration
- Don't skip negative tests (verify old routes return 404)
- Don't forget to update ALL test files that reference the endpoints

### Git Intelligence Summary

**Recent Commit Patterns (from git log):**

1. **Latest Commits Focus on Documentation:**
   - d442e82: "Update bmad" - Documentation and workflow updates
   - b8580da: "docs: update documentation for API versioning implementation"
   - Story 1.1 created comprehensive feature documentation

2. **Conventional Commit Format Used:**
   - `feat(story-1-1-...)`: For feature implementation
   - `docs:`: For documentation updates
   - `fix(docs):`: For documentation fixes
   - `chore:`: For maintenance tasks

3. **Story 1.1 Implementation Pattern:**
   - Feature implementation commit: 9e48fbd
   - Documentation commit: b8580da
   - Additional fixes: 7c3f61d
   - Story completion: 6f61a7a

**Files Created/Modified in Recent Work:**
- Router files: All 4 main routers updated
- Test files: Comprehensive test coverage added
- Documentation: Created docs/features/api-versioning.md
- Configuration: Updated rate limiting configs

**Code Patterns to Follow:**
- Create feature documentation after implementation
- Use conventional commit messages
- Update all related tests in same commit
- Document breaking changes explicitly

**Architecture Decisions Implemented:**
- URL prefix versioning pattern established
- All public API routes under `/v1/`
- OpenAPI integration preserved
- Middleware compatibility maintained

### Latest Technical Information

**Swift 6 & Vapor 4 (2025 Standards):**

From web research:
- **Swift Configuration 1.0:** Released December 2025 for production-ready config management
- **ConfigProvider Protocol:** Enables custom integrations with feature flagging services
- **Vapor Environment API:** Built-in support for loading environment variables

**Redis Best Practices (2025):**
- Vapor employs pooling strategy for RedisConnection instances
- Redis databases should be configured via REDIS_URL environment variable
- For best performance, Redis server should be close to Vapor app
- Connection pooling configured for production load (see technical-architecture.md:90)

**PostgreSQL with Fluent:**
- Use Fluent query builder exclusively (NO raw SQL)
- Async operations throughout (database.query(on:).all())
- Connection pooling pre-configured
- Proper indexing for performance

**Caching Strategy:**
- TTL Management: Context-aware expiration (see technical-architecture.md:426)
- LRU Eviction: Automatic memory management
- Hit Rate Monitoring: Real-time statistics
- Cache keys should be content-based for consistency

**Security Considerations:**
- Public endpoint (no auth) for config fetch
- Admin endpoints require JWT authentication
- No sensitive data in config (document this)
- Rate limiting may be needed (follow Story 1.1 pattern)

**Performance Targets:**
From technical-architecture.md:437-447:
- Database Queries: < 50ms
- Cached responses: < 100ms
- Use Redis for high-traffic endpoints

### Project Context Reference

**Module Boundaries (project-context.md:49-54):**
- RemoteConfig owns its Router, Controller, Models, Repository
- NEVER import other module's internal types
- Cross-module communication through Services only
- Controllers call Services, Services call Repositories

**Service Registration Pattern (project-context.md:56-66):**
```swift
// In Application-Setup.swift
app.configCacheService = RedisConfigCacheService(redis: app.redis)
app.remoteConfigRepository = DatabaseRemoteConfigRepository(database: app.db)
```

**Repository Access (project-context.md:253-261):**
```swift
// In controller
let config = try await req.repositories.remoteConfig.getAllConfig()
```

**Testing Isolation (project-context.md:179-200):**
- Each test suite gets fresh Application and database
- SQLite In-Memory for fast, isolated tests
- Use Swift Testing framework with @Test and #expect

**Anti-Patterns to Avoid (project-context.md:204-216):**
- ❌ NO DispatchQueue.global().async (use async/await)
- ❌ NO try! force unwrap (handle errors properly)
- ❌ NO raw Abort() throws (use AppError enum)
- ❌ NO inline SQL queries (use Fluent)
- ❌ NO hardcoded values (use environment variables)
- ❌ NO synchronous blocking calls (use async alternatives)

### Implementation Checklist

**Before Starting:**
- [ ] Verify redis package in Package.swift
- [ ] Check REDIS_URL environment variable configured
- [ ] Review Story 1.1 router pattern
- [ ] Review existing module structures

**During Implementation:**
- [ ] Follow module structure exactly as documented
- [ ] Use async/await throughout (Swift 6)
- [ ] All errors conform to AppError
- [ ] All types marked Sendable where needed
- [ ] Follow naming conventions (snake_case DB, camelCase Swift, kebab-case API)
- [ ] Add `.grouped("v1")` in router (critical!)
- [ ] Use protocol-first design for services

**Testing:**
- [ ] IsolatedTestWorld pattern for integration tests
- [ ] Test both happy path AND error cases
- [ ] Mock services via protocol injection
- [ ] Verify cache hit/miss scenarios
- [ ] Test all four value types
- [ ] Test authentication on admin endpoints

**Documentation:**
- [ ] Create docs/features/remote-config.md (follow api-versioning.md pattern)
- [ ] Document endpoint usage examples
- [ ] Document admin workflows
- [ ] Document cache behavior
- [ ] Note any breaking changes or considerations

**Before Marking Complete:**
- [ ] All tests passing
- [ ] No compilation errors or warnings
- [ ] Feature documentation created
- [ ] Story file updated with completion notes
- [ ] Ready for code review

### References

**Source Documents:**
- [Source: _bmad-output/epics.md#story-1.2:210-256] - Story acceptance criteria and epic context
- [Source: docs/architecture/technical-architecture.md#module-architecture:26-39] - Module structure pattern
- [Source: docs/architecture/technical-architecture.md#service-layer:144-188] - Service pattern and DI
- [Source: docs/architecture/technical-architecture.md#repository-pattern:219-261] - Repository abstraction
- [Source: docs/architecture/technical-architecture.md#redis-caching:367-373] - Redis integration pattern
- [Source: docs/project-context.md#module-structure:119-134] - Module structure requirements
- [Source: docs/project-context.md#swift-6-concurrency:29-47] - Async/await requirements
- [Source: docs/project-context.md#naming-conventions:104-115] - Naming standards
- [Source: docs/features/api-versioning.md#router-update-pattern:29-45] - Versioning pattern from Story 1.1
- [Source: _bmad-output/implementation-artifacts/1-1-add-api-version-prefix-to-all-public-routes.md#dev-notes] - Previous story learnings

**Web Research Sources:**
- [Vapor: Redis → Overview](https://docs.vapor.codes/redis/overview/) - Official Redis integration docs
- [Swift Configuration 1.0 released](https://www.swift.org/blog/swift-configuration-1.0-released/) - New Swift config library (Dec 2025)
- [Redis and Vapor With Server-Side Swift: Getting Started | Kodeco](https://www.kodeco.com/20954594-redis-and-vapor-with-server-side-swift-getting-started) - Redis best practices
- [Server-Side Swift with Vapor, Chapter 27: Caching | Kodeco](https://www.kodeco.com/books/server-side-swift-with-vapor/v3.0.ea1/chapters/27-caching) - Caching strategies

## Dev Agent Record

### Context Reference

<!-- Path(s) to story context XML will be added here by context workflow -->

### Agent Model Used

claude-sonnet-4-5-20250929

### Debug Log References

### Completion Notes List

✅ Successfully implemented Remote Config endpoint with full feature set:
- Created complete RemoteConfig module following project architecture
- Implemented public GET /api/v1/config endpoint (no authentication)
- Implemented admin endpoints with JWT authentication (POST/GET/DELETE)
- Created Redis caching service with 5-minute TTL
- Implemented typed config storage supporting boolean, integer, string, and JSON values
- Database schema with ConfigEntryModel supporting all value types
- Config transformation logic for feature flags (feature_*) and settings (setting_*)
- Comprehensive integration tests covering public and admin endpoints
- All tests passing

### File List

**New Files:**
- Sources/App/Modules/RemoteConfig/RemoteConfigModule.swift
- Sources/App/Modules/RemoteConfig/RemoteConfigRouter.swift
- Sources/App/Modules/RemoteConfig/Controller/RemoteConfigController.swift
- Sources/App/Modules/RemoteConfig/Models/RemoteConfig+Model.swift
- Sources/App/Modules/RemoteConfig/Database/Models/ConfigEntryModel.swift
- Sources/App/Modules/RemoteConfig/Database/Migrations/RemoteConfigMigrations.swift
- Sources/App/Modules/RemoteConfig/Repositories/RemoteConfigRepository.swift
- Sources/App/Services/ConfigCache/ConfigCacheService.swift
- Tests/AppTests/Framework/Mocks/MockConfigCacheService.swift
- Tests/AppTests/Tests/ControllerTests/RemoteConfigTests/RemoteConfigGetTests.swift
- Tests/AppTests/Tests/ControllerTests/RemoteConfigTests/RemoteConfigAdminTests.swift

**Modified Files:**
- Sources/App/Entrypoint/Application-Setup.swift (registered module and service)
- Tests/AppTests/Framework/IsolatedTestWorld.swift (added ConfigCacheService mock)
- _bmad-output/implementation-artifacts/sprint-status.yaml (updated story status)

