## TASK-009: Delete User Use Cases

---
**Status:** OPEN
**Branch:** refactoring/architecture-simplification
**Type:** REFACTOR
**Phase:** 2
**Depends On:** T008
---

### Overview

Delete all User use case files after verifying controller tests pass.

**Files:**
- `Sources/App/Modules/User/UseCases/GetCurrentUserUseCase.swift` (delete)
- `Sources/App/Modules/User/UseCases/ListUsersUseCase.swift` (delete)
- `Sources/App/Modules/User/UseCases/UpdateUserProfileUseCase.swift` (delete)
- `Sources/App/Modules/User/UseCases/DeleteUserAccountUseCase.swift` (delete)
- `Sources/App/Modules/User/UseCases/` (delete directory)
- `Tests/AppTests/UseCases/User/` (delete directory after verification)

### Implementation Steps

**Commit 1: Delete User use cases and update imports**
- [ ] Verify all user controller tests pass
- [ ] Delete all 4 use case files in User/UseCases/
- [ ] Delete the UseCases directory
- [ ] Remove use case imports from any files
- [ ] Update UseCaseAccessors.swift to remove user use cases
- [ ] Delete user use case test files
- [ ] Verify build and tests still pass

### Success Criteria

- [ ] Build succeeds with no user use case files
- [ ] All user tests pass
- [ ] No orphaned imports or references
- [ ] User/UseCases/ directory doesn't exist

### Verification

```bash
swift build
swift test --filter User
ls Sources/App/Modules/User/UseCases/ # Should fail
```

### Notes

- User module is simpler than Auth - mostly repository calls
- Don't delete until tests pass
