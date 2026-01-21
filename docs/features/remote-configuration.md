# Remote Configuration Module

**Date:** 2026-01-21
**Related Files:** RemoteConfigController.swift, RemoteConfigRouter.swift, RemoteConfigRepository.swift, RemoteConfig+Model.swift

## Overview

Server-side remote configuration system that delivers feature flags and app settings to mobile clients without requiring app store updates. Provides a public endpoint for mobile apps to fetch configuration and admin endpoints for managing configuration entries.

## What Was Built

- Public endpoint (`GET /api/v1/config`) for mobile clients to fetch feature flags and settings
- Admin CRUD endpoints (`/api/v1/admin/config`) for managing configuration entries
- Cache-first strategy with 5-minute TTL and graceful database fallback
- Value type validation (boolean, integer, string, json)
- Automatic cache invalidation on configuration mutations
- AnyCodable type-erased wrapper for heterogeneous JSON values

## Technical Implementation

### Key Files

- `Sources/App/Modules/RemoteConfig/RemoteConfigController.swift`: Business logic for public and admin endpoints
- `Sources/App/Modules/RemoteConfig/RemoteConfigRouter.swift`: Route definitions with OpenAPI documentation
- `Sources/App/Modules/RemoteConfig/Repositories/RemoteConfigRepository.swift`: Data access layer
- `Sources/App/Modules/RemoteConfig/Models/RemoteConfig+Model.swift`: Request/response models and AnyCodable wrapper
- `Sources/App/Modules/RemoteConfig/Database/Models/RemoteConfigEntryModel.swift`: Fluent database model
- `Sources/App/Modules/RemoteConfig/RemoteConfigModule.swift`: Module registration

### Key Patterns

**Cache-First Strategy with Graceful Degradation:**

The public config endpoint tries cache first but gracefully falls back to the database if cache operations fail:

```swift
func getConfig(_ req: Request) async throws -> RemoteConfig.Response {
    let cacheService = req.application.cacheService

    // Try cache first (gracefully handle cache failures)
    do {
        if let cached = try await cacheService.get(Self.cacheKey, as: RemoteConfig.Response.self) {
            return cached
        }
    } catch {
        req.logger.warning("Cache read failed, falling back to database: \(error)")
    }

    // Cache miss or error - build response from database
    let repository = req.repositories.remoteConfig
    let entries = try await repository.all()
    let response = buildConfigResponse(from: entries)

    // Cache the response (best-effort, don't fail on cache errors)
    do {
        try await cacheService.set(Self.cacheKey, value: response, ttl: Self.cacheTTL)
    } catch {
        req.logger.warning("Cache write failed: \(error)")
    }

    return response
}
```

**Type-Safe Value Validation:**

Configuration values are validated against their declared type before storage:

```swift
private func validateValueType(value: String, type: RemoteConfig.ValueType) throws {
    switch type {
    case .boolean:
        let lowercased = value.lowercased()
        guard lowercased == "true" || lowercased == "false" else {
            throw Abort(.badRequest, reason: "Value must be 'true' or 'false' for boolean type")
        }
    case .integer:
        guard Int(value) != nil else {
            throw Abort(.badRequest, reason: "Value must be a valid integer")
        }
    case .json:
        guard let data = value.data(using: .utf8),
              (try? JSONSerialization.jsonObject(with: data)) != nil else {
            throw Abort(.badRequest, reason: "Value must be valid JSON")
        }
    case .string:
        break // All strings are valid
    }
}
```

**AnyCodable Type-Erased Wrapper:**

For encoding heterogeneous JSON values in the settings dictionary:

```swift
struct AnyCodable: Codable, @unchecked Sendable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    // Encode/decode any JSON-compatible type
}
```

**Race Condition Protection:**

Admin create endpoint handles concurrent duplicate key creation:

