# Remote Configuration System

**Date:** 2026-01-22
**Related Files:** `Sources/App/Modules/RemoteConfig/`

## Overview

The Remote Configuration system enables mobile apps to fetch feature flags and settings from the backend without requiring app updates. It provides a public endpoint for reading configuration and admin-protected endpoints for managing configuration values, with Redis caching for performance.

## What Was Built

- **Public GET endpoint** (`/api/v1/config`) - Returns all configuration grouped by category (featureFlags, settings)
- **Admin CRUD endpoints** - POST, PATCH, DELETE operations requiring admin authentication
- **Redis caching** - Cache-aside pattern with 5-minute TTL for performance optimization
- **Typed values** - Support for boolean, integer, and string configuration values
- **PostgreSQL persistence** - Database model with migrations and seed data

## Technical Implementation

### Key Files

- `Sources/App/Modules/RemoteConfig/RemoteConfigModule.swift`: Module registration and migration setup
- `Sources/App/Modules/RemoteConfig/RemoteConfigRouter.swift`: Route definitions with OpenAPI documentation
- `Sources/App/Modules/RemoteConfig/Controllers/RemoteConfigController.swift`: Request handling and caching logic
- `Sources/App/Modules/RemoteConfig/Repositories/RemoteConfigRepository.swift`: Database operations
- `Sources/App/Modules/RemoteConfig/Database/Models/RemoteConfigModel.swift`: Database model with enums
- `Sources/App/Entities/RemoteConfig/RemoteConfig.swift`: Request/Response DTOs and AnyCodableValue type

### Key Patterns

- **Cache-Aside Pattern**: The controller checks Redis cache first, falls back to database on miss, and caches the result. Cache is invalidated on any mutation (create/update/delete).

- **Repository Pattern**: Database operations are abstracted through `RemoteConfigRepository` protocol, enabling test mocking via `TestRemoteConfigRepository`.

- **Module Structure**: Follows the established pattern of Module → Router → Controller → Repository → Model, making it easy to add new modules.

- **Typed Value Handling**: Uses `AnyCodableValue` enum to serialize/deserialize typed values (boolean/integer/string) in JSON responses.

### Code Examples

**Fetching config (public endpoint):**
```bash
curl -X GET http://localhost:8080/api/v1/config
```

Response:
```json
{
  "feature_flags": {
    "enablePaywall": true
  },
  "settings": {
    "maxRetries": 3
  }
}
```

**Creating a config entry (admin only):**
```bash
curl -X POST http://localhost:8080/api/v1/config \
  -H "Authorization: Bearer <admin-token>" \
  -H "Content-Type: application/json" \
  -d '{
    "key": "newFeature",
    "value": "true",
    "value_type": "boolean",
    "category": "feature_flags"
  }'
```

## How to Use

1. **Reading configuration (mobile apps)**: Make a GET request to `/api/v1/config` without authentication
2. **Creating entries (admins)**: POST to `/api/v1/config` with key, value, value_type, and category
3. **Updating entries (admins)**: PATCH to `/api/v1/config/:key` with the new value
4. **Deleting entries (admins)**: DELETE to `/api/v1/config/:key`

## Configuration

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| Cache Key | String | `remoteConfig:all` | Redis key for cached config response |
| Cache TTL | Integer | 300 (5 min) | Time-to-live for cached config in seconds |

### Value Types

| Type | Valid Values | Example |
|------|-------------|---------|
| `boolean` | `"true"`, `"false"` | `{"value": "true", "value_type": "boolean"}` |
| `integer` | Any parseable integer | `{"value": "42", "value_type": "integer"}` |
| `string` | Any string | `{"value": "hello", "value_type": "string"}` |

### Categories

| Category | Purpose |
|----------|---------|
| `feature_flags` | Boolean flags controlling feature visibility |
| `settings` | Configuration values (integers, strings) |

## Notes

- The GET endpoint is **intentionally public** - mobile apps need config without authentication
- Cache is invalidated immediately on any mutation to ensure consistency
- Keys must be alphanumeric with underscores/hyphens only (URL-safe)
- The seed migration only runs in development environment
- Duplicate key creation is rejected with 409 Conflict (handles race conditions)
