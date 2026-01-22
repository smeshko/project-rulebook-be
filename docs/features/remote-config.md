# Remote Config Endpoint

**Date:** 2026-01-22
**Related Files:** ConfigModule.swift, ConfigRouter.swift, ConfigController.swift, ConfigRepository.swift, ConfigEntryModel.swift

## Overview

Implemented a remote configuration system that allows mobile apps to fetch feature flags and settings from the backend without requiring app updates. The system uses PostgreSQL for persistence with Redis caching (5-minute TTL) and provides both public read access and admin-only mutation endpoints.

## What Was Built

- Public GET endpoint at `/api/v1/config` for mobile apps to fetch configuration
- Admin-only CRUD endpoints for managing configuration entries
- Redis caching with automatic invalidation on mutations
- Typed configuration values (boolean, integer, string)
- Category-based grouping (featureFlags, settings)

## Technical Implementation

### Key Files

- `Sources/App/Modules/Config/ConfigModule.swift`: Module registration and migration setup
- `Sources/App/Modules/Config/ConfigRouter.swift`: Route definitions with OpenAPI documentation
- `Sources/App/Modules/Config/Controllers/ConfigController.swift`: Business logic with caching
- `Sources/App/Modules/Config/Repositories/ConfigRepository.swift`: Database access layer
- `Sources/App/Modules/Config/Database/Models/ConfigEntryModel.swift`: Fluent model and enums
- `Sources/App/Modules/Config/Database/Migrations/ConfigMigrations.swift`: Database schema
- `Sources/App/Modules/Config/Models/Config+Model.swift`: Request/response DTOs

### Key Patterns

- **Public + Admin Endpoint Separation**: GET is public (no auth), mutations require admin. This pattern uses `UserAccountModel.guard()` combined with `EnsureAdminUserMiddleware()` for admin routes.

- **Cache-Through Strategy**: The controller implements cache-through with automatic invalidation:
  1. Check cache first
  2. On miss, fetch from database
  3. Store in cache with TTL
  4. Invalidate on any mutation (create/update/delete)

- **Typed Value Storage**: Configuration values are stored as JSON strings with a separate `valueType` enum. This avoids complex PostgreSQL JSON operations while maintaining type information for the API response.

- **Single Cache Key**: Uses one cache key (`config:all`) for the entire config structure. Simpler than per-key caching for a small, frequently-read dataset.

### Code Examples

**Fetching config (public endpoint):**

```swift
// GET /api/v1/config
// Response:
{
  "featureFlags": {
    "enablePaywall": true,
    "darkModeEnabled": false
  },
  "settings": {
    "maxRetries": 3,
    "timeoutSeconds": 30
  }
}
```

**Creating a config entry (admin):**

```swift
// POST /api/v1/config
// Headers: Authorization: Bearer <admin-token>
// Body:
{
  "key": "enablePaywall",
  "value": "true",
  "valueType": "boolean",
  "category": "feature_flag"
}
```

**Caching pattern in controller:**

```swift
func getConfig(_ req: Request) async throws -> Config.Get.Response {
    // Try cache first
    if let cached = try await req.services.cache.get(Self.cacheKey, as: Config.Get.Response.self) {
        return cached
    }

    // Cache miss - fetch and cache
    let entries = try await req.repositories.config.all()
    let response = buildConfigResponse(from: entries)
    try await req.services.cache.set(Self.cacheKey, value: response, ttl: Self.cacheTTL)

    return response
}
```

## How to Use

### For Mobile App Integration

1. **Fetch configuration on app launch:**
   ```swift
   // iOS Example
   let url = URL(string: "https://api.example.com/api/v1/config")!
   let (data, _) = try await URLSession.shared.data(from: url)
   let config = try JSONDecoder().decode(ConfigResponse.self, from: data)
   ```

2. **Use feature flags:**
   ```swift
   if config.featureFlags["enablePaywall"] == true {
       // Show paywall
   }
   ```

3. **Cache locally:** Consider caching the response locally with a short TTL to reduce network calls.

### For Adding New Config Entries

1. **Via Admin API:**
   - POST to `/api/v1/config` with admin authentication
   - Provide key, value, valueType (boolean/integer/string), and category (feature_flag/setting)

2. **Value types:**
   - `boolean`: Use "true" or "false" as string values
   - `integer`: Use numeric string values (e.g., "42")
   - `string`: Any string value

3. **Categories:**
   - `feature_flag`: Boolean toggles for enabling/disabling features
   - `setting`: Configuration values like timeouts, limits, etc.

### For Testing

```swift
@Test("Config endpoint returns grouped values")
func testGetConfig() async throws {
    try await app.test(.GET, "api/v1/config") { response in
        #expect(response.status == .ok)
        let config = try response.content.decode(Config.Get.Response.self)
        // Verify featureFlags and settings dictionaries
    }
}
```

## Configuration

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| Cache TTL | TimeInterval | 300 (5 min) | How long config is cached in Redis |
| Cache Key | String | "config:all" | Redis key for cached config |

**Environment Variables:** None required. Caching uses the existing Redis configuration.

## Notes

- **Why single cache key?** For a small config dataset (~10-50 entries), a single cached response is more efficient than per-key caching. The entire config is typically fetched together by mobile apps.

- **Why string storage for values?** Storing typed values as strings with a valueType enum provides:
  - SQLite compatibility for testing
  - Simple database schema
  - Type safety at the API layer via ConfigValue enum

- **Cache invalidation timing:** Cache is invalidated immediately on any mutation. There's a brief window where different app instances might see stale data until their next request.

- **Admin authentication:** Uses the existing `EnsureAdminUserMiddleware` which checks the `isAdmin` flag on the authenticated user.

- **Migration compatibility:** Uses string columns instead of PostgreSQL native enums for SQLite test compatibility.

### Future Considerations

- Add config versioning for mobile app backward compatibility
- Consider per-category caching if config grows significantly
- Add config change audit logging
- Support config inheritance/overrides per environment
