# Remote Configuration Endpoint

**Date:** 2026-01-22
**Related Files:** RemoteConfigModule.swift, RemoteConfigRouter.swift, RemoteConfigController.swift, RemoteConfigModel.swift, RemoteConfigRepository.swift

## Overview

Implemented a remote configuration system that enables mobile apps to fetch feature flags and settings without requiring app updates. The system provides a public GET endpoint for clients and admin-protected endpoints for configuration management, with PostgreSQL persistence and Redis caching (5-minute TTL).

## What Was Built

- Public endpoint for mobile apps to fetch all configuration as grouped feature flags and settings
- Admin-only CRUD endpoints for managing configuration entries
- PostgreSQL database persistence with typed value support (boolean, integer, string)
- Redis caching with 5-minute TTL and automatic cache invalidation on writes
- Value type validation ensuring stored values match their declared types

## Technical Implementation

### Key Files

- `Sources/App/Modules/RemoteConfig/RemoteConfigModule.swift`: Module registration and migration setup
- `Sources/App/Modules/RemoteConfig/RemoteConfigRouter.swift`: Route definitions with public/admin separation
- `Sources/App/Modules/RemoteConfig/Controllers/RemoteConfigController.swift`: Business logic with caching
- `Sources/App/Modules/RemoteConfig/Models/RemoteConfig+Model.swift`: Request/response DTOs and AnyCodable helper
- `Sources/App/Modules/RemoteConfig/Database/Models/RemoteConfigModel.swift`: Database model with value type enum
- `Sources/App/Modules/RemoteConfig/Repositories/RemoteConfigRepository.swift`: Data access layer

### Key Patterns

- **Public vs Admin Route Pattern**: The router separates public endpoints (no auth) from admin endpoints (requires `UserAccountModel.guard()` + `EnsureAdminUserMiddleware()`)

- **Redis Caching with Invalidation**: Cache key `remote_config:all` with 300-second TTL. All write operations (create/update/delete) invalidate the cache immediately.

- **Category-Based Grouping**: Config entries have an explicit `category` field (`feature_flags` or `settings`) that determines their grouping in the API response.

- **Typed Value Validation**: Values are validated against their declared `valueType` before storage. The `ValueType` enum provides validation logic.

- **AnyCodable Wrapper**: Type-erased Codable wrapper enables returning mixed-type JSON (boolean, integer, string) in a single response object.

### Code Examples

**Creating a new config entry (Admin):**

```swift
// POST /api/v1/config
let createRequest = RemoteConfig.Create.Request(
    key: "enablePaywall",
    value: "true",
    valueType: "boolean",
    category: "feature_flags"
)
```

**Fetching config (Mobile App):**

```swift
// GET /api/v1/config
// Response:
{
  "feature_flags": {
    "enablePaywall": true
  },
  "settings": {
    "maxRetries": 3
  }
}
```

**Adding a new config type (extending the system):**

```swift
// In RemoteConfigModel.swift
enum ValueType: String, Codable, CaseIterable {
    case boolean
    case integer
    case string
    case newType  // Add new type here

    func validate(_ value: String) -> Bool {
        switch self {
        case .newType:
            // Add validation logic
            return true
        // ... existing cases
        }
    }
}
```

## How to Use

### For Mobile App Integration

1. **Fetch Configuration:**
   ```
   GET /api/v1/config
   ```
   No authentication required. Returns feature flags and settings grouped by category.

2. **Parse Response:**
   - `feature_flags`: Boolean flags for enabling/disabling features
   - `settings`: Integer and string configuration values

3. **Cache Locally:** Consider caching the response client-side with a reasonable TTL (e.g., 5 minutes) to reduce network requests.

### For Admin Configuration Management

1. **List All Configs:**
   ```
   GET /api/v1/config/list
   Authorization: Bearer <admin-token>
   ```

2. **Create Config:**
   ```
   POST /api/v1/config
   Authorization: Bearer <admin-token>
   Content-Type: application/json

   {
     "key": "featureName",
     "value": "true",
     "value_type": "boolean",
     "category": "feature_flags"
   }
   ```

3. **Update Config:**
   ```
   PATCH /api/v1/config/:key
   Authorization: Bearer <admin-token>
   Content-Type: application/json

   {
     "value": "false",
     "value_type": "boolean"  // optional, defaults to existing type
   }
   ```

4. **Delete Config:**
   ```
   DELETE /api/v1/config/:key
   Authorization: Bearer <admin-token>
   ```

## Configuration

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| Cache TTL | Integer | 300 seconds | How long config is cached in Redis before refresh |
| Cache Key | String | `remote_config:all` | Redis key for cached config response |

No environment variables required. Cache settings are hardcoded in `RemoteConfigController.swift`.

## Notes

### Why Explicit Categories?

The `category` field was added to provide explicit control over grouping rather than inferring from value type. This allows:
- Boolean settings (not feature flags) to exist in the `settings` group
- Clear admin understanding of where configs will appear in the API response

### Value Type Validation

Values are validated before storage to ensure data integrity:
- `boolean`: Must be "true" or "false" (case-insensitive)
- `integer`: Must be parseable as Int
- `string`: Any non-empty string

Invalid values return HTTP 400 Bad Request.

### Cache Invalidation Strategy

The cache is invalidated (deleted) rather than updated on write operations. This ensures:
- Consistency across distributed instances
- Simplicity (no need to rebuild the cache structure on partial updates)
- The next read operation rebuilds the cache from the database

### Testing

The feature includes 23 integration tests covering:
- Public endpoint access (3 tests)
- Admin CRUD operations (12 tests)
- Value type validation (2 tests)
- Security/authorization (6 tests)
- Cache behavior (4 tests)

Tests use the `IsolatedTestWorld` pattern and `.serialized` suite decorator.

### OpenAPI Documentation

All endpoints are documented with VaporToOpenAPI decorators. The OpenAPI spec is automatically generated and includes:
- Endpoint descriptions
- Request/response schemas
- Authentication requirements
- Error response codes
