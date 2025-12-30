# Remote Configuration System

**Date:** 2025-12-30
**Related Files:** ConfigModule.swift, ConfigRouter.swift, ConfigController.swift, ConfigEntryModel.swift, ConfigRepository.swift

## Overview

Implemented a remote configuration system that allows mobile apps to fetch feature flags and dynamic settings from the server. This enables runtime configuration changes without requiring app updates, supporting A/B testing, gradual rollouts, and emergency feature toggles.

## What Was Built

- Public endpoint for retrieving all active configuration (`GET /api/v1/config`)
- Admin-only endpoint for updating configuration (`PATCH /api/v1/admin/config`)
- Redis-based caching with 5-minute TTL for performance
- Flexible value types supporting booleans, integers, strings, and objects
- Database persistence for configuration entries

## Technical Implementation

### Key Files

- `Sources/App/Modules/Config/ConfigModule.swift`: Module registration and migration setup
- `Sources/App/Modules/Config/ConfigRouter.swift`: Route definitions with OpenAPI documentation
- `Sources/App/Modules/Config/Controllers/ConfigController.swift`: Business logic with caching
- `Sources/App/Modules/Config/Database/Models/ConfigEntryModel.swift`: Database model
- `Sources/App/Modules/Config/Repositories/ConfigRepository.swift`: Data access layer
- `Sources/App/Modules/Config/Models/Config+Model.swift`: Request/response types

### Key Patterns

**Key Naming Convention:**

Config entries use dot-notation prefixes to organize values:

```
featureFlags.{flagName}  → Boolean feature flags
settings.{settingName}   → Dynamic settings (any type)
version                  → Config schema version
```

**Examples:**
- `featureFlags.darkMode` → `true`
- `featureFlags.newOnboarding` → `false`
- `settings.maxUploadSize` → `10485760`
- `settings.supportEmail` → `"support@example.com"`
- `version` → `"1.0.0"`

**Response Structure:**

```json
{
  "featureFlags": {
    "darkMode": true,
    "newOnboarding": false
  },
  "settings": {
    "maxUploadSize": 10485760,
    "supportEmail": "support@example.com"
  },
  "version": "1.0.0"
}
```

**Caching Strategy:**

- Cache key: `config:all`
- TTL: 5 minutes (300 seconds)
- Cache invalidation: Automatic on any config update via admin endpoint
- Rationale: Config changes are rare but reads are frequent

**Admin Update Request:**

```json
{
  "entries": [
    {
      "key": "featureFlags.darkMode",
      "value": true,
      "valueType": "boolean"
    },
    {
      "key": "settings.maxUploadSize",
      "value": 10485760,
      "valueType": "integer"
    }
  ]
}
```

## How to Use

### For Mobile App Developers

1. **Fetch Configuration:**
   ```swift
   // iOS Example
   let url = URL(string: "https://api.example.com/api/v1/config")!
   let (data, _) = try await URLSession.shared.data(from: url)
   let config = try JSONDecoder().decode(ConfigResponse.self, from: data)

   // Use feature flags
   if config.featureFlags["darkMode"] == true {
       enableDarkMode()
   }
   ```

2. **Cache Locally:**
   - Cache the response locally with appropriate TTL
   - Refresh on app launch and periodically in background
   - Use cached values when offline

### For Backend Developers

1. **Adding New Feature Flags:**
   - Use admin endpoint to add entry with key `featureFlags.{name}`
   - Set `valueType` to `"boolean"`
   - Value must be `true` or `false`

2. **Adding New Settings:**
   - Use admin endpoint to add entry with key `settings.{name}`
   - Set appropriate `valueType`: `"boolean"`, `"integer"`, `"string"`, or `"object"`

3. **Updating Values:**
   - Use `PATCH /api/v1/admin/config` with admin authentication
   - Cache is automatically invalidated on update

### For Adding New Config Types

When extending the config system:

1. Choose a new prefix (e.g., `experiments.{name}`)
2. Update `ConfigController.buildConfigResponse()` to parse the new prefix
3. Update the `Config.Response` struct with new property
4. Update tests in `ConfigGetTests.swift` and `ConfigAdminTests.swift`

## Configuration

**Environment Variables:** None required - config is stored in database.

**Database Table:** `config_entries`
- `id`: UUID primary key
- `key`: String (unique, indexed)
- `value`: JSON (flexible value storage)
- `value_type`: String (type hint for parsing)
- `created_at`: Timestamp
- `updated_at`: Timestamp

**Cache Settings:**
- Cache service: Redis (via `req.services.cache`)
- Cache key: `config:all`
- Default TTL: 300 seconds (5 minutes)
- To change TTL: Modify `ConfigController.cacheTTL`

## Notes

### Security Considerations

- Public endpoint (`GET /api/v1/config`) requires no authentication
- Admin endpoint (`PATCH /api/v1/admin/config`) requires:
  - Valid JWT authentication
  - Admin role (via `EnsureAdminUserMiddleware`)
- Never store secrets in config - use environment variables instead

### Performance Considerations

- First request after cache expiry will be slower (DB query)
- Subsequent requests served from Redis cache
- Cache invalidation is immediate on admin updates
- Consider client-side caching in mobile apps

### Common Issues

**Problem:** Config changes not appearing in app
**Solution:** Wait 5 minutes for cache to expire, or trigger admin update to invalidate

**Problem:** New feature flag not in response
**Solution:** Ensure key uses `featureFlags.` prefix exactly

**Problem:** Admin update returns 401/403
**Solution:** Verify JWT token and user has admin role

### Future Enhancements

Potential improvements for future iterations:
- Per-key TTL configuration
- A/B testing with user targeting
- Config change audit log
- Gradual rollout percentages
- Environment-specific configs
