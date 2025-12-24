## TASK-006: Migrate RefreshTokenUseCase and AppleSignInUseCase

---
**Status:** OPEN
**Branch:** refactoring/architecture-simplification
**Type:** REFACTOR
**Phase:** 1
**Depends On:** T003
---

### Overview

Migrate remaining auth use cases: RefreshTokenUseCase (JWT token rotation) and AppleSignInUseCase (Apple Sign-In integration).

**Files:**
- `Sources/App/Modules/Auth/Controllers/AuthController.swift` (modify)
- `Sources/App/Modules/Auth/UseCases/RefreshTokenUseCase.swift` (reference, delete later)
- `Sources/App/Modules/Auth/UseCases/AppleSignInUseCase.swift` (reference, delete later)

### Implementation Steps

**Commit 1: Move RefreshTokenUseCase and AppleSignInUseCase logic to AuthController**
- [ ] Copy RefreshTokenUseCase.execute() logic to refreshToken method
- [ ] Copy AppleSignInUseCase.execute() logic to authWithApple method
- [ ] Update to use `req.repositories.*` and `req.services.*` syntax
- [ ] Preserve token rotation logic
- [ ] Preserve Apple identity token validation

### Code Example

```swift
// RefreshToken migration:
func refreshToken(_ req: Request) async throws -> Auth.Refresh.Response {
    let refreshRequest = try req.content.decode(Auth.Refresh.Request.self)

    // Find token by hashed value
    let hashedToken = SHA256.hash(refreshRequest.refreshToken)
    guard let storedToken = try await req.repositories.refreshTokens.find(token: hashedToken) else {
        throw AuthenticationError.refreshTokenOrUserNotFound
    }

    // Verify token not expired
    guard storedToken.expiresAt > Date.now else {
        try await req.repositories.refreshTokens.delete(id: storedToken.requireID())
        throw AuthenticationError.refreshTokenExpired
    }

    // Get associated user
    let user = try await storedToken.$user.get(on: req.db)

    // Delete old token
    try await req.repositories.refreshTokens.delete(id: storedToken.requireID())

    // Generate new token
    let newTokenValue = req.services.randomGenerator.generate(bits: 256)
    let newRefreshToken = RefreshTokenModel(
        value: SHA256.hash(newTokenValue),
        userID: try user.requireID()
    )
    try await req.repositories.refreshTokens.create(newRefreshToken)

    return Auth.Refresh.Response(
        token: try .init(token: newTokenValue, user: user, on: req),
        user: try .init(from: user)
    )
}

// AppleSignIn migration:
func authWithApple(_ req: Request) async throws -> Auth.Apple.Response {
    let appleRequest = try req.content.decode(Auth.Apple.Request.self)

    // Verify Apple identity token (existing logic)
    let appleIdentityToken = try await req.jwt.apple.verify(
        appleRequest.appleIdentityToken,
        applicationIdentifier: req.application.configuration.appleAppId
    )

    // Find or create user
    let user: UserAccountModel
    if let existingUser = try await req.repositories.users.find(appleUserIdentifier: appleIdentityToken.subject.value) {
        user = existingUser
    } else {
        // Create new user from Apple data
        user = UserAccountModel(
            email: appleIdentityToken.email ?? "\(appleIdentityToken.subject.value)@apple.invalid",
            password: req.services.randomGenerator.generate(bits: 256), // Random password
            firstName: appleRequest.firstName,
            lastName: appleRequest.lastName,
            appleUserIdentifier: appleIdentityToken.subject.value
        )
        try await req.repositories.users.create(user)
    }

    // Generate refresh token
    let tokenValue = req.services.randomGenerator.generate(bits: 256)
    let refreshToken = RefreshTokenModel(
        value: SHA256.hash(tokenValue),
        userID: try user.requireID()
    )
    try await req.repositories.refreshTokens.create(refreshToken)

    return Auth.Apple.Response(
        token: try .init(token: tokenValue, user: user, on: req),
        user: try .init(from: user)
    )
}
```

### Success Criteria

- [ ] Build succeeds
- [ ] Token refresh works correctly
- [ ] Apple Sign-In works correctly
- [ ] Token rotation creates new token, deletes old
- [ ] All auth tests pass

### Verification

```bash
swift build
swift test --filter Auth
```

### Notes

- Token refresh requires both token validation AND user lookup
- Apple Sign-In may create new user or find existing
- Both operations delete old tokens before creating new
