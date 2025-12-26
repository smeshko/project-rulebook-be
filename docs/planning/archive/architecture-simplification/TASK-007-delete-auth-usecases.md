## TASK-007: Delete Auth Use Cases and Migrate Tests

---
**Status:** OPEN
**Branch:** refactoring/architecture-simplification
**Type:** REFACTOR
**Phase:** 1
**Depends On:** T004, T005, T006
---

### Overview

Delete all Auth use case files and ensure all test scenarios are covered in controller integration tests.

**Files:**
- `Sources/App/Modules/Auth/UseCases/SignUpUseCase.swift` (delete)
- `Sources/App/Modules/Auth/UseCases/SignInUseCase.swift` (delete)
- `Sources/App/Modules/Auth/UseCases/LogoutUseCase.swift` (delete)
- `Sources/App/Modules/Auth/UseCases/RefreshTokenUseCase.swift` (delete)
- `Sources/App/Modules/Auth/UseCases/AppleSignInUseCase.swift` (delete)
- `Sources/App/Modules/Auth/UseCases/` (delete directory)
- `Tests/AppTests/UseCases/Authentication/` (delete directory after verification)

### Implementation Steps

**Commit 1: Delete Auth use cases and update imports**
- [ ] Verify all auth controller tests pass
- [ ] Delete all 5 use case files in Auth/UseCases/
- [ ] Delete the UseCases directory
- [ ] Remove use case imports from any files
- [ ] Update UseCaseAccessors.swift to remove auth use cases
- [ ] Delete auth use case test files
- [ ] Verify build and tests still pass

### Test Scenario Mapping

Ensure these scenarios are covered in controller tests:

**SignUp:**
- [ ] Successful registration with valid data
- [ ] Duplicate email returns emailAlreadyExists error
- [ ] Password is hashed before storage
- [ ] Verification email is sent

**SignIn:**
- [ ] Successful login with valid credentials
- [ ] Invalid email returns invalidEmailOrPassword
- [ ] Invalid password returns invalidEmailOrPassword
- [ ] Token is generated on success

**Logout:**
- [ ] Token is deleted on logout
- [ ] Returns .ok status

**RefreshToken:**
- [ ] Valid token returns new token pair
- [ ] Expired token returns error
- [ ] Invalid token returns error
- [ ] Old token is deleted

**AppleSignIn:**
- [ ] New user is created with Apple ID
- [ ] Existing user is found by Apple ID
- [ ] Token is generated

### Success Criteria

- [ ] Build succeeds with no auth use case files
- [ ] All auth tests pass
- [ ] No orphaned imports or references
- [ ] Auth/UseCases/ directory doesn't exist

### Verification

```bash
swift build
swift test --filter Auth
ls Sources/App/Modules/Auth/UseCases/ # Should fail
```

### Notes

- Don't delete use cases until ALL controller tests pass
- Check for any imports of use case types in other files
- UseCaseAccessors.swift will need auth section removed
