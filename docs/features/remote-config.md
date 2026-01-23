# Remote Config Feature

**Date:** 2026-01-24
**Related Files:** `Sources/App/Modules/RemoteConfig/`

## Overview

The Remote Config feature enables mobile apps to fetch feature flags and configuration from the backend, allowing app behavior to be controlled remotely without requiring app updates. It provides a public endpoint for reading configuration and admin-protected endpoints for managing configuration values.

## What Was Built

- Public GET endpoint `/api/v1/config` for retrieving all configuration values
- Admin CRUD endpoints at `/api/v1/config/admin` for managing configuration
- Redis caching with 5-minute TTL and graceful fallback to PostgreSQL
- Typed configuration values (boolean, integer, string)
- Two categories: `featureFlag` and `setting`

## Technical Implementation

### Key Files

- `Sources/App/Modules/RemoteConfig/RemoteConfigModule.swift`: Module registration
- `Sources/App/Modules/RemoteConfig/RemoteConfigRouter.swift`: Route definitions with public/admin separation
- `Sources/App/Modules/RemoteConfig/Controllers/RemoteConfigController.swift`: Request handling with validation
- `Sources/App/Modules/RemoteConfig/Services/RemoteConfigCacheService.swift`: Caching logic with fallback
- `Sources/App/Modules/RemoteConfig/Repositories/RemoteConfigRepository.swift`: Database access
- `Sources/App/Modules/RemoteConfig/Database/Models/RemoteConfigModel.swift`: Database model with enums
- `Sources/App/Entities/RemoteConfig/RemoteConfig.swift`: DTOs for API requests/responses

### Key Patterns

- **Best-Effort Caching**: Redis failures don't break the endpoint - the service falls back to PostgreSQL and logs warnings. This ensures high availability even when Redis is down.

- **Public vs Admin Route Separation**: Public routes have no middleware; admin routes use layered authentication:
  ```swift
  .grouped(UserPayloadAuthenticator())
  .grouped(UserAccountModel.guard())
  .grouped(EnsureAdminUserMiddleware())
  ```

- **Typed Value Validation**: Values are stored as strings but validated against their declared type before persistence:
  ```swift
  private func validateValue(_ value: String, for type: RemoteConfigValueType) throws {
      switch type {
      case .boolean:
          let lowercased = value.lowercased()
          guard lowercased == "true" || lowercased == "false" || value == "1" || value == "0" else {
              throw Abort(.badRequest, reason: "Invalid boolean value")
          }
      case .integer:
          guard Int(value) != nil else {
              throw Abort(.badRequest, reason: "Invalid integer value")
          }
      case .string:
          break // Any string is valid
      }
  }
  ```

- **Type-Erased Response**: The GET response uses `AnyCodableValue` enum to return properly typed JSON values instead of string representations.

### Code Examples

**Fetching config (public):**
```bash
curl -X GET http://localhost:8080/api/v1/config
```

Response:
```json
{
  "featureFlags": {
    "enablePaywall": true
  },
  "settings": {
    "maxRetries": 3
  }
}
```

**Creating a config entry (admin):**
```bash
curl -X POST http://localhost:8080/api/v1/config/admin \
  -H "Authorization: Bearer <admin-token>" \
  -H "Content-Type: application/json" \
  -d '{
    "key": "enablePaywall",
    "value": "true",
    "valueType": "boolean",
    "category": "featureFlag"
  }'
```

## How to Use

1. **Register the module** in `Application-Setup.swift` (already done)
2. **Configure the cache service** in `Application+Services.swift` (already done)
3. **Use the public endpoint** from mobile apps to fetch configuration
4. **Use admin endpoints** to manage configuration values (requires admin user)

## Configuration

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| Cache TTL | TimeInterval | 300 (5 min) | How long config is cached in Redis |
| Cache Key | String | `remote_config:all` | Redis key for cached config |

These values are defined as constants in `RemoteConfigCacheService.swift`.

## Notes

- Cache invalidation happens automatically on any write operation (create, update, delete)
- The system handles race conditions in concurrent creates via database constraints
- Redis failures are logged but don't cause endpoint failures
- All admin endpoints return the updated/created entity for immediate UI feedback
