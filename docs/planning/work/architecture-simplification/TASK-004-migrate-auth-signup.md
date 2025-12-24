## TASK-004: Migrate SignUpUseCase to AuthController

---
**Status:** OPEN
**Branch:** refactoring/architecture-simplification
**Type:** REFACTOR
**Phase:** 1
**Depends On:** T003
---

### Overview

Migrate SignUpUseCase business logic to AuthController. This use case has critical duplicate email detection logic that must be preserved exactly.

**Files:**
- `Sources/App/Modules/Auth/Controllers/AuthController.swift` (modify)
- `Sources/App/Modules/Auth/UseCases/SignUpUseCase.swift` (reference, delete later)

### Implementation Steps

**Commit 1: Move SignUpUseCase.execute() logic to AuthController.signUp()**
- [ ] Copy the execute() method body from SignUpUseCase (lines 71-126)
- [ ] Copy the sendEmailVerification() helper method (lines 132-170)
- [ ] Update to use `req.repositories.*` and `req.services.*` syntax
- [ ] Preserve EXACT duplicate email detection logic (lines 88-101)
- [ ] Preserve email normalization (.lowercased())
- [ ] Preserve password hashing pattern

### Code Example

```swift
// Critical logic to preserve from SignUpUseCase.swift:88-101
do {
    try await userRepository.create(user)
} catch {
    let errorString = String(reflecting: error)

    // PostgreSQL UNIQUE constraint detection
    let isPostgreSQLDuplicateEmail = errorString.contains("sqlState: 23505") &&
        (errorString.contains("uq:users.email") ||
         errorString.contains("Key (email)") ||
         errorString.contains("duplicate key") && errorString.contains("email"))

    // SQLite UNIQUE constraint detection
    let isSQLiteDuplicateEmail = errorString.contains("UNIQUE constraint failed: users.email")

    if isPostgreSQLDuplicateEmail || isSQLiteDuplicateEmail {
        throw AuthenticationError.emailAlreadyExists
    }
    throw error
}

// After migration, signUp method should look like:
func signUp(_ req: Request) async throws -> Auth.SignUp.Response {
    let signUpRequest = try req.content.decode(Auth.SignUp.Request.self)

    // Hash password
    let hashedPassword = try await req.password.async.hash(signUpRequest.password)

    // Create user model with normalized email
    let user = UserAccountModel(
        email: signUpRequest.email.lowercased(),
        password: hashedPassword,
        firstName: signUpRequest.firstName.nilOrNonEmptyValue,
        lastName: signUpRequest.lastName.nilOrNonEmptyValue
    )

    // Create with duplicate detection
    do {
        try await req.repositories.users.create(user)
    } catch {
        // ... exact error detection logic from above
    }

    // Generate refresh token
    let tokenValue = req.services.randomGenerator.generate(bits: 256)
    let userID = try user.requireID()
    let refreshToken = RefreshTokenModel(
        value: SHA256.hash(tokenValue),
        userID: userID
    )
    try await req.repositories.refreshTokens.create(refreshToken)

    // Send verification email (non-blocking)
    try await sendEmailVerification(for: user, on: req)

    return Auth.SignUp.Response(
        token: try .init(token: tokenValue, user: user, on: req),
        user: try .init(from: user)
    )
}
```

### Success Criteria

- [ ] Build succeeds
- [ ] SignUp endpoint works correctly
- [ ] Duplicate email detection works for PostgreSQL
- [ ] Duplicate email detection works for SQLite
- [ ] Email verification is sent
- [ ] All auth tests pass

### Verification

```bash
swift build
swift test --filter Auth
```

### Notes

- CRITICAL: Duplicate email detection uses string pattern matching - preserve exactly
- Email verification failure is non-fatal (graceful degradation)
- Password hashing uses `req.password.async.hash()` (Vapor built-in)
- Token value is generated, then SHA256 hashed for storage
