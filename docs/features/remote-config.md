# Remote Configuration System

**Date:** 2025-12-27
**Related Files:** Sources/App/Modules/RemoteConfig/*, Sources/App/Services/ConfigCache/*

## Overview

A complete remote configuration management system that enables mobile apps to fetch feature flags and settings without requiring app updates. The system includes admin endpoints for managing configuration, Redis caching for performance, and support for multiple value types (boolean, integer, string, JSON).

## What Was Built

- Public GET endpoint (`/api/v1/config`) for mobile apps to fetch configuration
- Admin endpoints for creating, updating, listing, and deleting configuration entries
- Redis caching layer with 5-minute TTL for performance optimization
- Multi-type configuration storage supporting boolean, integer, string, and JSON values
- Key naming convention system for organizing feature flags and settings
- Repository pattern for database abstraction
- Service pattern for caching abstraction

## Technical Implementation

### Key Files

- `Sources/App/Modules/RemoteConfig/RemoteConfigModule.swift`: Module registration and boot configuration
- `Sources/App/Modules/RemoteConfig/RemoteConfigRouter.swift`: Route definitions with `/api/v1/config` prefix
- `Sources/App/Modules/RemoteConfig/Controller/RemoteConfigController.swift`: Business logic for public and admin endpoints
- `Sources/App/Modules/RemoteConfig/Models/RemoteConfig+Model.swift`: Request/Response DTOs and value types
- `Sources/App/Modules/RemoteConfig/Database/Models/ConfigEntryModel.swift`: Fluent model for PostgreSQL storage
- `Sources/App/Modules/RemoteConfig/Database/Migrations/RemoteConfigMigrations.swift`: Database schema migration
- `Sources/App/Modules/RemoteConfig/Repositories/RemoteConfigRepository.swift`: Data access abstraction layer
- `Sources/App/Services/ConfigCache/ConfigCacheService.swift`: Redis caching service with protocol-first design

### Key Patterns

**Key Naming Convention:**
- Keys prefixed with `feature_*` are transformed into the `featureFlags` dictionary (boolean values only)
- Keys prefixed with `setting_*` are transformed into the `settings` dictionary (any value type)
- Special key `api_version` is mapped to the top-level `version` field
- Example database keys: `feature_enableNewScanner`, `setting_maxRetries`, `api_version`

**Response Transformation:**
The controller transforms flat database rows into a structured nested response:
```swift
// Database: flat rows with typed columns
ConfigEntryModel(key: "feature_enableNewScanner", valueType: "boolean", boolValue: true)
ConfigEntryModel(key: "setting_maxRetries", valueType: "integer", intValue: 3)

// Response: nested structure
{
  "featureFlags": {
    "enableNewScanner": true
  },
  "settings": {
    "maxRetries": 3
  },
  "version": "1.0.0"
}
```

**Multi-Type Storage Pattern:**
Each config entry has four nullable value columns (`bool_value`, `int_value`, `string_value`, `json_value`), with only one populated based on `value_type`. This maintains type safety while avoiding JSON blob storage.

**Caching Strategy:**
- Public endpoint checks Redis cache first (`config:all` key)
- On cache miss, fetches from PostgreSQL and populates cache
- Admin mutations automatically invalidate cache
- 5-minute TTL for automatic cache refresh
- Cache failures log errors but don't break endpoints (graceful degradation)

**Protocol-First Service Design:**
Both the cache service and repository use protocols (`ConfigCacheServiceProtocol`, `RemoteConfigRepositoryProtocol`) for dependency injection and testing isolation. Extensions on `Application` and `Request` provide convenient access.

## How to Use

### Fetching Configuration (Mobile App)

**Endpoint:** `GET /api/v1/config`

**No authentication required** - this is a public endpoint.

```swift
// Example response
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

### Managing Configuration (Admin)

**Create or Update Config Entry:**
```bash
POST /api/v1/config/admin
Authorization: Bearer <admin-jwt-token>
Content-Type: application/json

{
  "key": "feature_enableNewScanner",
  "valueType": "boolean",
  "value": true
}
```

**List All Config Entries:**
```bash
GET /api/v1/config/admin
Authorization: Bearer <admin-jwt-token>
```

**Delete Config Entry:**
```bash
DELETE /api/v1/config/admin/:key
Authorization: Bearer <admin-jwt-token>
```

### Adding New Configuration Values

1. Decide on key naming:
   - For feature flags (boolean): Use `feature_` prefix (e.g., `feature_darkMode`)
   - For settings (any type): Use `setting_` prefix (e.g., `setting_apiTimeout`)
   - For API version: Use `api_version` key

2. Use admin endpoint to create the config entry with appropriate `valueType`

3. Mobile app will receive the value on next fetch (or immediately if cache is invalidated)

### Implementing Similar Caching

When adding Redis caching to other endpoints, follow this pattern:

```swift
// 1. Define protocol
protocol YourCacheServiceProtocol: Sendable {
    func get() async throws -> YourType?
    func set(_ value: YourType) async throws
    func invalidate() async throws
}

// 2. Implement with Redis
final class RedisYourCacheService: YourCacheServiceProtocol {
    private let redis: RedisClient
    private let ttl: TimeInterval = 300

    func get() async throws -> YourType? {
        let data = try await redis.get(RedisKey("your:key"), as: Data.self).get()
        // Decode and return, or return nil on cache miss
    }

    func set(_ value: YourType) async throws {
        let data = try JSONEncoder().encode(value)
        try await redis.setex(RedisKey("your:key"), to: data, expirationInSeconds: Int(ttl)).get()
    }

    func invalidate() async throws {
        _ = try await redis.delete([RedisKey("your:key")]).get()
    }
}

// 3. Register in Application
extension Application {
    var yourCacheService: YourCacheServiceProtocol {
        get { storage[YourCacheKey.self]! }
        set { storage[YourCacheKey.self] = newValue }
    }
}

// 4. Use in controller
if let cached = try await req.yourCacheService.get() {
    return cached
}
let fresh = try await fetchFromDatabase()
try await req.yourCacheService.set(fresh)
return fresh
```

## Configuration

### Environment Variables

- `REDIS_URL`: Redis connection string (required for caching)
  - Example: `redis://localhost:6379`
  - Production: Use Redis instance URL from hosting provider

### Database

- Table: `config_entries`
- Migration: Automatically runs on application boot
- Indexed on `key` field for fast lookups

### Cache Settings

- **TTL:** 5 minutes (300 seconds)
- **Cache Key:** `config:all`
- **Eviction:** Automatic on TTL expiration
- **Invalidation:** Manual on admin updates

### Rate Limiting

Consider adding rate limiting to the admin endpoints in production:
```swift
let rateLimited = admin.grouped(RateLimitMiddleware(requestsPerMinute: 60))
rateLimited.post(use: controller.createOrUpdateConfig)
```

## Notes

### Security Considerations

- **Public endpoint:** The GET endpoint is intentionally public and does not require authentication. Only store non-sensitive configuration values.
- **Admin endpoints:** Protected with JWT authentication. Only admin users can modify configuration.
- **Sensitive data:** Do not store API keys, passwords, or other secrets in this system. Use environment variables for sensitive configuration.

### Performance Characteristics

- **Cached response:** < 10ms (Redis)
- **Cache miss:** < 50ms (PostgreSQL query + cache write)
- **Cache invalidation:** Immediate (synchronous)

### Limitations

- **Type restrictions:** Feature flags (keys starting with `feature_`) must be boolean values
- **Key format:** Keys are case-sensitive and should follow naming convention
- **Cache granularity:** Entire config is cached as a single unit (no per-key caching)

### Future Enhancements

- **Versioning:** Add support for config versioning to track changes over time
- **A/B Testing:** Extend to support user-segmented config values
- **Schema Validation:** Add JSON schema validation for JSON-type values
- **Audit Logging:** Track who changed what configuration and when
- **Config Sync:** Webhook or push notification when config changes

### Related Documentation

- `docs/features/api-versioning.md`: All endpoints follow the `/api/v1/` prefix pattern established in Story 1.1
- Project architecture patterns for modules, services, and repositories

### Testing

Integration tests cover:
- Public endpoint returns correct structure
- Cache hit and miss scenarios
- Admin CRUD operations
- Authentication requirements
- Type validation and error handling

See `Tests/AppTests/Tests/ControllerTests/RemoteConfigTests/` for examples.
