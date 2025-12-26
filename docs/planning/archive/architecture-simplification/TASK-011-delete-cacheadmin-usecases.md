## TASK-011: Delete CacheAdmin Use Cases

---
**Status:** OPEN
**Branch:** refactoring/architecture-simplification
**Type:** REFACTOR
**Phase:** 3
**Depends On:** T010
---

### Overview

Delete all CacheAdmin use case files after verifying controller tests pass.

**Files:**
- `Sources/App/Modules/CacheAdmin/UseCases/GetCacheStatsUseCase.swift` (delete)
- `Sources/App/Modules/CacheAdmin/UseCases/ClearCacheUseCase.swift` (delete)
- `Sources/App/Modules/CacheAdmin/UseCases/GetCacheKeyUseCase.swift` (delete)
- `Sources/App/Modules/CacheAdmin/UseCases/DeleteCacheKeyUseCase.swift` (delete)
- `Sources/App/Modules/CacheAdmin/UseCases/ListCacheKeysUseCase.swift` (delete)
- `Sources/App/Modules/CacheAdmin/UseCases/RefreshCacheUseCase.swift` (delete)
- `Sources/App/Modules/CacheAdmin/UseCases/` (delete directory)
- `Tests/AppTests/UseCases/CacheAdmin/` (delete directory)

### Implementation Steps

**Commit 1: Delete CacheAdmin use cases and update imports**
- [ ] Verify all cache admin controller tests pass
- [ ] Delete all 6 use case files in CacheAdmin/UseCases/
- [ ] Delete the UseCases directory
- [ ] Remove use case imports from any files
- [ ] Update UseCaseAccessors.swift to remove cache admin use cases
- [ ] Delete cache admin use case test files
- [ ] Verify build and tests still pass

### Success Criteria

- [ ] Build succeeds with no cache admin use case files
- [ ] All cache admin tests pass
- [ ] No orphaned imports or references
- [ ] CacheAdmin/UseCases/ directory doesn't exist

### Verification

```bash
swift build
swift test --filter CacheAdmin
ls Sources/App/Modules/CacheAdmin/UseCases/ # Should fail
```

### Notes

- CacheAdmin is simple service calls - low risk
- Check for any remaining use case references
