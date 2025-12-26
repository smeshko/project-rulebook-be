## TASK-015: Delete ServiceRegistry Infrastructure

---
**Status:** OPEN
**Branch:** refactoring/architecture-simplification
**Type:** REFACTOR
**Phase:** 5
**Depends On:** T014
---

### Overview

Delete all ServiceRegistry infrastructure files (11 files, ~2,500 lines) now that all use cases are migrated.

**Files:**
- `Sources/App/Common/ServiceRegistry/ServiceContainer.swift` (delete)
- `Sources/App/Common/ServiceRegistry/ServiceCache.swift` (delete)
- `Sources/App/Common/ServiceRegistry/ServiceRegistry.swift` (delete)
- `Sources/App/Common/ServiceRegistry/ServiceRegistryIntegration.swift` (delete)
- `Sources/App/Common/ServiceRegistry/ServiceRegistryError.swift` (delete)
- `Sources/App/Common/ServiceRegistry/ServiceLifecycle.swift` (delete)
- `Sources/App/Common/ServiceRegistry/ServiceProvider.swift` (delete)
- `Sources/App/Common/ServiceRegistry/RepositoryServiceProvider.swift` (delete)
- `Sources/App/Common/ServiceRegistry/ExternalServiceProvider.swift` (delete)
- `Sources/App/Common/ServiceRegistry/DomainServiceProvider.swift` (delete)
- `Sources/App/Common/ServiceRegistry/CQRSServiceProvider.swift` (delete)
- `Sources/App/Common/ServiceRegistry/` (delete directory)
- `Tests/AppTests/ServiceRegistry/` (delete directory)

### Implementation Steps

**Commit 1: Delete ServiceRegistry infrastructure**
- [ ] Remove `setupServiceRegistry()` call from Application-Setup.swift
- [ ] Remove `createServiceCache()` call
- [ ] Remove `serviceRegistry` property access from any remaining code
- [ ] Delete all 11 ServiceRegistry files
- [ ] Delete the ServiceRegistry directory
- [ ] Delete ServiceRegistry tests
- [ ] Verify build succeeds
- [ ] Verify all tests pass

### Files to Check for References

Search for and remove references to:
- `serviceRegistry`
- `ServiceContainer`
- `ServiceCache`
- `ServiceProvider`
- `setupServiceRegistry`
- `createServiceCache`
- `resolveRequired`
- `resolveService`

### Code Changes in Application-Setup.swift

```swift
// BEFORE
func setupServices() throws {
    // ... existing code
    try await setupServiceRegistry()
    // ...
}

// AFTER
func setupServices() throws {
    // Initialize services directly on Application storage
    // (already done in T002)
}
```

### Success Criteria

- [ ] Build succeeds with no ServiceRegistry code
- [ ] All tests pass
- [ ] `grep -r "serviceRegistry" Sources/` returns nothing
- [ ] `grep -r "ServiceContainer" Sources/` returns nothing
- [ ] ServiceRegistry/ directory doesn't exist

### Verification

```bash
swift build
swift test
grep -r "serviceRegistry" Sources/
grep -r "ServiceContainer" Sources/
ls Sources/App/Common/ServiceRegistry/ # Should fail
```

### Notes

- This is a major deletion - ~2,500 lines
- Verify NO code still references ServiceRegistry before deleting
- May need to update TestWorld/IsolatedTestWorld first
