## TASK-010: Migrate CacheAdmin Module Use Cases

---
**Status:** OPEN
**Branch:** refactoring/architecture-simplification
**Type:** REFACTOR
**Phase:** 3
**Depends On:** T009
---

### Overview

Migrate all 6 CacheAdmin use cases to CacheAdminController: GetCacheStats, ClearCache, GetCacheKey, DeleteCacheKey, ListCacheKeys, RefreshCache.

**Files:**
- `Sources/App/Modules/CacheAdmin/Controllers/CacheAdminController.swift` (modify)
- `Sources/App/Modules/CacheAdmin/UseCases/*.swift` (reference, delete)

### Implementation Steps

**Commit 1: Move all CacheAdmin use case logic to CacheAdminController**
- [ ] GetCacheStatsUseCase: Return cache statistics
- [ ] ClearCacheUseCase: Clear all cache entries
- [ ] GetCacheKeyUseCase: Get specific cache entry
- [ ] DeleteCacheKeyUseCase: Delete specific cache entry
- [ ] ListCacheKeysUseCase: List all cache keys
- [ ] RefreshCacheUseCase: Refresh cache for key
- [ ] Update to use `req.services.aiCache` syntax

### Code Example

```swift
// GetCacheStats
func getCacheStats(_ req: Request) async throws -> CacheAdmin.Stats.Response {
    let stats = await req.services.aiCache.getStats()
    return CacheAdmin.Stats.Response(
        totalKeys: stats.totalKeys,
        memoryUsage: stats.memoryUsage,
        hitRate: stats.hitRate
    )
}

// ClearCache
func clearCache(_ req: Request) async throws -> HTTPStatus {
    await req.services.aiCache.clear()
    return .ok
}

// GetCacheKey
func getCacheKey(_ req: Request) async throws -> CacheAdmin.Key.Response {
    let key = try req.parameters.require("key", as: String.self)
    guard let value = await req.services.aiCache.get(key: key) else {
        throw Abort(.notFound)
    }
    return CacheAdmin.Key.Response(key: key, value: value)
}

// DeleteCacheKey
func deleteCacheKey(_ req: Request) async throws -> HTTPStatus {
    let key = try req.parameters.require("key", as: String.self)
    await req.services.aiCache.remove(key: key)
    return .ok
}

// ListCacheKeys
func listCacheKeys(_ req: Request) async throws -> CacheAdmin.KeyList.Response {
    let keys = await req.services.aiCache.listKeys()
    return CacheAdmin.KeyList.Response(keys: keys)
}

// RefreshCache
func refreshCache(_ req: Request) async throws -> HTTPStatus {
    let key = try req.parameters.require("key", as: String.self)
    await req.services.aiCache.refresh(key: key)
    return .ok
}
```

### Success Criteria

- [ ] Build succeeds
- [ ] All cache admin endpoints work correctly
- [ ] Stats endpoint returns valid data
- [ ] Clear cache actually clears entries
- [ ] All cache admin tests pass

### Verification

```bash
swift build
swift test --filter CacheAdmin
```

### Notes

- All operations use `req.services.aiCache`
- These are admin operations - typically require admin auth
- Simple service calls - low risk migration
