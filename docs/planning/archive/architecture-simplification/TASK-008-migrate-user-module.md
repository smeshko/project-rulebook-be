## TASK-008: Migrate User Module Use Cases

---
**Status:** OPEN
**Branch:** refactoring/architecture-simplification
**Type:** REFACTOR
**Phase:** 2
**Depends On:** T007
---

### Overview

Migrate all 4 User use cases to UserController: GetCurrentUser, ListUsers, UpdateUserProfile, DeleteUserAccount.

**Files:**
- `Sources/App/Modules/User/Controllers/UserController.swift` (modify)
- `Sources/App/Modules/User/UseCases/GetCurrentUserUseCase.swift` (reference, delete)
- `Sources/App/Modules/User/UseCases/ListUsersUseCase.swift` (reference, delete)
- `Sources/App/Modules/User/UseCases/UpdateUserProfileUseCase.swift` (reference, delete)
- `Sources/App/Modules/User/UseCases/DeleteUserAccountUseCase.swift` (reference, delete)

### Implementation Steps

**Commit 1: Move all User use case logic to UserController**
- [ ] GetCurrentUserUseCase: Simply return authenticated user (trivial)
- [ ] ListUsersUseCase: Return all users (admin only)
- [ ] UpdateUserProfileUseCase: Update user fields
- [ ] DeleteUserAccountUseCase: Delete user with cascade (tokens)
- [ ] Update to use `req.repositories.*` syntax

### Code Example

```swift
// GetCurrentUser (trivial - just returns authenticated user)
func getCurrentUser(_ req: Request) async throws -> User.Detail.Response {
    let user = try req.auth.require(UserAccountModel.self)
    return try .init(from: user)
}

// ListUsers (admin only)
func listUsers(_ req: Request) async throws -> [User.Detail.Response] {
    let users = try await req.repositories.users.all()
    return try users.map { try .init(from: $0) }
}

// UpdateUserProfile
func updateProfile(_ req: Request) async throws -> User.Detail.Response {
    let user = try req.auth.require(UserAccountModel.self)
    let updateRequest = try req.content.decode(User.Update.Request.self)

    if let firstName = updateRequest.firstName {
        user.firstName = firstName.nilOrNonEmptyValue
    }
    if let lastName = updateRequest.lastName {
        user.lastName = lastName.nilOrNonEmptyValue
    }

    try await req.repositories.users.update(user)
    return try .init(from: user)
}

// DeleteUserAccount (with cascade)
func deleteAccount(_ req: Request) async throws -> HTTPStatus {
    let user = try req.auth.require(UserAccountModel.self)
    let userID = try user.requireID()

    // Cascade delete: tokens first, then user
    try await req.repositories.refreshTokens.delete(forUserID: userID)
    try await req.repositories.emailTokens.delete(forUserID: userID)
    try await req.repositories.passwordTokens.delete(forUserID: userID)
    try await req.repositories.users.delete(id: userID)

    return .ok
}
```

### Success Criteria

- [ ] Build succeeds
- [ ] GetCurrentUser returns authenticated user
- [ ] ListUsers returns all users (admin only)
- [ ] UpdateProfile updates user fields
- [ ] DeleteAccount cascades to delete all related tokens
- [ ] All user tests pass

### Verification

```bash
swift build
swift test --filter User
```

### Notes

- GetCurrentUserUseCase is trivial - just returns the authenticated user
- DeleteUserAccount has cascade logic - must delete tokens before user
- UpdateProfile preserves nil handling for optional fields
