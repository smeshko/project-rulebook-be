# Remote Configuration Endpoint

**Date:** 2026-01-22
**Related Files:** `Sources/App/Modules/RemoteConfig/`

## Overview

Remote configuration allows mobile apps to fetch feature flags and settings from the backend, enabling app behavior to be controlled remotely without requiring app updates. This module provides a public endpoint for apps to fetch config values and admin endpoints for managing configuration entries.

## What Was Built

- **Public GET endpoint** (`/api/v1/config`) - Returns grouped configuration (feature flags + settings)
- **Admin CRUD endpoints** - Create, read, update, delete config entries (requires admin authentication)
- **Redis caching** - 5-minute TTL with automatic invalidation on writes
- **Typed values** - Support for boolean, integer, and string configuration values

## Technical Implementation

### Key Files

- `RemoteConfigController.swift`: Main controller with public and admin endpoint handlers
- `RemoteConfigRouter.swift`: Route registration with authentication middleware
- `RemoteConfigModel.swift`: Database model with typed value support
- `RemoteConfig+Model.swift`: Request/response DTOs and `AnyCodableValue` type
- `RemoteConfigRepository.swift`: Repository pattern implementation

### Key Patterns

- **Public + Admin Endpoint Separation**: The router registers the public GET endpoint without authentication, then creates a grouped route with `UserAccountModel.guard()` and `EnsureAdminUserMiddleware()` for admin-only operations.

- **Redis Caching with Write-Through Invalidation**: The public endpoint checks Redis cache first. On cache miss, it fetches from database and caches with 5-minute TTL. All write operations (POST, PATCH, DELETE) invalidate the cache.

- **Typed Value Storage**: Values are stored as strings in the database with a `valueType` enum (boolean/integer/string). The controller transforms these to proper JSON types in the response.

- **Key Naming Convention**: Config keys use dot notation for categorization: `featureFlags.enablePaywall` or `settings.maxRetries`. The controller parses these to group values in the response.

### Code Examples

**Adding a new config entry (admin):**
```bash
curl -X POST /api/v1/config \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"key": "featureFlags.newFeature", "value": "true", "valueType": "boolean"}'
```

**Fetching config (public):**
```bash
curl /api/v1/config
# Returns:
# {
#   "featureFlags": {"enablePaywall": true},
#   "settings": {"maxRetries": 3}
# }
```

**Creating config entries in code:**
```swift
// Boolean feature flag
let flag = RemoteConfigModel.create(key: "featureFlags.darkMode", boolValue: true)

// Integer setting
let setting = RemoteConfigModel.create(key: "settings.timeout", intValue: 30)

// String setting
let apiUrl = RemoteConfigModel.create(key: "settings.apiUrl", stringValue: "https://api.example.com")
```

## How to Use

1. **For mobile apps**: Call `GET /api/v1/config` (no authentication required) to fetch all feature flags and settings as a single JSON response.

2. **For admin management**: Use the admin endpoints with a valid admin JWT token:
   - `POST /api/v1/config` - Create a new config entry
   - `PATCH /api/v1/config/:key` - Update an existing entry
   - `DELETE /api/v1/config/:key` - Delete an entry
   - `GET /api/v1/config/admin` - List all entries with metadata

3. **Key naming**: Use `featureFlags.` prefix for boolean flags and `settings.` prefix for other values to ensure proper grouping in the response.

## Configuration

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| Cache TTL | TimeInterval | 300 (5 min) | How long config is cached in Redis |
| Cache Key | String | `remote_config_all` | Redis key for cached response |

Cache TTL is defined in `RemoteConfigController.cacheTTL`. To modify, update the constant in the controller.

## Notes

- The public endpoint does NOT require authentication - this is intentional for mobile app accessibility
- Cache is automatically invalidated on any write operation, so changes are immediately visible
- Values are stored as strings internally but transformed to proper JSON types (boolean, integer, string) in the response
- The `AnyCodableValue` enum handles type-erased encoding/decoding for mixed-type settings