```swift
// Pre-check for fast-fail
if let _ = try await repository.find(key: createRequest.key) {
    throw Abort(.conflict, reason: "Configuration key already exists")
}

do {
    try await repository.create(entry)
} catch {
    // Handle unique constraint violation from concurrent creates
    if "\(error)".contains("UNIQUE constraint failed") || "\(error)".contains("duplicate key") {
        throw Abort(.conflict, reason: "Configuration key already exists")
    }
    throw error
}
```

### Code Examples

**Creating a Feature Flag (Admin):**

```bash
POST /api/v1/admin/config
Authorization: Bearer <admin-token>
Content-Type: application/json

{
    "key": "feature_dark_mode",
    "value": "true",
    "valueType": "boolean",
    "description": "Enable dark mode feature"
}
```

**Fetching Configuration (Mobile Client):**

```bash
GET /api/v1/config

Response:
{
    "featureFlags": {
        "feature_dark_mode": true,
        "feature_beta_testing": false
    },
    "settings": {
        "max_retries": 3,
        "api_timeout": 30,
        "welcome_message": "Hello!"
    },
    "version": "1737496234"
}
```

## How to Use

### For Mobile App Developers

1. Call `GET /api/v1/config` on app launch or resume
2. Use the `version` field to detect configuration changes
3. Boolean configs are in `featureFlags`, other types in `settings`
4. Cache locally and refresh periodically (endpoint is cached server-side for 5 minutes)

```swift
// iOS Example
struct RemoteConfig: Codable {
    let featureFlags: [String: Bool]
    let settings: [String: AnyCodable]
    let version: String
}

func fetchConfig() async throws -> RemoteConfig {
    let url = URL(string: "https://api.example.com/api/v1/config")!
    let (data, _) = try await URLSession.shared.data(from: url)
    return try JSONDecoder().decode(RemoteConfig.self, from: data)
}
```

### For Backend Developers

**Adding New Configuration Entry:**

1. Use admin panel or API to create entry
2. Choose appropriate value type (boolean for feature flags)
3. Cache is automatically invalidated

**Creating a New Module Following This Pattern:**

1. Create module directory under `Sources/App/Modules/{ModuleName}/`
2. Create subdirectories: `Database/Models/`, `Database/Migrations/`, `Models/`, `Repositories/`
3. Implement: Model, Repository Protocol + Implementation, Controller, Router, Module
4. Register repository in `Application+Services.swift`
5. Register module in `Application-Setup.swift`
6. Create test repository mock in `Tests/AppTests/Framework/Mocks/Repositories/`

## Configuration

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| Cache TTL | TimeInterval | 300 (5 min) | How long public config is cached |
| Cache Key | String | "remote_config_public" | Cache key for public config |

**Value Types:**

| Type | Storage | JSON Output |
|------|---------|-------------|
| boolean | "true"/"false" | true/false in featureFlags |
| integer | "123" | 123 in settings |
| string | "any text" | "any text" in settings |
| json | "{...}" | parsed object in settings |

## Notes

### Public vs Admin Endpoints

- **Public (`/api/v1/config`)**: No authentication required, read-only, cached
- **Admin (`/api/v1/admin/config`)**: Requires authentication + admin role, CRUD operations, triggers cache invalidation

### Response Structure Design

Boolean values are separated into `featureFlags` for easier mobile consumption:

```json
{
    "featureFlags": { "feature_x": true },  // Only booleans
    "settings": { "max_items": 100 }         // Everything else
}
```

### Version Field

The `version` field is a Unix timestamp of the most recent update. Mobile apps can use this to detect when configuration has changed without comparing the full payload.

### Testing

Test tag `.config` is available for filtering remote config tests:

```bash
swift test --filter config
```

### Architectural Decisions

- **Values stored as strings**: Allows uniform storage while supporting multiple types via valueType enum
- **Cache-first with fallback**: Ensures API availability even during cache failures
- **Admin authorization**: Uses EnsureAdminUserMiddleware following existing codebase patterns
- **OpenAPI integration**: All routes documented via VaporToOpenAPI annotations
