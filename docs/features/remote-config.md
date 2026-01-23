# Remote Configuration Feature

**Date:** 2026-01-23
**Related Files:** `Sources/App/Modules/RemoteConfig/`

## Overview

The Remote Configuration feature provides a centralized system for managing feature flags and application settings that mobile apps can fetch without requiring app updates. It implements a public read endpoint with Redis caching and admin-protected write endpoints with PostgreSQL persistence.

## What Was Built

- **Public GET endpoint** (`/api/v1/config`) for mobile apps to fetch configuration
- **Admin CRUD endpoints** for managing configuration entries (POST, PATCH, DELETE)
- **Redis caching layer** with 5-minute TTL for performance
- **Typed configuration values** supporting boolean, integer, and string types
- **Category-based organization** into feature flags and settings

## Technical Implementation

### Key Files

- `RemoteConfigModule.swift`: Module registration and migration setup
- `RemoteConfigRouter.swift`: Route definitions with OpenAPI documentation
- `RemoteConfigController.swift`: Request handlers with cache integration
- `RemoteConfigModel.swift`: Database model with enums for valueType and category
- `RemoteConfigCacheService.swift`: Redis cache wrapper with TTL management
- `RemoteConfigRepository.swift`: Database access layer with soft delete support

### Key Patterns

- **Cache-Aside Pattern**: The GET endpoint checks Redis cache first, falls back to PostgreSQL on miss, and caches the result. All write operations invalidate the cache.

- **Category-Based Grouping**: Values are stored flat in PostgreSQL but grouped by category (`featureFlag`, `setting`) in the API response for client convenience.

- **Value Type Validation**: Values are stored as strings in the database but validated against their declared type (boolean, integer, string) on create/update.

- **Admin Middleware Stack**: Write endpoints use `UserAccountModel.guard()` + `EnsureAdminUserMiddleware()` for authentication and authorization.

### Code Examples

**Fetching configuration (public):**
```swift
// GET /api/v1/config returns:
{
  "featureFlags": {
    "enablePaywall": true,
    "showBetaFeatures": false
  },
  "settings": {
    "maxRetries": 3,
    "apiTimeout": 30
  }
}
```

**Creating a config entry (admin):**
```swift
// POST /api/v1/config
{
  "key": "enablePaywall",
  "value": "true",
  "valueType": "boolean",
  "category": "featureFlag"
}
```

**Cache service usage:**
```swift
// Check cache first
if let cached = await req.remoteConfigCache.getCachedConfig() {
    return cached
}

// On miss, fetch from DB and cache
let configs = try await req.services.remoteConfig.all()
let response = transformToResponse(configs)
await req.remoteConfigCache.setCachedConfig(response)
```

## How to Use

1. **Register the module** in `Application-Setup.swift`:
   ```swift
   app.use(RemoteConfigModule())
   ```

2. **Register the repository** in `Application-Setup.swift`:
   ```swift
   app.remoteConfigRepository = DatabaseRemoteConfigRepository(database: app.db)
   ```

3. **Fetch config from mobile app**: Call `GET /api/v1/config` (no auth required)

4. **Manage config as admin**: Use POST/PATCH/DELETE with admin bearer token

## Configuration

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| Cache TTL | TimeInterval | 300 (5 min) | `RemoteConfigCacheService.cacheTTL` |
| Cache Key | String | `remote_config:all` | `RemoteConfigCacheService.cacheKey` |

## Notes

- **Single cache key strategy**: All configuration is cached as one response. This is efficient for small-to-medium config sets. For large sets, consider per-category caching.
- **Soft deletes**: Deleted configs are retained with `deletedAt` timestamp, not hard deleted.
- **Value storage**: All values are stored as strings; type conversion happens at response time.
- **Unique keys**: Configuration keys must be unique across all categories (enforced by database constraint).
