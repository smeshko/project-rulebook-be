## TASK-005: Migrate SignInUseCase to AuthController

---
**Status:** OPEN
**Branch:** refactoring/architecture-simplification
**Type:** REFACTOR
**Phase:** 1
**Depends On:** T003
---

### Overview

Migrate SignInUseCase business logic to AuthController. Handles user authentication with email/password validation and token generation.

**Files:**
- `Sources/App/Modules/Auth/Controllers/AuthController.swift` (modify)
- `Sources/App/Modules/Auth/UseCases/SignInUseCase.swift` (reference, delete later)

### Implementation Steps

**Commit 1: Move SignInUseCase.execute() logic to AuthController.signIn()**
- [ ] Copy the execute() method body from SignInUseCase
- [ ] Update to use `req.repositories.*` and `req.services.*` syntax
- [ ] Preserve password verification logic
- [ ] Preserve token generation pattern

### Code Example

```swift
// After migration:
func signIn(_ req: Request) async throws -> Auth.Login.Response {
    let loginRequest = try req.content.decode(Auth.Login.Request.self)

    // Find user by email (normalized)
    guard let user = try await req.repositories.users.find(email: loginRequest.email.lowercased()) else {
        throw AuthenticationError.invalidEmailOrPassword
    }

    // Verify password
    guard try await req.password.async.verify(loginRequest.password, created: user.password) else {
        throw AuthenticationError.invalidEmailOrPassword
    }

    // Delete existing refresh tokens for this user
    try await req.repositories.refreshTokens.delete(forUserID: user.requireID())

    // Generate new refresh token
    let tokenValue = req.services.randomGenerator.generate(bits: 256)
    let refreshToken = RefreshTokenModel(
        value: SHA256.hash(tokenValue),
        userID: try user.requireID()
    )
    try await req.repositories.refreshTokens.create(refreshToken)

    return Auth.Login.Response(
        token: try .init(token: tokenValue, user: user, on: req),
        user: try .init(from: user)
    )
}
```

### Success Criteria

- [ ] Build succeeds
- [ ] SignIn endpoint works correctly
- [ ] Invalid email returns proper error
- [ ] Invalid password returns proper error
- [ ] Token is generated on success
- [ ] All auth tests pass

### Verification

```bash
swift build
swift test --filter Auth
```

### Notes

- Same error for invalid email OR password (security best practice)
- Old tokens are deleted before creating new one
- Password verification uses Vapor's built-in async verify
