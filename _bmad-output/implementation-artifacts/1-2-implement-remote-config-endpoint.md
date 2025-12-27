# Story 1.2: Implement Remote Config Endpoint

Status: ready-for-dev
Linear Issue: RULE-151
Epic: 1 - API Versioning & Stability
Created: 2025-12-27

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

- [ ] Create RemoteConfig module foundation (AC: Structure)
  - [ ] Create `RemoteConfigModule.swift` for module registration
  - [ ] Create `RemoteConfigRouter.swift` with `/api/v1/` versioned routes
  - [ ] Create directory structure following established pattern
- [ ] Implement database model and migrations (AC: 3, 6)
  - [ ] Create `RemoteConfigModel.swift` with Fluent schema
  - [ ] Define fields: `key` (String), `value` (JSON), `valueType` (enum), `updatedAt`
  - [ ] Create migration for `remote_configs` table
  - [ ] Support typed values: boolean, integer, string, JSON object
- [ ] Implement repository pattern for data access (AC: 3, 6)
  - [ ] Create `RemoteConfigRepository` protocol
  - [ ] Implement `RemoteConfigDatabaseRepository`
  - [ ] Add methods: `getAll()`, `get(key:)`, `update(_:)`, `delete(key:)`
- [ ] Implement controller with public GET endpoint (AC: 1, 2)
  - [ ] Create `RemoteConfigController.swift`
  - [ ] Implement `GET /api/v1/config` endpoint
  - [ ] Return all active configs as JSON dictionary
  - [ ] No authentication required for GET
- [ ] Implement Redis caching with 5-minute TTL (AC: 3, 6)
  - [ ] Integrate with existing Redis cache service
  - [ ] Cache full config response with 300-second TTL
  - [ ] Generate cache key based on config version/hash
  - [ ] Implement cache-aside pattern (check cache → fetch DB → update cache)
- [ ] Implement admin update endpoint (AC: 5)
  - [ ] Create `PATCH /api/v1/admin/config` endpoint
  - [ ] Require JWT authentication + admin role check
  - [ ] Accept updates to individual config keys
  - [ ] Invalidate cache on successful update
- [ ] Add comprehensive tests (All AC)
  - [ ] Test public GET endpoint returns config
  - [ ] Test cache hit scenario (fast response)
  - [ ] Test cache miss scenario (DB fetch + cache update)
  - [ ] Test admin PATCH requires authentication
  - [ ] Test admin PATCH updates DB and invalidates cache
  - [ ] Test unauthenticated admin request returns 401
  - [ ] Test typed value support (boolean, integer, string, JSON)

---

## Relevant Feature Documentation

### API Versioning Pattern (docs/features/api-versioning.md)

**Critical for this story:** The Remote Config endpoint MUST follow the established API versioning pattern.

**Router Pattern:**
```swift
func boot(routes: RoutesBuilder) throws {
    let api = routes
        .grouped("api")
        .grouped("v1")           // ← Version prefix REQUIRED
        .grouped("remote-config")
        .groupedOpenAPI(tags: .init(name: "Remote Config",
                                     description: "Configuration and feature flags"))

    // Public endpoints
    api.get("", use: controller.getConfig)

    // Admin endpoints
    let admin = api
        .grouped("admin")
        .grouped(UserPayloadAuthenticator())
        .grouped(EnsureAdminUserMiddleware())
    admin.patch("", use: controller.updateConfig)
}
```

**Testing Pattern:**
```swift
@Test("Config endpoint accessible with v1 prefix")
func testVersionedEndpoint() async throws {
    try await app.test(.GET, "api/v1/remote-config") { req in
        // Test implementation
    } afterResponse: { response in
        #expect(response.status == .ok)
    }
}

@Test("Old unversioned route returns 404")
func oldRouteReturns404() async throws {
    try await app.test(.GET, "api/remote-config") { req in
        // Test implementation
    } afterResponse: { response in
        #expect(response.status == .notFound)
    }
}
```

**Key Requirements:**
- All routes MUST include `/api/v1/` prefix
- OpenAPI spec automatically reflects versioned paths
- Tests must verify both versioned routes work AND old routes return 404
- Version prefix comes BEFORE module-specific grouping

---

## Developer Context

### Technical Requirements

**Framework & Language:**
- Vapor 4 with Swift 6.0+
- PostgreSQL for persistent storage
- Redis for caching (5-minute TTL for config endpoint)
- Fluent ORM for database operations
- VaporToOpenAPI for automatic API documentation

