# Remote Configuration Module

**Date:** 2026-01-20
**Related Files:** RemoteConfigController.swift, RemoteConfigRouter.swift, RemoteConfigRepository.swift, RemoteConfig+Model.swift

## Overview

Server-side remote configuration system that delivers feature flags, settings, and app version information to mobile clients without requiring app store updates. Provides a public endpoint for config retrieval (cached for 5 minutes) and admin endpoints for CRUD operations.

## What Was Built

- Public config endpoint at `/api/v1/config` (unauthenticated, cached)
- Admin CRUD endpoints at `/api/v1/admin/config` (admin-only, authenticated)
- Type-safe configuration storage with validation (boolean, integer, string, JSON)
- Automatic cache invalidation on admin mutations
- `AnyCodable` type-erased wrapper for heterogeneous JSON values
- Comprehensive test coverage (20 tests)

## Technical Implementation

### Key Files

- `Sources/App/Modules/RemoteConfig/RemoteConfigController.swift`: Controller with public `getConfig()` and admin CRUD methods
- `Sources/App/Modules/RemoteConfig/RemoteConfigRouter.swift`: Route definitions with OpenAPI documentation
- `Sources/App/Modules/RemoteConfig/Repositories/RemoteConfigRepository.swift`: Repository protocol and database implementation
- `Sources/App/Modules/RemoteConfig/Models/RemoteConfig+Model.swift`: API models and `AnyCodable` wrapper
- `Sources/App/Modules/RemoteConfig/Database/Models/RemoteConfigEntryModel.swift`: Fluent database model

### Key Patterns

**Public vs Admin Endpoint Separation:**

Public endpoint is unauthenticated for mobile app access:
```swift
let publicAPI = routes
    .grouped("api")
    .grouped("v1")
    .grouped("config")
    // No auth middleware - public access

publicAPI.get(use: controller.getConfig)
```

Admin endpoints require authentication and admin role:
```swift
let adminAPI = routes
    .grouped("api")
    .grouped("v1")
    .grouped("admin")
    .grouped("config")
    .grouped(UserAccountModel.guard())          // Requires auth
    .grouped(EnsureAdminUserMiddleware())       // Requires admin role
```

**Cache Strategy with Automatic Invalidation:**

```swift
// Cache TTL: 5 minutes for public endpoint
private static let cacheTTL: TimeInterval = 300

// On any admin mutation (create/update/delete):
try await req.services.cache.delete(Self.cacheKey)
```

**Value Type Validation:**

Values are stored as strings with type metadata for validation:
```swift
enum ValueType: String, Content {
    case boolean   // "true" or "false"
    case integer   // Parseable as Int
    case string    // Any string
    case json      // Valid JSON
}
```

**AnyCodable for Heterogeneous JSON:**

Type-erased wrapper enabling mixed-type settings in response:
```swift
struct Response: Content {
    let featureFlags: [String: Bool]      // Boolean configs → featureFlags
    let settings: [String: AnyCodable]    // Other types → settings
    let version: String
}
```

### Code Examples

**Creating a feature flag (Admin):**
```bash
POST /api/v1/admin/config
Authorization: Bearer <admin_token>
Content-Type: application/json

{
    "key": "enable_new_scanner",
    "value": "true",
    "valueType": "boolean",
    "description": "Enable the new barcode scanner feature"
}
```

**Retrieving config (Public):**
```bash
GET /api/v1/config

# Response:
{
    "featureFlags": {
        "enable_new_scanner": true
    },
    "settings": {
        "max_retries": 3,
        "api_endpoint": "https://api.example.com"
    },
    "version": "1.0.0"
}
```

**Using AnyCodable in Swift:**
```swift
// When you need heterogeneous JSON in a response:
struct AnyCodable: Codable, Equatable, @unchecked Sendable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    // Decodes any JSON primitive, array, or object
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        }
        // ... handles Int, Double, String, Array, Dictionary
    }
}
```

## How to Use

### Adding New Configuration Values

1. Call the admin create endpoint with appropriate value type
2. Boolean values become `featureFlags` in the response
3. All other types become `settings` in the response
4. Cache is automatically invalidated - new values appear within 5 minutes

### Creating Feature Flags

```bash
# Boolean → appears in featureFlags
POST /api/v1/admin/config
{
    "key": "dark_mode_enabled",
    "value": "true",
    "valueType": "boolean"
}
```

### Creating Settings

```bash
# Integer → appears in settings
POST /api/v1/admin/config
{
    "key": "max_upload_size_mb",
    "value": "50",
    "valueType": "integer"
}

# JSON → appears in settings
POST /api/v1/admin/config
{
    "key": "server_endpoints",
    "value": "{\"primary\": \"api1.example.com\", \"backup\": \"api2.example.com\"}",
    "valueType": "json"
}
```

### Mobile App Integration

```swift
// iOS client example
func fetchConfig() async throws -> RemoteConfig {
    let url = URL(string: "https://api.example.com/api/v1/config")!
    let (data, _) = try await URLSession.shared.data(from: url)
    return try JSONDecoder().decode(RemoteConfig.self, from: data)
}

// Use feature flags
if config.featureFlags["dark_mode_enabled"] == true {
    enableDarkMode()
}

// Use settings
if let maxRetries = config.settings["max_retries"] as? Int {
    setMaxRetries(maxRetries)
}
```

## Configuration

| Endpoint | Method | Auth | Description |
|----------|--------|------|-------------|
| `/api/v1/config` | GET | None | Public config retrieval (cached 5 min) |
| `/api/v1/admin/config` | GET | Admin | List all config entries |
| `/api/v1/admin/config` | POST | Admin | Create new config entry |
| `/api/v1/admin/config/:id` | PATCH | Admin | Update config entry |
| `/api/v1/admin/config/:id` | DELETE | Admin | Delete config entry |

**Value Types:**

| Type | Storage Format | Validation |
|------|---------------|------------|
| boolean | "true" or "false" | Case-insensitive, must be exact |
| integer | String number | Must parse as Int |
| string | Any string | No validation |
| json | JSON string | Must be valid JSON |

## Notes

### Design Decisions

- **Public endpoint is unauthenticated**: Mobile apps need config before user logs in
- **Cache TTL is 5 minutes**: Balance between freshness and database load
- **Values stored as strings**: Enables flexible storage with type validation on write
- **Separate featureFlags vs settings**: Clean separation for mobile client consumption

### Limitations

- No versioning of individual config values (audit trail)
- No environment-specific configs (dev/staging/prod share same table)
- No client-side caching headers (mobile apps should implement their own caching)

### Testing Patterns

```swift
// Test admin authorization
@Test("Non-admin cannot list config entries")
func nonAdminCannotListConfigEntries() async throws {
    // Create user via mock and repository (not dataFactory) for proper auth token generation
    let user = try UserAccountModel.mock(app: app, isAdmin: false)
    try await app.repositories.users.create(user)

    try await app.test(.GET, adminConfigPath, user: user, afterResponse: { res in
        #expect(res.status == .unauthorized)
    })
}

// Test value type validation
@Test("Create fails with invalid boolean value")
func createFailsWithInvalidBooleanValue() async throws {
    let createRequest = RemoteConfig.Create.Request(
        key: "badBoolean",
        value: "yes",  // Invalid - should be "true" or "false"
        valueType: .boolean,
        description: nil
    )
    // Expect 400 Bad Request
}
```

### Related Documentation

- `docs/features/api-versioning.md` - API versioning pattern used by this module
- `docs/architecture/technical-architecture.md` - Module architecture patterns
