---
title: "Service Creation Template"
description: "Guide for creating services in project-rulebook-be"
author: Claude
date: 2026-01-23
---

# Service Creation Template

## When to Use

- Integrating with external APIs (OpenAI, Brevo, etc.)
- Creating shared functionality across modules
- Abstracting complex operations behind a clean interface

## Quick Reference

| Component | Description |
|-----------|-------------|
| Protocol Location | `Sources/App/Services/{Service}/{Service}Service.swift` or `{Service}ServiceInterface.swift` |
| Implementation | Same file or `{Service}ServiceImpl.swift` |
| Storage | `Sources/App/Common/Extensions/Application+Services.swift` |
| Request Extension | `Sources/App/Common/Extensions/Request+Services.swift` |
| Access Pattern | `req.services.{serviceName}` |

## Directory Structure

```text
Sources/App/Services/{ServiceName}/
├── {ServiceName}Service.swift        # Protocol + extensions
├── {ServiceName}ServiceImpl.swift    # Implementation (optional, can be in same file)
└── Models/                           # Service-specific types (optional)
    └── {ServiceName}Request.swift
```

## Code Template

### Step 1: Define the Protocol

```swift
import Vapor

// MARK: - Protocol

/// Protocol defining the {ServiceName} service interface.
protocol {ServiceName}Service: Sendable {

    /// Brief description of what this method does.
    /// - Parameter input: Description of parameter
    /// - Returns: Description of return value
    /// - Throws: {ServiceName}Error on failure
    func primaryMethod(input: String) async throws -> OutputType

    /// Returns a service instance for the request context.
    func `for`(_ request: Request) -> {ServiceName}Service
}

// MARK: - Application Extension

extension Application.Services {
    var {serviceName}: Application.Service<{ServiceName}Service> {
        .init(application: application)
    }
}
```

### Step 2: Implement the Service

```swift
import Vapor

// MARK: - Implementation

struct {ServiceName}ServiceImpl: {ServiceName}Service {
    let app: Application

    // MARK: - Configuration

    private let maxRetries: Int = 3
    private let baseDelay: TimeInterval = 1.0

    // MARK: - Protocol Implementation

    func primaryMethod(input: String) async throws -> OutputType {
        return try await withRetry(maxAttempts: maxRetries) { attempt in
            try await performRequest(input: input, attempt: attempt)
        }
    }

    func `for`(_ request: Request) -> {ServiceName}Service {
        Self(app: request.application)
    }

    // MARK: - Private Helpers

    private func performRequest(input: String, attempt: Int) async throws -> OutputType {
        let response = try await app.client.post(
            URI(string: "https://api.example.com/endpoint"),
            headers: headers
        ) { req in
            try req.content.encode(RequestBody(input: input))
        }

        switch response.status {
        case .ok:
            return try response.content.decode(OutputType.self)
        case .tooManyRequests:
            throw {ServiceName}Error.rateLimitExceeded
        case .unauthorized:
            throw {ServiceName}Error.authenticationFailed
        default:
            throw {ServiceName}Error.requestFailed(response.status)
        }
    }

    private func withRetry<T>(
        maxAttempts: Int,
        operation: (Int) async throws -> T
    ) async throws -> T {
        var lastError: Error?

        for attempt in 1...maxAttempts {
            do {
                return try await operation(attempt)
            } catch {
                lastError = error
                if attempt < maxAttempts {
                    let delay = baseDelay * pow(2.0, Double(attempt - 1))
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }

        throw lastError ?? {ServiceName}Error.unknown
    }

    private var headers: HTTPHeaders {
        var headers = HTTPHeaders()
        headers.add(name: .contentType, value: "application/json")
        headers.add(name: .authorization, value: "Bearer \(app.configuration.apiKey)")
        return headers
    }
}
```

### Step 3: Register in Application Storage

In `Sources/App/Common/Extensions/Application+Services.swift`:

```swift
// Add to ServiceStorageContainer
final class ServiceStorageContainer: @unchecked Sendable {
    // ... existing services ...
    var {serviceName}Service: {ServiceName}Service?
}

// Add Application extension
extension Application {
    var {serviceName}Service: {ServiceName}Service {
        get { serviceStorage.{serviceName}Service! }
        set { serviceStorage.{serviceName}Service = newValue }
    }
}
```

### Step 4: Add Request Extension

In `Sources/App/Common/Extensions/Request+Services.swift`:

```swift
struct RequestServices: @unchecked Sendable {
    let app: Application

    // ... existing services ...

    var {serviceName}: {ServiceName}Service {
        app.{serviceName}Service.for(Request(application: app, on: app.eventLoopGroup.next()))
    }
}
```

Or if using direct access pattern:

```swift
var {serviceName}: {ServiceName}Service {
    app.{serviceName}Service
}
```

### Step 5: Initialize in Setup

In `Sources/App/Application-Setup.swift`:

```swift
func setupServices(_ app: Application) throws {
    // ... existing services ...
    app.{serviceName}Service = {ServiceName}ServiceImpl(app: app)
}
```

## Error Type

Create `Sources/App/Entities/Errors/{ServiceName}Error.swift`:

```swift
import Foundation

enum {ServiceName}Error: Error, LocalizedError {
    case authenticationFailed
    case rateLimitExceeded
    case requestFailed(HTTPStatus)
    case invalidResponse(String)
    case unknown

    var errorDescription: String? {
        switch self {
        case .authenticationFailed:
            return "{ServiceName} authentication failed. Check your API key."
        case .rateLimitExceeded:
            return "{ServiceName} rate limit exceeded. Try again later."
        case .requestFailed(let status):
            return "{ServiceName} request failed with status \(status.code)."
        case .invalidResponse(let details):
            return "{ServiceName} returned invalid response: \(details)"
        case .unknown:
            return "{ServiceName} encountered an unknown error."
        }
    }
}
```

## Usage in Controllers

```swift
func processWithService(_ req: Request) async throws -> Response {
    // Access service via req.services
    let result = try await req.services.{serviceName}.primaryMethod(input: "data")
    return Response(result: result)
}
```

## Implementation Checklist

- [ ] Protocol defined with `Sendable` conformance
- [ ] All I/O methods use `async throws`
- [ ] `for(_ request:)` method implemented for request context
- [ ] Retry logic with exponential backoff for external APIs
- [ ] Error handling for all HTTP status codes
- [ ] Added to `ServiceStorageContainer` in Application+Services.swift
- [ ] Application extension property added
- [ ] Request extension property added to `RequestServices`
- [ ] Initialized in `Application-Setup.swift`
- [ ] Custom error type created
- [ ] Configuration via `app.configuration` (not hardcoded)

## Codebase Examples

- `Sources/App/Services/LLM/LLMService.swift` - Protocol with Request extension
- `Sources/App/Services/LLM/OpenAIService.swift` - Full implementation with retry
- `Sources/App/Services/Email/EmailService.swift` - Simple service pattern
- `Sources/App/Services/Cache/CacheService.swift` - Generic interface
- `Sources/App/Common/Extensions/Application+Services.swift` - Registration pattern
- `Sources/App/Common/Extensions/Request+Services.swift` - Access pattern

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Missing `Sendable` | Services must be thread-safe for concurrent access |
| No retry logic | External APIs can fail transiently - implement retries |
| Hardcoded config | Use `app.configuration.*` for API keys and URLs |
| Missing logging | Log errors and retries for debugging |
| Wrong storage pattern | Use `serviceStorage` container, not direct `storage[Key]` |
| Forgetting `for(_ request:)` | Required for request-scoped service instances |
