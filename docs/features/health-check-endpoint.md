# Health Check Endpoint

**Date:** 2026-03-19
**Related Files:** `Sources/App/Modules/Health/`, `Tests/AppTests/Tests/ControllerTests/HealthTests/`

## Overview

A comprehensive health check endpoint at `GET /health` that probes database and Redis connectivity, returning structured JSON with individual check statuses. Designed for Railway/Kubernetes liveness probes to monitor service availability and trigger automatic restarts when dependencies are unreachable.

## What Was Built

- `HealthModule` following the `ModuleInterface` pattern for module registration
- `HealthRouter` registering the endpoint at root `/health` (outside `/api/v1` group)
- `HealthController` with database and Redis health probes
- `Health.Check.Response` DTO with nested `Checks` struct for type-safe responses
- Integration test suite covering happy path, timestamp validation, JSON structure, and no-auth behavior

## Technical Implementation

### Key Files

- `Sources/App/Modules/Health/HealthModule.swift`: Module entry point implementing `ModuleInterface`
- `Sources/App/Modules/Health/HealthRouter.swift`: Route registration at `/health` with OpenAPI tags
- `Sources/App/Modules/Health/Controllers/HealthController.swift`: Health probe logic and response assembly
- `Sources/App/Modules/Health/Models/Health+Model.swift`: Response DTO using nested enum namespace pattern
- `Tests/AppTests/Tests/ControllerTests/HealthTests/HealthCheckTests.swift`: Integration tests

### Key Patterns

- **Database Probe via SQLKit**: Casts `req.db` to `SQLDatabase` and executes `SELECT 1` to verify connectivity. Falls back to `"error"` if the database driver doesn't support SQLKit (e.g., SQLite in tests returns error for this cast).
- **Redis Probe via CacheService**: Writes a short-TTL key (`health:ping:<uuid>`), reads it back, and deletes it. Uses the `CacheService` abstraction rather than direct Redis commands to validate the full cache pipeline.
- **Custom HTTP Status via Response**: Returns `Response` instead of conforming to `Content` so the controller can set 200 for healthy and 503 for unhealthy. This is necessary because Vapor's `Content` return type always produces 200.
- **No Authentication**: The route group is registered without `UserPayloadAuthenticator` or `EnsureAdminUserMiddleware`, allowing infrastructure probes to hit the endpoint without credentials.

### Code Examples

```swift
// Database probe pattern
guard let sqlDB = req.db as? any SQLDatabase else {
    return "error"
}
_ = try await sqlDB.raw("SELECT 1").first()
return "ok"
```

```swift
// Redis probe pattern using CacheService
let healthKey = "health:ping:\(UUID().uuidString)"
try await req.services.cache.set(healthKey, value: "pong", ttl: 5.0)
let result: String? = try await req.services.cache.get(healthKey, as: String.self)
try? await req.services.cache.delete(healthKey)
guard result == "pong" else { return "error" }
return "ok"
```

## How to Use

1. Send `GET /health` — no authentication required
2. Check response status code: `200` = all healthy, `503` = one or more checks failed
3. Parse JSON body for individual check details:

```json
{
  "status": "healthy",
  "timestamp": "2026-03-19T20:30:00Z",
  "checks": {
    "database": "ok",
    "redis": "ok"
  }
}
```

## Configuration

No configuration options. The endpoint is always available at `/health` and checks all registered dependencies.

| Aspect | Value | Description |
|--------|-------|-------------|
| Path | `/health` | Root-level, outside `/api/v1` |
| Auth | None | No authentication middleware applied |
| Redis TTL | 5 seconds | Health probe key expiry |

## Notes

- In test environments, the database probe may return `"error"` because SQLite (used in tests) does not conform to `SQLDatabase`. The test suite validates against a full `IsolatedTestWorld` which configures appropriate test doubles.
- The Redis probe generates a unique key per request to avoid key collisions under concurrent health checks.
- Warning-level logs are emitted when any check fails, providing structured metadata for observability dashboards.
