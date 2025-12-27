# Remote Configuration and Feature Flags Module

**Date:** 2025-12-27
**Related Files:** RemoteConfigController.swift, RemoteConfigModule.swift, RemoteConfigRouter.swift, RemoteConfigModel.swift, RemoteConfigRepository.swift, RemoteConfig+Content.swift

## Overview

The RemoteConfig module provides a cache-optimized REST API for delivering feature flags and application settings to mobile clients. It implements a repository pattern with intelligent cache invalidation, type-safe heterogeneous value handling using AnyCodableValue, and separates public read access from admin-protected configuration updates. This allows mobile apps to fetch configuration without authentication while ensuring only admins can modify values.

## What Was Built

- Public GET endpoint (`/api/v1/config`) for fetching feature flags and settings
- Admin-protected PATCH endpoint (`/api/v1/admin/config`) for updating configuration
- Database model with support for multiple value types (boolean, integer, string, JSON)
- Repository pattern with type-safe database operations
- Cache layer with 5-minute TTL and automatic invalidation on updates
- AnyCodableValue wrapper for handling heterogeneous typed values in JSON responses
- Key-based routing logic to categorize configs into featureFlags vs settings
- Comprehensive test coverage including route versioning tests

## Technical Implementation

### Key Files

- `Sources/App/Modules/RemoteConfig/Controllers/RemoteConfigController.swift`: Handles GET and PATCH requests with cache management
- `Sources/App/Modules/RemoteConfig/RemoteConfigRouter.swift`: Defines versioned routes with OpenAPI documentation
- `Sources/App/Modules/RemoteConfig/Database/Models/RemoteConfigModel.swift`: Fluent model for remote_configs table
- `Sources/App/Modules/RemoteConfig/Repositories/RemoteConfigRepository.swift`: Repository protocol and implementation for database operations
- `Sources/App/Modules/RemoteConfig/Models/RemoteConfig+Content.swift`: Request/response DTOs including AnyCodableValue enum
- `Sources/App/Modules/RemoteConfig/Database/Migrations/RemoteConfigMigrations.swift`: Database schema migrations
- `Sources/App/Modules/RemoteConfig/RemoteConfigModule.swift`: Module registration and setup
- `Tests/AppTests/Tests/ControllerTests/RemoteConfigTests/`: Test suite including versioning, admin, and public endpoint tests

### Key Patterns

**Cache-Backed Repository Pattern:**

The controller implements a read-through cache pattern where GET requests first check the cache, and only query the database on cache miss. Updates invalidate the cache to ensure fresh data:

```swift
func getConfig(_ req: Request) async throws -> RemoteConfig.GetResponse {
    // Try cache first
    if let cached = try await req.services.cache.get(cacheKey, as: RemoteConfig.GetResponse.self) {
        return cached
    }

    // Cache miss - fetch from database
    let repository = req.repositories.remoteConfig
    let configs = try await repository.getAll()

    // Build response and cache it
    let response = buildResponse(from: configs)
    try await req.services.cache.set(cacheKey, value: response, ttl: cacheTTL)

    return response
}

func updateConfig(_ req: Request) async throws -> RemoteConfig.UpdateResponse {
    // Update database
    _ = try await repository.update(...)

    // Invalidate cache
    try await req.services.cache.delete(cacheKey)

    return response
}
```

**Key-Based Configuration Routing:**

The controller categorizes configuration entries into `featureFlags` or `settings` based on key prefixes:

```swift
for config in configs {
    let parsedValue = parseConfigValue(config.value, type: config.valueType)

    // Route to appropriate category based on key prefix
    if config.key.hasPrefix("feature_") || config.key.hasPrefix("enable") {
        let key = config.key.replacingOccurrences(of: "feature_", with: "")
        featureFlags[key] = parsedValue
    } else if config.key == "version" {
        version = config.value
    } else {
        settings[config.key] = parsedValue
    }
}
```

**Naming Convention:**
- Keys with prefix `feature_` or `enable` → routed to `featureFlags` (prefix stripped)
- Key `version` → maps to top-level `version` field
- All other keys → routed to `settings`

**AnyCodableValue Type Wrapper:**

To support heterogeneous typed values in the JSON response (booleans, integers, strings, objects), the module uses a custom `AnyCodableValue` enum that is fully Codable:

```swift
enum AnyCodableValue: Codable, Sendable {
    case bool(Bool)
    case int(Int)
    case string(String)
    case object([String: AnyCodableValue])

    // Custom Codable implementation to encode/decode as native JSON types
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .bool(let value): try container.encode(value)
        case .int(let value): try container.encode(value)
        case .string(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        }
    }
}
```

This allows the response to contain mixed types while remaining fully Codable for caching and JSON serialization.

**Value Type Parsing:**

The database stores all values as strings with an associated `ConfigValueType` enum. The controller parses values based on type at runtime:

