# Remote Configuration Module

**Date:** 2026-01-22
**Related Files:** RemoteConfigController.swift, RemoteConfigRouter.swift, RemoteConfigRepository.swift, RemoteConfig+Model.swift

## Overview

The Remote Configuration module provides a server-side feature flag and settings system for mobile clients. It enables toggling features and updating app behavior without requiring app store updates. The system uses a cache-first strategy with Redis and gracefully falls back to PostgreSQL when the cache is unavailable.

## What Was Built

- Public endpoint `GET /api/v1/config` for mobile clients (no auth required)
- Admin CRUD endpoints `POST/GET/PATCH/DELETE /api/v1/admin/config` with auth + admin role
- Cache-first architecture with 5-minute TTL and automatic database fallback
- Value type system supporting boolean, integer, string, and JSON values
- Automatic cache invalidation on config mutations
- Response structure separating booleans into `featureFlags` and other types into `settings`

## Technical Implementation

### Key Files

- `Sources/App/Modules/RemoteConfig/RemoteConfigController.swift`: Business logic with cache-first pattern and value type validation
- `Sources/App/Modules/RemoteConfig/RemoteConfigRouter.swift`: Route definitions with OpenAPI documentation
- `Sources/App/Modules/RemoteConfig/Repositories/RemoteConfigRepository.swift`: Database access layer
- `Sources/App/Modules/RemoteConfig/Models/RemoteConfig+Model.swift`: DTOs and AnyCodable wrapper for heterogeneous JSON
- `Sources/App/Modules/RemoteConfig/Database/Models/RemoteConfigEntryModel.swift`: Fluent database model

### Key Patterns

**Cache-First with Database Fallback:**

The public endpoint implements a resilient cache-first pattern:

```swift
func getPublicConfig(_ req: Request) async throws -> RemoteConfig.Public.Response {
    // Try cache first
    do {
        if let cached = try await req.services.cache.get(Self.publicConfigCacheKey, ...) {
            return cached
        }
    } catch {
        // Log warning but don't fail - fallback to database
        req.logger.warning("Cache get failed, falling back to database")
    }

    // Fetch from database
    let entries = try await req.repositories.remoteConfig.findAll()
    let response = buildPublicResponse(from: entries)

    // Try to cache (non-blocking failure)
    do {
        try await req.services.cache.set(Self.publicConfigCacheKey, value: response, ttl: 300)
    } catch {
        req.logger.warning("Cache set failed")
    }

    return response
}
```

**Value Type Separation:**

Boolean values are automatically separated into `featureFlags` while other types go into `settings`:

```swift
private func buildPublicResponse(from entries: [RemoteConfigEntryModel]) -> RemoteConfig.Public.Response {
    var featureFlags: [String: Bool] = [:]
    var settings: [String: AnyCodable] = [:]

    for entry in entries {
        if entry.valueType == RemoteConfig.ValueType.boolean.rawValue {
            featureFlags[entry.key] = entry.value.lowercased() == "true"
        } else {
            settings[entry.key] = parseValue(entry.value, type: entry.valueType)
        }
    }
    return RemoteConfig.Public.Response(featureFlags: featureFlags, settings: settings, version: Date())
}
```

**Cache Invalidation on Mutation:**

All admin mutations automatically invalidate the public cache:

```swift
// In createEntry, updateEntry, deleteEntry:
await invalidatePublicCache(req)

private func invalidatePublicCache(_ req: Request) async {
    do {
        try await req.services.cache.delete(Self.publicConfigCacheKey)
    } catch {
        req.logger.warning("Failed to invalidate cache")  // Non-blocking
    }
}
```

**Value Type Validation:**

Values are validated against their declared type before storage:

