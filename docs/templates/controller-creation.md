---
title: "Controller Creation Template"
description: "Guide for creating HTTP endpoint handlers in project-rulebook-be"
author: Claude
date: 2026-01-23
---

# Controller Creation Template

## When to Use

- Creating HTTP endpoint handlers
- Implementing business logic for API routes
- Processing requests and returning responses

## Quick Reference

| Component | Description |
|-----------|-------------|
| Location | `Sources/App/Modules/{Module}/Controllers/{Module}Controller.swift` |
| Protocol | None (struct) |
| Access Services | `req.services.{serviceName}` |
| Access Repositories | `req.repositories.{entityName}` |
| Authentication | `req.auth.require(TokenPayload.self)` or `req.auth.require(UserAccountModel.self)` |

## Code Template

```swift
import Vapor

// MARK: - Controller

/// Controller for {description of feature}.
struct {Module}Controller {

    // MARK: - Public Endpoints

    /// Brief description of what this endpoint does.
    /// - Parameter req: The incoming HTTP request
    /// - Returns: Response DTO
    /// - Throws: {Module}Error if operation fails
    func handleAction(_ req: Request) async throws -> {Module}.Action.Response {
        // 1. Decode and validate request
        let input = try req.content.decode({Module}.Action.Request.self)

        // 2. Execute business logic via services
        let result = try await req.services.someService.process(input.field)

        // 3. Persist via repositories if needed
        try await req.repositories.items.create(result)

        // 4. Return response DTO
        return {Module}.Action.Response(from: result)
    }

    // MARK: - Protected Endpoints

    /// Endpoint requiring authentication.
    func protectedAction(_ req: Request) async throws -> {Module}.Protected.Response {
        // 1. Get authenticated user
        let user = try req.auth.require(UserAccountModel.self)

        // 2. Execute authorized logic
        let items = try await req.repositories.items.findAll(forUserID: user.requireID())

        // 3. Return response
        return {Module}.Protected.Response(items: items.map { .init(from: $0) })
    }
}
```

## Common Patterns

### Request Validation

```swift
func createItem(_ req: Request) async throws -> Item.Create.Response {
    // Validate content structure
    try Item.Create.Request.validate(content: req)
    let input = try req.content.decode(Item.Create.Request.self)

    // Additional validation with guard
    guard !input.name.isEmpty else {
        throw {Module}Error.invalidInput
    }

    // Continue with business logic...
}
```

### Caching Pattern

```swift
func cachedAction(_ req: Request) async throws -> ResponseType {
    let input = try req.content.decode(RequestType.self)

    // 1. Generate cache key
    let cacheKey = req.services.cacheKeyGenerator.generateKey(for: input.field)

    // 2. Check cache first (note: positional parameters, try await)
    if let cached: ResponseType = try await req.services.cache.get(cacheKey, as: ResponseType.self) {
        return cached
    }

    // 3. Generate fresh result
    let result = try await req.services.llm.generate(input: input.prompt)

    // 4. Cache result (ttl in seconds, nil for default)
    try await req.services.cache.set(cacheKey, value: result, ttl: 3600)

    return result
}
```

### Database Error Handling

```swift
func createUser(_ req: Request) async throws -> User.Response {
    let input = try req.content.decode(User.Create.Request.self)

    let user = UserAccountModel(
        email: input.email.lowercased(),
        password: try await req.password.async.hash(input.password)
    )

    do {
        try await req.repositories.users.create(user)
    } catch {
        // Handle unique constraint violations
        let errorString = String(reflecting: error)

        let isPostgreSQLDuplicate = errorString.contains("sqlState: 23505") &&
            (errorString.contains("uq:users.email") || errorString.contains("Key (email)"))

        let isSQLiteDuplicate = errorString.contains("UNIQUE constraint failed: users.email")

        if isPostgreSQLDuplicate || isSQLiteDuplicate {
            throw AuthenticationError.emailAlreadyExists
        }
        throw error
    }

    return User.Response(from: user)
}
```

### Logging Pattern

```swift
func loggedAction(_ req: Request) async throws -> ResponseType {
    let clientIP = req.services.ipExtractor.extractClientIP(from: req)

    req.logger.info("Processing request", metadata: [
        "client_ip": .string(clientIP),
        "endpoint": .string("action")
    ])

    do {
        let result = try await performAction(req)
        req.logger.info("Request completed successfully")
        return result
    } catch {
        req.logger.error("Request failed", metadata: [
            "error": .string(error.localizedDescription)
        ])
        throw error
    }
}
```

### Path Parameters

```swift
func getById(_ req: Request) async throws -> Item.Response {
    guard let id = req.parameters.get("id", as: UUID.self) else {
        throw Abort(.badRequest, reason: "Invalid ID format")
    }

    guard let item = try await req.repositories.items.find(id: id) else {
        throw {Module}Error.itemNotFound
    }

    return Item.Response(from: item)
}
```

### Refresh Token Pattern

```swift
func refreshAccessToken(_ req: Request) async throws -> Auth.TokenRefresh.Response {
    let input = try req.content.decode(Auth.TokenRefresh.Request.self)

    // Hash token for lookup (tokens stored hashed)
    let hashedToken = SHA256.hash(input.refreshToken)

    guard let storedToken = try await req.repositories.refreshTokens.find(token: hashedToken) else {
        throw AuthenticationError.refreshTokenOrUserNotFound
    }

    guard storedToken.expiresAt > .now else {
        throw AuthenticationError.refreshTokenHasExpired
    }

    // Delete old token (single-use)
    try await req.repositories.refreshTokens.delete(id: storedToken.requireID())

    // Generate new token
    let newTokenValue = req.services.randomGenerator.generate(bits: 256)
    let newToken = RefreshTokenModel(
        value: SHA256.hash(newTokenValue),
        userID: storedToken.$user.id
    )
    try await req.repositories.refreshTokens.create(newToken)

    // Return new tokens
    return Auth.TokenRefresh.Response(
        refreshToken: newTokenValue,
        accessToken: try req.jwt.sign(TokenPayload(with: storedToken.user))
    )
}
```

## Method Flow Pattern

```text
1. Decode request       → HTTP concern (Content.decode)
2. Validate input       → Guard clauses, .validate()
3. Authenticate         → req.auth.require() (if protected)
4. Execute logic        → Service calls (req.services.*)
5. Persist data         → Repository calls (req.repositories.*)
6. Return response      → DTO transformation
```

## Implementation Checklist

- [ ] Controller is a `struct` (not class)
- [ ] Methods use `async throws`
- [ ] Clear numbered steps in comments
- [ ] Input validated with guard clauses
- [ ] Uses custom error types (not generic `Abort`)
- [ ] Services accessed via `req.services.*`
- [ ] Repositories accessed via `req.repositories.*`
- [ ] Cache calls use `try await` and positional parameters
- [ ] Sensitive data (passwords) never logged or returned
- [ ] Database errors properly caught and translated

## Codebase Examples

- `Sources/App/Modules/Auth/Controllers/AuthController.swift` - Full auth flow with tokens
- `Sources/App/Modules/RulesGeneration/Controller/RulesGenerationController.swift` - Caching pattern

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Missing `try await` on cache calls | Cache methods throw - always use `try await` |
| Using `Abort(.badRequest)` | Create typed errors like `{Module}Error.invalidInput` |
| Direct database access | Use repositories: `req.repositories.items` |
| Missing input validation | Always validate before processing |
| Logging sensitive data | Never log passwords, tokens, or PII |