**Configuration Data Model:**
The remote config system must support multiple typed values:
- **Feature Flags:** Boolean values (e.g., `enableNewScanner: true`)
- **Settings:** Integer values (e.g., `maxRetries: 3`)
- **Parameters:** String values (e.g., `apiBaseUrl: "https://api.example.com"`)
- **Complex Config:** JSON objects for structured data

**Endpoint Design:**
1. **Public Endpoint:** `GET /api/v1/config` - No authentication, heavily cached
2. **Admin Endpoint:** `PATCH /api/v1/admin/config` - JWT auth + admin role required

### Architecture Compliance

**From Architecture Analysis:**

**Module Structure (MANDATORY):**
```
Sources/App/Modules/RemoteConfig/
├── RemoteConfigModule.swift           # Module registration
├── RemoteConfigRouter.swift           # Route definitions
├── Controllers/
│   └── RemoteConfigController.swift   # Business logic
├── Repositories/
│   └── RemoteConfigRepository.swift   # Data access
├── Models/
│   └── RemoteConfig+Content.swift     # Request/Response DTOs
└── Database/
    ├── Models/
    │   └── RemoteConfigModel.swift    # Fluent entity
    └── Migrations/
        └── RemoteConfigMigrations.swift
```

**Naming Conventions:**
- Database table: `remote_configs` (snake_case, plural)
- Database columns: `config_key`, `config_value`, `value_type`, `updated_at` (snake_case)
- API endpoints: `/api/v1/remote-config/` (kebab-case)
- Swift types: `RemoteConfigController`, `RemoteConfigModel` (PascalCase)
- Swift properties: `configKey`, `configValue`, `valueType` (camelCase)

**Controller-Centric Design:**
- Business logic lives directly in `RemoteConfigController.swift`
- No separate use case/service layer needed
- Controllers handle request validation, response formatting, and orchestration

**Repository Pattern:**
```swift
protocol RemoteConfigRepository: Repository {
    func getAll() async throws -> [RemoteConfigModel]
    func get(key: String) async throws -> RemoteConfigModel?
    func update(key: String, value: String, type: ConfigValueType) async throws -> RemoteConfigModel
    func delete(key: String) async throws
}

final class RemoteConfigDatabaseRepository: RemoteConfigRepository {
    let database: Database

    init(database: Database) {
        self.database = database
    }

    func getAll() async throws -> [RemoteConfigModel] {
        try await RemoteConfigModel.query(on: database).all()
    }

    func get(key: String) async throws -> RemoteConfigModel? {
        try await RemoteConfigModel.query(on: database)
            .filter(\.$key == key)
            .first()
    }
}
```

**Access repositories in controllers via:**
```swift
let configs = try await req.repositories.remoteConfig.getAll()
```

### Library & Framework Requirements

**Vapor 4 Dependencies:**
- `import Vapor` - Core framework
- `import Fluent` - ORM layer
- `import FluentPostgresDriver` - PostgreSQL driver
- `import VaporToOpenAPI` - API documentation

**Swift Configuration (2025 - Production Ready):**
According to recent releases, Swift Configuration 1.0 is production-ready and provides a common API for reading configuration across the Swift ecosystem. Consider this for future enhancements if dynamic config loading from multiple sources is needed.

**Redis Integration:**
- Use existing `req.services.cache` for Redis operations
- RediStack is used behind the scenes in Vapor
- Cache key pattern: `"remote_config:v\(version)"`
- TTL: 300 seconds (5 minutes)

**PostgreSQL Enum Types:**
For `ConfigValueType` enum, use Fluent's native database enum support:

```swift
// In migration:
database.enum("config_value_type")
    .case("boolean")
    .case("integer")
    .case("string")
    .case("json")
    .create()

// Then in model:
@Enum(key: "value_type")
var valueType: ConfigValueType
```

This provides type safety and better performance than raw string storage.

### File Structure Requirements

**Files to Create:**

1. **Module Registration:**
   - `Sources/App/Modules/RemoteConfig/RemoteConfigModule.swift`
   - Conforms to `ModuleInterface` protocol
   - Registers routes with the application

2. **Router Definition:**
   - `Sources/App/Modules/RemoteConfig/RemoteConfigRouter.swift`
   - MUST use `.grouped("api").grouped("v1").grouped("remote-config")`
   - Public GET route + Admin PATCH route