```swift
private func parseConfigValue(_ value: String, type: ConfigValueType) -> RemoteConfig.AnyCodableValue {
    switch type {
    case .boolean:
        return .bool(value.lowercased() == "true")
    case .integer:
        return .int(Int(value) ?? 0)
    case .string:
        return .string(value)
    case .json:
        // Attempt to parse as JSON object, fallback to string
        if let data = value.data(using: .utf8),
           let dict = try? JSONDecoder().decode([String: RemoteConfig.AnyCodableValue].self, from: data) {
            return .object(dict)
        }
        return .string(value)
    }
}
```

**Public vs Admin Endpoint Separation:**

The router separates public and admin functionality using Vapor's grouped route builders:

```swift
// Public endpoint - no auth required
let apiV1 = routes.grouped("api").grouped("v1")
apiV1.grouped("config").get(use: controller.getConfig)

// Admin endpoint - requires authentication + admin role
let admin = apiV1
    .grouped("admin")
    .grouped(UserPayloadAuthenticator())
    .grouped(EnsureAdminUserMiddleware())
    .grouped("config")

admin.patch(use: controller.updateConfig)
```

**Repository Pattern:**

The module follows the repository pattern established in the codebase:

```swift
protocol RemoteConfigRepository: Repository {
    func getAll() async throws -> [RemoteConfigModel]
    func get(key: String) async throws -> RemoteConfigModel?
    func update(key: String, value: String, type: ConfigValueType) async throws -> RemoteConfigModel
    func delete(key: String) async throws
}
```

The repository handles upsert logic (update if exists, create if not):

```swift
func update(key: String, value: String, type: ConfigValueType) async throws -> RemoteConfigModel {
    if let existing = try await get(key: key) {
        existing.value = value
        existing.valueType = type
        try await existing.update(on: database)
        return existing
    } else {
        let new = RemoteConfigModel(key: key, value: value, valueType: type)
        try await new.create(on: database)
        return new
    }
}
```

## How to Use

### For Mobile App Integration

**Fetching Configuration:**

Mobile apps can fetch feature flags and settings without authentication:

```swift
// iOS Example
let url = URL(string: "https://api.example.com/api/v1/config")!
let (data, _) = try await URLSession.shared.data(from: url)
let config = try JSONDecoder().decode(RemoteConfigResponse.self, from: data)

// Access feature flags
if let enableNewUI = config.featureFlags["enableNewUI"] as? Bool {
    // Use feature flag
}

// Access settings
if let maxRetries = config.settings["maxRetries"] as? Int {
    // Use setting
}

// Access version
print("Config version: \(config.version)")
```

**Response Format:**

```json
{
  "featureFlags": {
    "enableNewUI": true,
    "darkMode": false
  },
  "settings": {
    "maxRetries": 3,
    "apiTimeout": 30,
    "theme": "light"
  },
  "version": "1.2.0"
}
```

### For Admin Configuration Management

**Updating Configuration:**

Admins can update configuration values via the PATCH endpoint (requires authentication):

```bash
curl -X PATCH https://api.example.com/api/v1/admin/config \
  -H "Authorization: Bearer <admin-token>" \
  -H "Content-Type: application/json" \
  -d '{
    "key": "feature_enableNewUI",
    "value": "true",
    "type": "boolean"
  }'
```

**Response:**

```json
{
  "success": true,
  "key": "feature_enableNewUI",
  "message": "Configuration updated successfully"
}
```

### For Backend Development

**Adding New Configuration Keys:**

Use the admin endpoint or database migrations to add configuration keys. Follow the naming convention:

1. **Feature Flags:** Use `feature_` prefix or `enable` prefix
   - Examples: `feature_darkMode`, `enableBetaFeatures`
   - Will appear in `featureFlags` without prefix

2. **Settings:** Use descriptive key names without special prefixes
   - Examples: `maxRetries`, `apiTimeout`, `defaultTheme`
   - Will appear in `settings`

3. **Version:** Use key `version` for API version tracking
   - Will appear as top-level `version` field

**Value Types:**

- `boolean`: Stored as "true" or "false" string, parsed to Bool
- `integer`: Stored as number string, parsed to Int
- `string`: Stored and returned as-is
- `json`: Stored as JSON string, parsed to object if valid JSON

**Example Migration:**

```swift
struct SeedInitialConfig: AsyncMigration {
    func prepare(on database: Database) async throws {
        let configs = [
            RemoteConfigModel(key: "feature_enableNewUI", value: "false", valueType: .boolean),
            RemoteConfigModel(key: "maxRetries", value: "3", valueType: .integer),
            RemoteConfigModel(key: "version", value: "1.0.0", valueType: .string)
        ]
        try await configs.create(on: database)
    }
}
```

## Configuration

### Cache Settings

The cache layer uses the following defaults (configured in `RemoteConfigController`):

- **Cache Key:** `"remote_config:latest"`
- **TTL:** `300.0` seconds (5 minutes)
- **Strategy:** Read-through cache with invalidation on updates

To modify cache behavior, update the constants in `RemoteConfigController.swift`:

```swift
struct RemoteConfigController {
    private let cacheKey = "remote_config:latest"
    private let cacheTTL = 300.0 // Adjust TTL here
}
```

