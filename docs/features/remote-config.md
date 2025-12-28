# Remote Configuration System

**Date:** 2025-12-28
**Related Files:** `Sources/App/Modules/Config/*`

## Overview

A remote configuration system that allows mobile apps to fetch feature flags and settings from the backend without requiring app updates. Configuration values are stored in PostgreSQL with Redis caching for performance, and can be updated by administrators through a protected API endpoint.

## What Was Built

- Public endpoint for mobile apps to fetch configuration (`GET /api/v1/config`)
- Admin endpoint for updating configuration (`PUT /api/v1/admin/config`)
- Type-safe configuration values (boolean, integer, string, JSON)
- Redis caching with 5-minute TTL and automatic invalidation
- Database persistence with PostgreSQL

## Technical Implementation

### Key Files

- `Modules/Config/ConfigModule.swift`: Module registration and migration setup
- `Modules/Config/ConfigRouter.swift`: Route definitions for public and admin endpoints
- `Modules/Config/Controller/ConfigController.swift`: Business logic for config retrieval and updates
- `Modules/Config/Models/Config+Model.swift`: Request/response DTOs and `AnyCodableValue` type
- `Modules/Config/Database/Models/ConfigValueModel.swift`: Fluent database model
- `Modules/Config/Repositories/ConfigRepository.swift`: Data access layer

### Key Patterns

- **Key Naming Convention**: Configuration keys use prefixes to categorize values:
  - `featureFlags.*` for boolean feature toggles (e.g., `featureFlags.enableNewScanner`)
  - `settings.*` for general settings (e.g., `settings.maxRetries`)
  - `version` for config version string

- **AnyCodableValue**: Type-erasing wrapper for JSON-compatible values that handles serialization of mixed types in the settings dictionary

- **Cache-Through Pattern**: The controller first checks Redis cache, falls back to database on miss, and populates cache for subsequent requests

- **Cache Invalidation**: Admin updates immediately delete the cached response, ensuring clients get fresh values

- **Admin Authentication**: Update endpoint uses `EnsureAdminUserMiddleware` to restrict access

## How to Use

### Fetching Configuration (Mobile App)

```http
GET /api/v1/config
```

Response:
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

### Adding New Configuration Values

1. Use the admin endpoint or database migration to insert values:

```json
PUT /api/v1/admin/config
Authorization: Bearer <admin-token>

{
  "items": [
    {
      "key": "featureFlags.newFeature",
      "value": "true",
      "valueType": "boolean"
    },
    {
      "key": "settings.timeout",
      "value": "30",
      "valueType": "integer"
    }
  ]
}
```

2. The key prefix determines where the value appears in the response:
   - `featureFlags.*` → `featureFlags` dictionary
   - `settings.*` → `settings` dictionary

### Value Types

| Type | Description | Example Value |
|------|-------------|---------------|
| `boolean` | True/false flags | `"true"` or `"false"` |
| `integer` | Numeric settings | `"300"` |
| `string` | Text values | `"production"` |
| `json` | Complex objects | `"{\"key\": \"value\"}"` |

## Configuration

### Cache Settings

The cache TTL is configured in `ConfigController.swift`:

```swift
private static let cacheTTL: TimeInterval = 300 // 5 minutes
```

### Redis Cache Key

Config is cached under the key `config:all`.

## Notes

- The public endpoint requires no authentication, making it suitable for app startup configuration
- All values are stored as strings in the database and decoded based on `valueType`
- The `AnyCodableValue` enum provides type-safe JSON serialization for mixed-type settings
- Cache invalidation is immediate on admin updates - no stale data window
- The config version can be used by clients to detect when to refresh their local cache