3. **Controller:**
   - `Sources/App/Modules/RemoteConfig/Controllers/RemoteConfigController.swift`
   - Methods: `getConfig(_:)`, `updateConfig(_:)`

4. **Database Model:**
   - `Sources/App/Modules/RemoteConfig/Database/Models/RemoteConfigModel.swift`
   - Schema: `remote_configs`
   - Fields: `id`, `key`, `value`, `valueType`, `updatedAt`

5. **Migration:**
   - `Sources/App/Modules/RemoteConfig/Database/Migrations/RemoteConfigMigrations.swift`
   - Create table + enum type

6. **Repository:**
   - `Sources/App/Modules/RemoteConfig/Repositories/RemoteConfigRepository.swift`
   - Protocol + Database implementation

7. **DTOs:**
   - `Sources/App/Modules/RemoteConfig/Models/RemoteConfig+Content.swift`
   - Request/Response structures

8. **Error Handling:**
   - `Sources/App/Entities/Errors/RemoteConfigError.swift`
   - Conforms to `AppError` enum

**Files to Modify:**

1. **Application Setup:**
   - `Sources/App/Application-Setup.swift`
   - Register RemoteConfig service/repository

2. **Module Registration:**
   - `Sources/App/configure.swift`
   - Add `try app.register(collection: RemoteConfigModule())`

3. **Service Extensions:**
   - `Sources/App/Extensions/Application+Services.swift`
   - Add `remoteConfigRepository` accessor

4. **Request Extensions:**
   - `Sources/App/Extensions/Request+Services.swift`
   - Add convenience accessor for repository

### Testing Requirements

**Test File Location:**
```
Tests/AppTests/Modules/RemoteConfig/
├── RemoteConfigControllerTests.swift
└── RemoteConfigRepositoryTests.swift
```

**IsolatedTestWorld Pattern (MANDATORY):**
```swift
@Suite(.serialized)  // Within-suite serialization
struct RemoteConfigControllerTests {
    let testWorld: IsolatedTestWorld

    init() async throws {
        testWorld = try await IsolatedTestWorld()
    }

    @Test("GET /api/v1/config returns configuration")
    func testGetConfig() async throws {
        // Seed test data
        let config = RemoteConfigModel(
            key: "enableNewScanner",
            value: "true",
            valueType: .boolean
        )
        try await testWorld.app.db.create(config)

        // Test endpoint
        try await testWorld.app.test(.GET, "api/v1/config") { _ in
        } afterResponse: { response in
            #expect(response.status == .ok)
            let body = try response.content.decode([String: Any].self)
            #expect(body["enableNewScanner"] as? Bool == true)
        }
    }

    @Test("PATCH /api/v1/admin/config requires authentication")
    func testAdminUpdateRequiresAuth() async throws {
        try await testWorld.app.test(.PATCH, "api/v1/admin/config") { req in
            try req.content.encode(["enableNewScanner": false])
        } afterResponse: { response in
            #expect(response.status == .unauthorized)
        }
    }
}
```

**Test Categories:**
1. **Integration Tests:** Controller and endpoint testing with IsolatedTestWorld
2. **Unit Tests:** Repository testing with in-memory SQLite
3. **Caching Tests:** Verify cache hit/miss behavior
4. **Security Tests:** Verify admin endpoints require auth
5. **Versioning Tests:** Verify old routes return 404

**Mock Repository Pattern:**
```swift
final class MockRemoteConfigRepository: RemoteConfigRepository {
    var configs: [String: RemoteConfigModel] = [:]

    func getAll() async throws -> [RemoteConfigModel] {
        return Array(configs.values)
    }

    func get(key: String) async throws -> RemoteConfigModel? {
        return configs[key]
    }
}

// In tests:
testWorld.app.repositories.remoteConfig = MockRemoteConfigRepository()
```

**Coverage Expectations:**
- All public endpoints tested (GET /api/v1/config)
- All admin endpoints tested (PATCH /api/v1/admin/config)
- Authentication/authorization tested
- Cache behavior tested (hit/miss scenarios)
- Error cases tested (invalid data, missing configs)
- Versioning tested (404 for old routes)

---

## Previous Story Intelligence

**From Story 1.1 (Add API Version Prefix):**

**Key Learnings:**
1. **Router Update Pattern is Consistent:**
   - All modules use `.grouped("api").grouped("v1").grouped("{module-name}")` pattern
   - Insert `.grouped("v1")` between `api` and module-specific grouping
   - OpenAPI integration preserved automatically

