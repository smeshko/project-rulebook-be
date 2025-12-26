## TASK-003: Verify New Pattern in Controller

---
**Status:** COMPLETE
**Branch:** refactoring/architecture-simplification
**Type:** IMPLEMENTATION
**Phase:** 0
**Depends On:** T002
---

### Overview

Verify the new accessor pattern works by updating one simple endpoint to use `req.services.*` instead of the use case pattern. Choose a low-risk endpoint for validation.

**Files:**
- `Sources/App/Modules/Auth/Controllers/AuthController.swift` (modify - one method only)

### Implementation Steps

**Commit 1: Update logout endpoint to use new pattern**
- [x] Find logout endpoint in AuthController
- [x] Replace `req.useCases.auth.logout` with direct repository call
- [x] Use `req.repositories.refreshTokens` for token deletion
- [x] Verify endpoint still works correctly

### Code Example

```swift
// BEFORE (current pattern)
func logout(_ req: Request) async throws -> HTTPStatus {
    let user = try req.auth.require(UserAccountModel.self)
    let useCase = try await req.useCases.auth.logout
    _ = try await useCase.execute(LogoutUseCase.Request(user: user))
    return .ok
}

// AFTER (new pattern)
func logout(_ req: Request) async throws -> HTTPStatus {
    let user = try req.auth.require(UserAccountModel.self)
    try await req.repositories.refreshTokens.delete(forUserID: user.requireID())
    return .ok
}
```

### Success Criteria

- [x] Build succeeds
- [x] Logout endpoint works correctly
- [x] Existing tests pass
- [x] No regression in logout functionality

### Verification

```bash
swift build
swift test --filter Auth
```

### Notes

- This is a validation task - only update ONE endpoint
- LogoutUseCase is the simplest (just deletes tokens)
- If this works, we've validated the entire infrastructure
- Revert if any issues - don't proceed to Phase 1 until this works
