# Remote Configuration System

**Date:** 2025-12-28
**Related Files:** ConfigModule.swift, ConfigRouter.swift, ConfigController.swift, ConfigRepository.swift, ConfigEntryModel.swift

## Overview

Implemented a backend-driven remote configuration system that allows the mobile app to fetch feature flags and settings without requiring app updates. Configuration values are stored in PostgreSQL with Redis caching for performance, and include both public (no auth) and admin (auth required) endpoints for retrieval and management.

## What Was Built

- Public endpoint for mobile app config retrieval (`GET /api/v1/config`)
- Admin CRUD endpoints for config management (`/api/v1/admin/config`)
- PostgreSQL storage for typed configuration entries
- Redis caching layer with 5-minute TTL
- Automatic cache invalidation on admin updates
- Support for typed values: boolean, integer, string, JSON

## Technical Implementation

### Key Files

- `Sources/App/Modules/Config/ConfigModule.swift`: Module registration and migration setup
- `Sources/App/Modules/Config/ConfigRouter.swift`: Route definitions for public and admin endpoints
- `Sources/App/Modules/Config/ConfigController.swift`: Request handlers with caching logic
- `Sources/App/Modules/Config/Repositories/ConfigRepository.swift`: Database access layer
- `Sources/App/Modules/Config/Database/Models/ConfigEntryModel.swift`: Fluent model for config entries
- `Sources/App/Modules/Config/Models/Config+Model.swift`: DTOs and AnyCodable helper

### Key Patterns

**Public/Admin Endpoint Split:**
```swift
// Public - no auth required
let api = routes
    .grouped("api")
    .grouped("v1")
    .grouped("config")

// Admin - requires authentication
let adminAPI = routes
    .grouped("api")
    .grouped("v1")
    .grouped("admin")
    .grouped("config")
    .grouped(UserAccountModel.guard())
    .grouped(EnsureAdminUserMiddleware())
```

**Redis Cache-First Pattern:**
```swift
func getConfig(req: Request) async throws -> Config.Response {
    let cacheService = req.services.cache

    // Try cache first
    if let cached = try await cacheService.get(Self.cacheKey, as: Config.Response.self) {
        return cached
    }

    // Cache miss - fetch from database
    let entries = try await req.repositories.config.findAll()
    let response = Config.Response.from(entries: entries)

    // Cache the response
    try await cacheService.set(Self.cacheKey, value: response, ttl: Self.cacheTTL)

    return response
}
```

**Cache Invalidation on Write:**
```swift
// Called after any create/update/delete operation
private func invalidateCache(req: Request) async throws {
    try await req.services.cache.delete(Self.cacheKey)
}
```

**Typed Value Storage:**
- Store values as strings in PostgreSQL with type metadata
- Use `AnyCodable` wrapper for JSON serialization
- Helper computed properties (`boolValue`, `intValue`, `anyValue`) for type-safe access

## How to Use

### For Mobile Apps (Public Endpoint)

Fetch configuration without authentication:

```
GET /api/v1/config
```

Response format:
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

### For Admins (Managing Config)

**List all entries:**
```
GET /api/v1/admin/config
Authorization: Bearer <token>
```

**Create new entry:**
```
POST /api/v1/admin/config
Authorization: Bearer <token>
Content-Type: application/json

{
  "key": "enableFeatureX",
  "value": "true",
  "type": "boolean"
}
```

**Update entry:**
```
PUT /api/v1/admin/config/{key}
Authorization: Bearer <token>
Content-Type: application/json

{
  "value": "false",
  "type": "boolean"  // optional
}
```

**Delete entry:**
```
DELETE /api/v1/admin/config/{key}
Authorization: Bearer <token>
```

### Adding New Config Values

1. Use admin endpoint to create entry, OR
2. Add to seed migration in `ConfigMigrations.swift`:
```swift
static func v1Seed() -> AsyncMigration {
    .init { database in
        let entries = [
            ConfigEntryModel(key: "myNewFlag", value: "true", type: "boolean"),
            ConfigEntryModel(key: "mySetting", value: "42", type: "integer"),
        ]
        for entry in entries { try await entry.create(on: database) }
    }
}
```

## Configuration

**Cache Settings (in ConfigController):**
- Cache key: `config:all`
- TTL: 300 seconds (5 minutes)

**Supported Types:**
| Type | Storage | Example |
|------|---------|---------|
| `boolean` | `"true"` / `"false"` | Feature flags |
| `integer` | `"42"` | Numeric settings |
| `string` | `"value"` | Text settings |
| `json` | `"{...}"` | Complex objects |

**Database Table:** `config_entries`
| Column | Type | Description |
|--------|------|-------------|
| id | UUID | Primary key |
| config_key | VARCHAR | Unique identifier |
| config_value | TEXT | Value as string |
| config_type | VARCHAR | Type hint |
| created_at | TIMESTAMP | Creation time |
| updated_at | TIMESTAMP | Last update time |

## Notes

### Cache Behavior

- Public endpoint always checks Redis first
- Cache is automatically refreshed on miss
- Any admin write operation (create/update/delete) invalidates the entire cache
- Next public request will rebuild cache from database

### Type Safety

The `type` field provides hints for client-side parsing but values are always stored as strings. The `AnyCodable` wrapper handles proper JSON serialization for the public response.

### Testing

The module includes comprehensive tests:
- `ConfigPublicEndpointTests`: Public access, no-auth verification, versioning
- `ConfigAdminEndpointTests`: CRUD operations, auth requirements, validation
- `ConfigCachingTests`: Cache hit/miss behavior, invalidation

### Extending the System

To add category-based config grouping:
1. Add `category` field to `ConfigEntryModel`
2. Update seed migration with categories
3. Modify response DTO to group by category
4. Update cache key if per-category caching needed
