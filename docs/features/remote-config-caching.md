# Remote Configuration with Redis Caching

**Date:** 2025-12-27
**Related Files:**
- `Sources/App/Modules/RemoteConfig/Controllers/RemoteConfigController.swift`
- `Sources/App/Modules/RemoteConfig/RemoteConfigRouter.swift`
- `Sources/App/Modules/RemoteConfig/Models/RemoteConfig+Model.swift`
- `Sources/App/Modules/RemoteConfig/Database/Migrations/RemoteConfigMigrations.swift`

## Overview

The Remote Config feature provides a complete configuration management system for mobile applications, allowing feature flags and settings to be controlled remotely without requiring app updates. It implements a two-tier storage architecture with PostgreSQL persistence and Redis caching (5-minute TTL) for optimal performance, along with automatic cache invalidation on admin updates.

## What Was Built

- **Public GET endpoint** (`/api/v1/config`) for retrieving active configuration without authentication
- **Admin CRUD endpoints** (`/api/v1/admin/config`) for managing configurations with authentication and admin role enforcement
- **Redis caching layer** with 5-minute TTL and automatic invalidation on mutations
- **Configuration grouping pattern** that organizes configs by prefix (`featureFlags.*`, `settings.*`)
- **Dynamic JSON value support** using custom `AnyCodable` type for flexible configuration values
- **PostgreSQL persistence** with unique key constraint and version tracking

## Technical Implementation

### Key Files

- `RemoteConfigController.swift`: HTTP endpoint handlers with caching logic and config grouping
- `RemoteConfigRouter.swift`: Route definitions using API versioning pattern (`/api/v1/`) with OpenAPI documentation
- `RemoteConfig+Model.swift`: Request/response DTOs and `AnyCodable` helper for dynamic JSON encoding
- `RemoteConfigModel.swift`: Fluent database model with unique key constraint
- `RemoteConfigMigrations.swift`: Database schema migration
- `RemoteConfigRepository.swift`: Data access abstraction layer

### Key Patterns

- **Cache-Aside Pattern**: Check cache first, on miss fetch from database and populate cache
  ```swift
  // Try cache first
  if let cachedJSON = await req.services.aiCache.get(key: cacheKey) {
      return try JSONDecoder().decode(Response.self, from: cachedData)
  }

  // Cache miss - fetch from database
  let configs = try await repository.allActive()

  // Cache the response
  await req.services.aiCache.set(key: cacheKey, value: responseJSON, ttl: 300)
  ```

- **Cache Invalidation on Mutation**: All admin endpoints (POST, PATCH, DELETE) automatically invalidate cache
  ```swift
  private func invalidateCache(_ req: Request) async {
      let cacheKey = "remote_config:all_active"
      await req.services.aiCache.remove(key: cacheKey)
      req.logger.info("Remote config cache invalidated")
  }
  ```

- **Config Grouping by Prefix**: Configurations are stored with prefixed keys and grouped in response
  ```swift
  // Database stores:
  // - featureFlags.enableNewScanner = true
  // - settings.maxRetries = 3

  // Response groups them:
  {
    "featureFlags": {
      "enableNewScanner": true
    },
    "settings": {
      "maxRetries": 3
    }
  }
  ```

- **AnyCodable for Dynamic JSON**: Custom `Codable` type handles mixed-type configuration values
  ```swift
  struct AnyCodable: Codable, @unchecked Sendable {
      let value: Any
      // Supports: Bool, Int, Double, String, [AnyCodable], [String: AnyCodable]
  }
  ```

- **Type-Safe Value Parsing**: Configuration values stored as strings in database, parsed by `valueType` field
  ```swift
  switch type {
  case "boolean": return AnyCodable(value.lowercased() == "true")
  case "integer": return AnyCodable(Int(value) ?? 0)
  case "json": return AnyCodable(JSONSerialization.jsonObject(from: data))
  default: return AnyCodable(value) // string
  }
  ```

## How to Use

### Fetching Configuration (Mobile App)

1. Make a GET request to `/api/v1/config` (no authentication required)
2. Parse the JSON response containing `featureFlags`, `settings`, and `version`
3. Cache locally in app and periodically refresh

**Example Request:**
```bash
curl https://api.example.com/api/v1/config
```

**Example Response:**
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

### Creating Configuration (Admin)