2. **Testing Approach:**
   - Created dedicated `*RouteVersioningTests.swift` files
   - All tests updated to use `/api/v1/` prefix
   - Negative tests added to verify old routes return 404

3. **Rate Limit Configuration:**
   - When adding new module, ensure `RateLimitConfiguration` includes it
   - Update `MockRateLimitService` for test support
   - Add properties to all configuration variants (default, production, development)

4. **Files Modified in Story 1.1:**
   - 4 Router files updated (RulesGeneration, Auth, User, Waitlist)
   - 8+ test files updated with new paths
   - Rate limit configuration files updated
   - All changes were surgical and focused

**Apply to Current Story:**
- Follow exact same router pattern for RemoteConfig module
- Create comprehensive tests from the start
- Plan for rate limit configuration updates
- Ensure mock services support new module

---

## Git Intelligence

**Recent Commit Patterns:**

**Most Recent Work (PR #26 - Story 1.1):**
```
6f61a7a - chore: mark story 1-1 as done
7c3f61d - fix(docs): update remaining API paths to v1 prefix
b8580da - docs: update documentation for API versioning implementation
```

**Commit Message Style:**
- Use conventional commit format: `type(scope): description`
- Common types: `feat`, `fix`, `chore`, `docs`, `test`
- Scope indicates affected module or area

**Code Patterns Observed:**
1. **Feature Branch Workflow:**
   - Branch naming: `feature-issue-RULE-XXX-adw-{id}-story-{num}-{description}`
   - PRs merged to `staging` branch
   - Clean, focused commits

2. **Documentation Updates:**
   - API changes accompanied by documentation updates
   - Feature documentation created for significant changes (see api-versioning.md)

**For This Story:**
- Create feature branch following naming convention
- Write focused commits for each major component
- Update documentation for remote config feature
- Include tests in same commit as implementation
- Mark story done after PR approval

---

## Latest Technical Information

### Swift Configuration Library (2025)

**Swift Configuration 1.0 is Production-Ready:**
- Common API for reading configuration across Swift ecosystem
- Original motivation: making Swift servers easier to operate
- Allows switching between env vars, CLI flags, JSON/YAML files, or remote feature flagging services without large refactor

**Future Enhancement Consideration:**
This library could be integrated in future iterations to allow RemoteConfig to pull from multiple sources (environment variables, local files, database) using a unified interface.

### Redis + PostgreSQL Caching Best Practices (2025)

**Cache-Aside Pattern:**
1. Check cache for config data
2. On cache miss, fetch from PostgreSQL
3. Store in Redis with TTL
4. Return to client

**TTL Strategy:**
- Frequently-accessed configs: 5-15 minutes (we're using 5 min per AC)
- Infrequently-changed configs: 30-60 minutes
- Admin updates: Immediate cache invalidation

**Cache Key Design:**
- Content-based: `remote_config:v{version}` or `remote_config:{hash}`
- Simple key: `remote_config:latest`

For this implementation, use simple key since config is relatively small and fetched as a whole.

### Vapor 4 + Redis Integration

**RediStack Integration:**
Vapor uses RediStack behind the scenes for Redis operations:
```swift
// Cache config response
let cacheKey = "remote_config:latest"
try await req.cache.set(cacheKey, to: configResponse, expiresIn: .seconds(300))

// Retrieve from cache
let cached = try await req.cache.get(cacheKey, as: ConfigResponse.self)
```

**Sources:**
- [Michael Tsai - Blog - Swift Configuration](https://mjtsai.com/blog/2025/12/16/swift-configuration/)
- [Redis and Vapor With Server-Side Swift: Getting Started | Kodeco](https://www.kodeco.com/20954594-redis-and-vapor-with-server-side-swift-getting-started)
- [How we made feature flags faster and more reliable - PostHog](https://posthog.com/blog/how-we-improved-feature-flags-resiliency)
- [Vapor: Fluent → Schema](https://docs.vapor.codes/fluent/schema/)
- [PostgreSQL Tutorial: Speed up applications with Redis caching](https://www.rockdata.net/tutorial/setup-redis-cache/)

---

## Project Context Reference

See: `docs/project-context.md`

Key patterns and rules from project context:
- **Module Structure:** Complete vertical slice architecture - all related code within module boundary
- **Controller-Centric:** Business logic lives in controllers, not separate service layers
- **Repository Pattern:** All data access abstracted through repository protocols
- **Property-Based DI:** Simple property accessors, no complex DI frameworks
- **IsolatedTestWorld:** Each test suite gets fresh Application and in-memory database
- **Three-Strike Rule:** Don't create abstractions until the third occurrence
- **Framework Harmony:** Work with Vapor conventions, not against them

---

## Dev Notes

### Architectural Context

**Epic 1 Objective:**
Establish versioned API endpoints and foundational services to enable safe, backward-compatible evolution of the API. This story adds the first "foundational service" - remote configuration.

**Why Remote Config?**
- Enables feature flag control without app updates
- Allows A/B testing and gradual rollouts
- Provides runtime configuration for mobile apps
- Reduces app store review cycles for behavioral changes

**Design Decisions:**
1. **Public GET, Admin PATCH:** Most configs are read-heavy, write-light
2. **5-Minute Cache TTL:** Balances freshness with performance
3. **PostgreSQL Storage:** Persistence and transactional safety
4. **JSON Value Storage:** Flexibility for complex config structures
5. **Type Enum:** Helps clients parse values correctly

### Implementation Approach

**Phase 1: Database Foundation**
1. Create migration with `remote_configs` table
2. Create `ConfigValueType` enum
3. Implement Fluent model

**Phase 2: Repository Layer**
4. Define repository protocol
5. Implement database repository
6. Register in Application setup

**Phase 3: Controller & Routes**
7. Implement GET endpoint (public)
8. Implement PATCH endpoint (admin)
9. Integrate Redis caching
10. Register routes with `/api/v1/` prefix

**Phase 4: Testing**
11. Write integration tests
12. Write repository tests
13. Test caching behavior
14. Test authentication/authorization

**Phase 5: Documentation**
15. Create feature documentation (similar to api-versioning.md)
16. Update OpenAPI spec (automatic via VaporToOpenAPI)

### Potential Challenges

**Challenge 1: JSON Value Storage**
- **Issue:** Storing arbitrary JSON in PostgreSQL field
- **Solution:** Use PostgreSQL's native JSONB type via Fluent
- **Pattern:** `@Field(key: "config_value")` with `String` type, encode/decode JSON

**Challenge 2: Cache Invalidation**
- **Issue:** Admin updates must invalidate cache immediately
- **Solution:** Delete cache key on PATCH success
- **Pattern:**
  ```swift
  try await repository.update(config)
  try await req.cache.delete("remote_config:latest")
  ```

**Challenge 3: Type Safety for Clients**
- **Issue:** Clients need to know value types
- **Solution:** Include `valueType` in response, clients parse accordingly
- **Example:**
  ```json
  {
    "featureFlags": {
      "enableNewScanner": {"value": true, "type": "boolean"}
    }
  }
  ```

**Challenge 4: Seed Data**
- **Issue:** New deployments need default config
- **Solution:** Include seed data in migration or startup script
- **Pattern:** Create default configs if table is empty

### Security Considerations

1. **Public Endpoint Risk:**
   - GET endpoint is public, no auth required
   - Rate limiting crucial to prevent abuse
   - Consider per-IP rate limit of 100/hour

2. **Admin Endpoint Protection:**
   - MUST use `UserPayloadAuthenticator` middleware
   - MUST use `EnsureAdminUserMiddleware` for role check
   - Prevent non-admins from modifying config

3. **Injection Prevention:**
   - Validate config keys (alphanumeric + underscores only)
   - Sanitize values before storage
   - Use prepared statements (Fluent handles this)

### References

- [Source: docs/architecture/technical-architecture.md - Module Structure]
- [Source: docs/architecture/future-architecture-decisions.md - API Versioning]
- [Source: docs/features/api-versioning.md - Router Pattern]
- [Source: _bmad-output/epics.md#story-1.2]
- [Source: _bmad-output/implementation-artifacts/1-1-add-api-version-prefix-to-all-public-routes.md]
- [Source: Sources/App/Modules/RulesGeneration/RulesGenerationRouter.swift - Example router]
- [Source: Sources/App/Modules/User/UserRouter.swift - Example authentication]
- [Source: Tests/AppTests/Framework/IsolatedTestWorld.swift - Test pattern]

---

## Dev Agent Record

### Context Reference

<!-- Story context will be added here during implementation -->

### Agent Model Used

<!-- Will be filled during implementation -->

### Debug Log References

<!-- Will be filled during implementation -->

### Completion Notes List

<!-- Will be filled during implementation -->

### File List

<!-- Will be filled during implementation -->
