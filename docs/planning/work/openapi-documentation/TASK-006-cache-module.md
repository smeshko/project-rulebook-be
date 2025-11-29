## TASK-006: Document CacheAdmin Module Endpoints

---
**Status:** COMPLETE
**Branch:** feature/openapi-documentation
**Type:** IMPLEMENTATION
**Phase:** 1
**Depends On:** TASK-002

---

### Overview

Add OpenAPI documentation metadata to all 6 CacheAdmin module endpoints. All endpoints require JWT authentication and admin role. Includes nested path (redis/health) to test path parameter handling.

### Files Modified

- `Sources/App/Modules/CacheAdmin/CacheAdminRouter.swift`

### Implementation Steps

- [x] Add "Cache Admin" tag to the admin/cache route group
- [x] Document cache statistics endpoint (GET /api/admin/cache/stats)
- [x] Document cache health endpoint (GET /api/admin/cache/health)
- [x] Document cache entries endpoint (GET /api/admin/cache/entries)
- [x] Document Redis health endpoint (GET /api/admin/cache/redis/health) - test nested path
- [x] Document clear cache endpoint (DELETE /api/admin/cache)
- [x] Document manual cleanup endpoint (POST /api/admin/cache/cleanup)
- [x] Add `bearerAuth` security requirement to all endpoints
- [x] Note admin requirement in descriptions

### Code Example

**File: `Sources/App/Modules/CacheAdmin/CacheAdminRouter.swift`**

```swift
import Vapor
import VaporToOpenAPI

struct CacheAdminRouter: RouteCollection {
    let controller = CacheAdminController()

    func boot(routes: any RoutesBuilder) throws {
        // Admin cache management endpoints (requires admin authentication)
        let adminAPI = routes
            .grouped("api")
            .grouped("admin")
            .grouped("cache")
            .groupedOpenAPI(tag: "Cache Admin")  // Tag all cache admin routes
            .grouped(EnsureAdminUserMiddleware())  // Admin-only enforced

        // Cache statistics and monitoring
        adminAPI
            .get("stats", use: controller.getCacheStatistics)
            .description("Retrieve comprehensive cache statistics including hit/miss rates, entry counts, and memory usage. Admin only.")
            .security([.init(requirement: "bearerAuth")])

        adminAPI
            .get("health", use: controller.getCacheHealth)
            .description("Check cache health status with diagnostic information and recommendations. Admin only.")
            .security([.init(requirement: "bearerAuth")])

        adminAPI
            .get("entries", use: controller.getCacheEntries)
            .description("List all cache entries with metadata (age, TTL, hit count). Useful for debugging cache behavior. Admin only.")
            .security([.init(requirement: "bearerAuth")])

        // Redis-specific health monitoring
        adminAPI
            .get("redis", "health", use: controller.getRedisHealth)
            .description("Check Redis connection health and latency. Separate from general cache health for infrastructure monitoring. Admin only.")
            .security([.init(requirement: "bearerAuth")])

        // Cache management operations
        adminAPI
            .delete(use: controller.clearCache)
            .description("Clear all cache entries. Use with caution - will temporarily reduce performance until cache rebuilds. Admin only.")
            .security([.init(requirement: "bearerAuth")])

        adminAPI
            .post("cleanup", use: controller.manualCleanup)
            .description("Manually trigger cache cleanup to remove expired entries. Normally handled automatically but useful for testing. Admin only.")
            .security([.init(requirement: "bearerAuth")])
    }
}
```

**Reference: Existing CacheAdminRouter pattern (from research.md)**
```swift
struct CacheAdminRouter: RouteCollection {
    let controller = CacheAdminController()

    func boot(routes: any RoutesBuilder) throws {
        let adminAPI = routes
            .grouped("api")
            .grouped("admin")
            .grouped("cache")
            .grouped(EnsureAdminUserMiddleware())  // Admin-only enforced

        adminAPI.get("stats", use: controller.getCacheStatistics)
        adminAPI.get("health", use: controller.getCacheHealth)
        adminAPI.get("entries", use: controller.getCacheEntries)
        adminAPI.get("redis", "health", use: controller.getRedisHealth)
        adminAPI.delete(use: controller.clearCache)
        adminAPI.post("cleanup", use: controller.manualCleanup)
    }
}
```

**Reference: CacheAdmin DTOs**
Schemas auto-generated from:
- `CacheAdmin.Statistics.Response`
- `CacheAdmin.Health.Response`
- `CacheAdmin.Entries.Response`
- `CacheAdmin.RedisHealth.Response`
- `CacheAdmin.Clear.Response`

### Success Criteria

- [ ] Build succeeds without errors
- [ ] All 6 cache admin endpoints appear in `/openapi.json` under "Cache Admin" tag
- [ ] Each endpoint has description explaining admin purpose
- [ ] All endpoints show `bearerAuth` security requirement
- [ ] Nested path `/api/admin/cache/redis/health` correctly represented
- [ ] Descriptions emphasize admin-only access
- [ ] Request/response schemas match DTO structures

### Verification Commands

```bash
# Build project
swift build

# Run and verify CacheAdmin endpoints
swift run &
sleep 5

# List all Cache Admin endpoints
curl -s http://localhost:8080/openapi.json | jq '.paths | to_entries | map(select(.key | contains("/admin/cache"))) | from_entries'

# Verify nested path exists
curl -s http://localhost:8080/openapi.json | jq '.paths["/api/admin/cache/redis/health"]'

# Verify all have security requirements
curl -s http://localhost:8080/openapi.json | jq '[.paths | to_entries[] | select(.key | contains("/admin/cache")) | .value[].security] | unique'

pkill -f "swift run"
```

### Notes

- All cache admin endpoints require both JWT authentication AND admin role via EnsureAdminUserMiddleware
- The nested path `redis/health` tests VaporToOpenAPI's handling of multi-segment paths
- DELETE endpoint has no path parameters (operates on root `/api/admin/cache`)
- Descriptions should emphasize admin-only nature for security awareness
- Rate limiting applies but is less strict for admin endpoints (10-200 requests per 5 minutes)
