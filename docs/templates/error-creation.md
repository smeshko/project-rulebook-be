---
title: "Error Creation Template"
description: "Guide for creating custom error types in project-rulebook-be"
author: Claude
date: 2026-01-23
---

# Error Creation Template

## When to Use

- Creating domain-specific errors for API responses
- Defining service-level errors with detailed messages
- Building errors that integrate with Vapor's error handling

## Quick Reference

| Pattern | Use Case | Protocol |
|---------|----------|----------|
| IdentifiableError | Domain errors for API responses | `IdentifiableError` |
| LocalizedError | Service errors with detailed messages | `LocalizedError` |
| AppError | Full Vapor integration with HTTP status | `AbortError`, `DebuggableError` |

## Pattern 1: IdentifiableError (Domain Errors)

Best for domain errors that become API responses with consistent identifiers.

Create `Sources/App/Entities/Errors/{Domain}Error.swift`:

```swift
import Vapor

// MARK: - {Domain} Error

public enum {Domain}Error: String, IdentifiableError {
    case itemNotFound = "item_not_found"
    case itemAlreadyExists = "item_already_exists"
    case invalidInput = "invalid_input"
    case operationFailed = "operation_failed"
    case unauthorized = "unauthorized"

    public var identifier: String {
        rawValue
    }

    public var reason: String {
        switch self {
        case .itemNotFound:
            return "The requested item was not found"
        case .itemAlreadyExists:
            return "An item with that identifier already exists"
        case .invalidInput:
            return "The provided input is invalid"
        case .operationFailed:
            return "The operation could not be completed"
        case .unauthorized:
            return "You are not authorized to perform this action"
        }
    }
}
```

**Key features:**
- `String` raw values for API consistency
- `identifier` returns snake_case raw value
- `reason` provides user-friendly messages

## Pattern 2: LocalizedError (Service Errors)

Best for internal service errors with detailed context for logging.

```swift
import Foundation
import Vapor

// MARK: - {Service} Error

enum {Service}Error: Error, LocalizedError {
    case authenticationFailed
    case rateLimitExceeded(retryAfter: TimeInterval?)
    case serverError(HTTPStatus)
    case requestFailed(Error)
    case invalidResponse(String)
    case timeout

    var errorDescription: String? {
        switch self {
        case .authenticationFailed:
            return "{Service} authentication failed. Check your API key."

        case .rateLimitExceeded(let retryAfter):
            if let delay = retryAfter {
                return "{Service} rate limit exceeded. Retry after \(Int(delay)) seconds."
            }
            return "{Service} rate limit exceeded. Try again later."

        case .serverError(let status):
            return "{Service} server error (HTTP \(status.code)). Try again later."

        case .requestFailed(let error):
            return "{Service} request failed: \(error.localizedDescription)"

        case .invalidResponse(let details):
            return "{Service} returned invalid response: \(details)"

        case .timeout:
            return "{Service} request timed out. Try again."
        }
    }
}
```

**Key features:**
- Associated values for context (retry delays, status codes, etc.)
- Detailed `errorDescription` for logging
- Non-technical language suitable for logs

## Pattern 3: AppError (Full Vapor Integration)

Best for errors that need full HTTP response control.

```swift
import Vapor

// MARK: - App Error Protocol

public protocol AppError: AbortError, DebuggableError {}

// MARK: - {Module} Error

enum {Module}Error: AppError {
    case resourceNotFound(UUID)
    case validationFailed(String)
    case duplicateEntry(String)
    case insufficientPermissions

    var status: HTTPResponseStatus {
        switch self {
        case .resourceNotFound:
            return .notFound
        case .validationFailed:
            return .badRequest
        case .duplicateEntry:
            return .conflict
        case .insufficientPermissions:
            return .forbidden
        }
    }

    var reason: String {
        switch self {
        case .resourceNotFound(let id):
            return "Resource with ID \(id) not found"
        case .validationFailed(let message):
            return "Validation failed: \(message)"
        case .duplicateEntry(let field):
            return "A record with this \(field) already exists"
        case .insufficientPermissions:
            return "You do not have permission to perform this action"
        }
    }

    var identifier: String {
        switch self {
        case .resourceNotFound:
            return "resource_not_found"
        case .validationFailed:
            return "validation_failed"
        case .duplicateEntry:
            return "duplicate_entry"
        case .insufficientPermissions:
            return "insufficient_permissions"
        }
    }

    // DebuggableError
    var source: ErrorSource? { nil }
}
```

## HTTP Status Mapping Reference

| Error Type | HTTP Status | Use Case |
|------------|-------------|----------|
| Not found | 404 | Resource doesn't exist |
| Already exists / Conflict | 409 | Duplicate creation |
| Invalid input / Bad request | 400 | Validation failure |
| Unauthorized | 401 | Missing authentication |
| Forbidden | 403 | Insufficient permissions |
| Rate limited | 429 | Too many requests |
| Server error | 500 | Internal failures |
| Service unavailable | 503 | External service down |

## Usage in Controllers

```swift
func getItem(_ req: Request) async throws -> Item.Response {
    guard let id = req.parameters.get("id", as: UUID.self) else {
        throw {Module}Error.validationFailed("Invalid ID format")
    }

    guard let item = try await req.repositories.items.find(id: id) else {
        throw {Module}Error.resourceNotFound(id)
    }

    return Item.Response(from: item)
}
```

## Error Translation Pattern

For translating database errors to domain errors:

```swift
do {
    try await req.repositories.users.create(user)
} catch {
    let errorString = String(reflecting: error)

    // PostgreSQL unique constraint
    let isPostgreSQLDuplicate = errorString.contains("sqlState: 23505") &&
        (errorString.contains("uq:users.email") || errorString.contains("Key (email)"))

    // SQLite unique constraint
    let isSQLiteDuplicate = errorString.contains("UNIQUE constraint failed: users.email")

    if isPostgreSQLDuplicate || isSQLiteDuplicate {
        throw AuthenticationError.emailAlreadyExists
    }
    throw error
}
```

## Implementation Checklist

### IdentifiableError
- [ ] Enum with `String` raw values (snake_case)
- [ ] Conforms to `IdentifiableError`
- [ ] `identifier` returns raw value
- [ ] `reason` provides user-friendly message
- [ ] All cases have consistent snake_case identifiers

### LocalizedError
- [ ] Conforms to `Error` and `LocalizedError`
- [ ] Associated values for context where needed
- [ ] `errorDescription` implemented for all cases
- [ ] Messages are non-technical and actionable

### AppError
- [ ] Conforms to `AbortError` and `DebuggableError`
- [ ] `status` returns appropriate HTTP status code
- [ ] `reason` for response body
- [ ] `identifier` for error code
- [ ] `source` property (can return nil)

## Codebase Examples

- `Sources/App/Entities/Errors/AuthenticationError.swift` - IdentifiableError pattern
- `Sources/App/Entities/Errors/UserError.swift` - Domain errors
- `Sources/App/Entities/Errors/OpenAIError.swift` - LocalizedError for service
- `Sources/App/Common/Errors/AppError.swift` - Protocol definition

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Generic error messages | Be specific about what failed and why |
| Technical jargon | Users don't understand "UNIQUE constraint" |
| Missing context | Include IDs, field names in messages |
| Wrong HTTP status | Match status to error type (404 for not found, etc.) |
| Exposing internals | Don't leak stack traces or implementation details |
| Inconsistent identifiers | Use snake_case consistently for all identifiers |