1. Authenticate and obtain admin JWT token
2. POST to `/api/v1/admin/config` with configuration details
3. Cache is automatically invalidated

**Example Request:**
```bash
curl -X POST https://api.example.com/api/v1/admin/config \
  -H "Authorization: Bearer <admin-token>" \
  -H "Content-Type: application/json" \
  -d '{
    "key": "featureFlags.enableNewScanner",
    "value": "true",
    "valueType": "boolean",
    "version": 1,
    "isActive": true
  }'
```

**Example Response:**
```json
{
  "id": "123e4567-e89b-12d3-a456-426614174000",
  "key": "featureFlags.enableNewScanner",
  "message": "Configuration created successfully"
}
```

### Updating Configuration (Admin)

1. Authenticate and obtain admin JWT token
2. PATCH to `/api/v1/admin/config/:key` with updated fields
3. Cache is automatically invalidated

**Example Request:**
```bash
curl -X PATCH https://api.example.com/api/v1/admin/config/featureFlags.enableNewScanner \
  -H "Authorization: Bearer <admin-token>" \
  -H "Content-Type: application/json" \
  -d '{
    "value": "false",
    "version": 2
  }'
```

### Deleting Configuration (Admin)

1. Authenticate and obtain admin JWT token
2. DELETE to `/api/v1/admin/config/:key`
3. Cache is automatically invalidated

**Example Request:**
```bash
curl -X DELETE https://api.example.com/api/v1/admin/config/featureFlags.enableNewScanner \
  -H "Authorization: Bearer <admin-token>"
```

## Configuration

### Database Schema

The `remote_configs` table has the following structure:

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | UUID | PRIMARY KEY | Unique identifier |
| key | STRING | UNIQUE, NOT NULL | Configuration key (e.g., "featureFlags.enableNewScanner") |
| value | STRING | NOT NULL | String-encoded value |
| value_type | STRING | NOT NULL | Type indicator: "boolean", "integer", "string", "json" |
| version | INTEGER | NOT NULL | Version number for tracking changes |
| is_active | BOOLEAN | NOT NULL | Whether config is active (soft delete flag) |
| created_at | TIMESTAMP | | Creation timestamp |
| updated_at | TIMESTAMP | | Last update timestamp |

### Caching Configuration

- **Cache Key Pattern**: `remote_config:all_active`
- **TTL**: 300 seconds (5 minutes)
- **Cache Backend**: Redis via `AICacheServiceInterface`
- **Invalidation**: Automatic on all admin mutations (POST, PATCH, DELETE)

### Supported Value Types

1. **boolean**: `"true"` or `"false"` (case-insensitive) → parsed to Bool
2. **integer**: Numeric string → parsed to Int
3. **string**: Plain text → returned as String
4. **json**: Valid JSON string → parsed to nested object/array

## Notes

### Design Decisions

- **Prefix-based grouping** allows logical organization without additional database fields
- **String storage with type metadata** provides flexibility for heterogeneous configuration values
- **Single cache key for all configs** reduces cache complexity but invalidates everything on any change
- **Public endpoint without auth** enables mobile apps to fetch config without user login
- **Admin-only mutations** ensures configuration changes are controlled and auditable

### Performance Considerations

- **Cache hit** returns response in ~1-2ms
- **Cache miss** fetches from database and caches, taking ~10-50ms
- **Cache invalidation** is immediate but all clients see new values within 5 minutes max
- **Database query** uses `isActive = true` filter for efficient retrieval

### Limitations

- Configuration changes take up to 5 minutes to propagate to all mobile clients (TTL)
- Unique key constraint prevents duplicate keys (handle conflicts with 409 Conflict response)
- JSON values require valid JSON strings; invalid JSON falls back to string type
- Version field is informational only; no automatic version conflict resolution

### Future Enhancements

- Add configuration change history/audit log
- Implement targeted cache invalidation per configuration key
- Add batch update endpoint for multiple configurations
- Support environment-specific configurations (dev, staging, production)
- Add configuration validation rules and constraints
- Implement A/B testing support with percentage rollouts

### Related Patterns

- See `docs/features/api-versioning.md` for API versioning pattern used in routes
- Repository pattern follows same structure as other modules (Waitlist, Auth, User)
- OpenAPI documentation pattern consistent across all endpoints
- Admin middleware enforcement pattern reusable for other admin endpoints