```swift
private func validateValue(_ value: String, for type: RemoteConfig.ValueType) throws {
    switch type {
    case .boolean:
        guard ["true", "false", "1", "0"].contains(value.lowercased()) else {
            throw Abort(.badRequest, reason: "Invalid boolean value")
        }
    case .integer:
        guard Int(value) != nil else {
            throw Abort(.badRequest, reason: "Invalid integer value")
        }
    case .json:
        guard let data = value.data(using: .utf8),
              (try? JSONSerialization.jsonObject(with: data)) != nil else {
            throw Abort(.badRequest, reason: "Invalid JSON value")
        }
    case .string:
        break  // All strings valid
    }
}
```

## How to Use

### For Mobile App Integration

1. **Fetch configuration on app launch:**
   ```
   GET /api/v1/config
   ```

2. **Parse the response:**
   ```json
   {
     "featureFlags": {
       "darkModeEnabled": true,
       "newOnboardingFlow": false
     },
     "settings": {
       "maxUploadSizeMB": 50,
       "welcomeMessage": "Hello!",
       "themeConfig": {"primary": "#007AFF"}
     },
     "version": "2026-01-22T10:30:00Z"
   }
   ```

3. **Cache locally and refresh periodically** (server caches for 5 minutes)

### For Admin Configuration Management

1. **Create a new feature flag:**
   ```
   POST /api/v1/admin/config
   Authorization: Bearer <admin-token>

   {
     "key": "darkModeEnabled",
     "value": "true",
     "valueType": "boolean",
     "description": "Enable dark mode UI"
   }
   ```

2. **Update an existing config:**
   ```
   PATCH /api/v1/admin/config/darkModeEnabled
   Authorization: Bearer <admin-token>

   {
     "value": "false"
   }
   ```

3. **Delete a config entry:**
   ```
   DELETE /api/v1/admin/config/darkModeEnabled
   Authorization: Bearer <admin-token>
   ```

4. **List all entries:**
   ```
   GET /api/v1/admin/config
   Authorization: Bearer <admin-token>
   ```

### Key Naming Convention

Config keys must follow the pattern: `^[a-zA-Z][a-zA-Z0-9_]*$`
- Start with a letter
- Contain only letters, numbers, and underscores
- Maximum 128 characters

## Configuration

| Setting | Value | Description |
|---------|-------|-------------|
| Cache Key | `remote_config:public` | Redis key for cached public response |
| Cache TTL | 300 seconds (5 minutes) | How long responses are cached |
| Database Table | `remote_config_entries` | PostgreSQL table name |

No environment variables required - caching uses the existing Redis service.

## Notes

### Why Separate featureFlags from settings?

Mobile clients typically handle boolean feature flags differently from other configuration:
- Feature flags are used for conditional UI/logic (`if featureFlags.darkModeEnabled`)
- Settings are type-diverse and used for values (`settings.maxUploadSizeMB`)

Separating them in the response makes client-side consumption cleaner.

### Cache Strategy Rationale

- **5-minute TTL**: Balances freshness with performance. Config changes take up to 5 minutes to propagate.
- **Non-blocking cache failures**: If Redis is down, requests still succeed via database fallback.
- **Immediate invalidation**: Admin mutations invalidate cache immediately for faster propagation.

### Value Storage

All values are stored as strings in the database with a `value_type` discriminator. This simplifies the schema while supporting heterogeneous types. Parsing happens at read time.

### AnyCodable Pattern

The `AnyCodable` wrapper enables heterogeneous JSON serialization for the `settings` dictionary, supporting mixed types (integers, strings, nested objects) in a single Codable response.

### Testing

Integration tests cover:
- Public endpoint with empty config
- Public endpoint with mixed value types
- Feature flag separation logic
- Admin CRUD operations
- Auth and admin role requirements
- Cache invalidation behavior

Test files:
- `Tests/AppTests/Tests/ControllerTests/RemoteConfigTests/RemoteConfigPublicTests.swift`
- `Tests/AppTests/Tests/ControllerTests/RemoteConfigTests/RemoteConfigAdminTests.swift`
