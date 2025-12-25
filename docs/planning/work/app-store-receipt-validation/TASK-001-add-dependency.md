## TASK-001: Add App Store Server Library Dependency

---
**Status:** OPEN
**Branch:** feature/app-store-receipt-validation
**Type:** IMPLEMENTATION
**Phase:** 1
**Depends On:** None
---

### Overview

Add Apple's App Store Server Library Swift package to enable JWS transaction verification for iOS in-app purchases.

**Files:**
- `Package.swift`

### Implementation Steps

**Commit 1: feat(deps): add App Store Server Library dependency**
- [ ] Add package dependency for app-store-server-library-swift v4.0.0
- [ ] Add product to App target dependencies
- [ ] Run `swift build` to verify dependency resolution

### Code Example

```swift
// Package.swift
// Add to dependencies array:
.package(url: "https://github.com/apple/app-store-server-library-swift.git", exact: "4.0.0"),

// Add to App target dependencies:
.product(name: "AppStoreServerLibrary", package: "app-store-server-library-swift"),
```

### Success Criteria

- [ ] Build succeeds with `swift build`
- [ ] No dependency conflicts
- [ ] Package.resolved updated with new dependency

### Verification

```bash
swift build
swift package show-dependencies | grep app-store-server-library
```

### Notes

Using exact version 4.0.0 as specified in Linear issue RULE-128.