### Database Schema

The `remote_configs` table has the following structure:

- `id` (UUID): Primary key
- `config_key` (String): Unique configuration key
- `config_value` (String): Value stored as string
- `value_type` (ConfigValueType): Enum indicating how to parse value
- `created_at` (Timestamp): Creation timestamp
- `updated_at` (Timestamp): Last update timestamp

### Environment Variables

No environment variables required. Uses existing:

- Database connection (configured via Vapor)
- Cache service (configured via Application services)
- Authentication middleware (existing auth system)

## Notes

### Why Cache Configuration Responses?

Configuration data is:
- **Read-heavy:** Mobile apps fetch on every launch
- **Rarely changes:** Admins update infrequently
- **Performance-critical:** High traffic endpoint

The 5-minute cache dramatically reduces database load while ensuring updates propagate within reasonable time.

### Why AnyCodableValue Instead of JSON Dictionary?

Swift's `Codable` protocol doesn't support heterogeneous dictionaries (`[String: Any]`) without custom encoding. The `AnyCodableValue` enum:

1. **Fully Codable:** Can be cached using Vapor's cache system
2. **Type-safe:** Compiler-checked value types
3. **JSON-friendly:** Encodes to native JSON types (not wrapped)
4. **Extensible:** Easy to add new types if needed

### Cache Invalidation Strategy

The cache is invalidated on ANY update to ensure consistency:

```swift
func updateConfig(_ req: Request) async throws -> RemoteConfig.UpdateResponse {
    _ = try await repository.update(...)
    try await req.services.cache.delete(cacheKey)  // ← Invalidate entire cache
    return response
}
```

This simple strategy works because:
- All configs are fetched together (single cache entry)
- Updates are infrequent (admin-only)
- Cache rebuilds quickly (5-minute TTL)

### Performance Considerations

**Cache Warmup:**
- First request after cache expiry/invalidation queries database
- Subsequent requests served from cache (fast)
- Consider pre-warming cache on app startup if needed

**Scaling:**
- Cache reduces database queries by ~99% for typical usage
- Database queries use `.all()` without filtering (full table scan)
- For very large config sets (>1000 entries), consider indexing or partitioning

### Security Considerations

**Public Endpoint Security:**
- GET endpoint is intentionally public (no auth)
- Only exposes configuration data (no secrets)
- Cache prevents DOS via database overload

**Admin Endpoint Security:**
- PATCH endpoint protected by `UserPayloadAuthenticator()` + `EnsureAdminUserMiddleware()`
- Follows existing auth patterns from other modules
- Consider audit logging for configuration changes

⚠️ **CRITICAL:** Never store secrets or credentials in this system. Configuration values are returned in plain text to mobile apps.

### API Versioning

This module follows the API versioning pattern documented in `docs/features/api-versioning.md`:

- Public endpoint: `/api/v1/config`
- Admin endpoint: `/api/v1/admin/config`
- Tests verify versioned routes work and unversioned routes return 404

### Testing Requirements

When modifying this module:

- ✅ Test public endpoint returns proper structure
- ✅ Test admin endpoint requires authentication
- ✅ Test cache hit/miss scenarios
- ✅ Test value type parsing for all types
- ✅ Test key-based routing to featureFlags vs settings
- ✅ Test cache invalidation on updates
- ✅ Test route versioning (see `RemoteConfigRouteVersioningTests.swift`)

### Common Issues

**Problem:** Cache not invalidating after update
**Solution:** Verify `cache.delete()` is called in update handler

**Problem:** Values parsing incorrectly
**Solution:** Check `valueType` matches actual value format in database

**Problem:** Config not appearing in correct category
**Solution:** Verify key naming follows prefix convention (`feature_` for flags)

**Problem:** Admin endpoint returns 401
**Solution:** Ensure request includes valid admin bearer token

### Future Enhancements

**Potential Improvements:**

1. **Selective Cache Invalidation:** Invalidate only changed keys instead of entire cache
2. **Config History:** Track changes with timestamps and admin user
3. **Batch Updates:** Allow updating multiple keys in single request
4. **Config Validation:** Add schema validation for complex JSON values
5. **DELETE Endpoint:** Admin endpoint to delete config keys
6. **Config Environments:** Separate configs for dev/staging/production
7. **Real-time Updates:** WebSocket or SSE for live config updates to clients

### Reusable Patterns from This Module

This module demonstrates several patterns applicable to other modules:

1. **Cache-Backed Repository:** Use read-through cache for read-heavy data
2. **Public vs Admin Endpoint Separation:** Separate routes with different auth requirements
3. **AnyCodableValue Pattern:** Handle heterogeneous typed values in Codable responses
4. **Upsert Repository Pattern:** Update if exists, create if not logic
5. **Key-Based Routing:** Categorize data based on key prefixes or patterns
6. **OpenAPI Documentation:** Inline route documentation with `.openAPI()`

Refer to this module when implementing similar cache-backed configuration or settings systems.
