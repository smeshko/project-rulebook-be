# Vapor Service Creation Template

This template provides a standardized approach for creating new services in the Vapor application, following the simplified property-based architecture.

## Service Template

### 1. Define Service Protocol

```swift
import Vapor

/// Protocol defining the interface for [ServiceName] operations.
///
/// This service provides [brief description of service purpose].
protocol [ServiceName]ServiceInterface {
    func [methodName]([parameters]) async throws -> [ReturnType]
}
```

### 2. Implement Service

```swift
/// [ServiceName] implementation.
///
/// This service provides [detailed description].
final class [ServiceName]Service: [ServiceName]ServiceInterface {
    private let app: Application

    init(app: Application) {
        self.app = app
    }

    func [methodName]([parameters]) async throws -> [ReturnType] {
        // Implementation
    }
}
```

### 3. Add Application Storage

Add to `Sources/App/Common/Extensions/Application+Services.swift`:

```swift
// In ServiceStorageContainer class:
var [serviceName]Service: [ServiceName]ServiceInterface?

// In Application extension:
var [serviceName]Service: [ServiceName]ServiceInterface {
    get { serviceStorage.[serviceName]Service! }
    set { serviceStorage.[serviceName]Service = newValue }
}
```

### 4. Add Request Accessor

Add to `Sources/App/Common/Extensions/Request+Services.swift`:

```swift
// In RequestServices struct:
var [serviceName]: [ServiceName]ServiceInterface {
    app.[serviceName]Service
}
```

### 5. Initialize in Application Setup

Add to `Sources/App/Entrypoint/Application-Setup.swift`:

```swift
// In setupServices() function:
app.[serviceName]Service = [ServiceName]Service(app: app)
```

## Usage

```swift
// In any route handler:
func handleRequest(_ req: Request) async throws -> Response {
    let result = try await req.services.[serviceName].[methodName](...)
    return response
}
```

## Usage Checklist

When creating a new service:

1. **Protocol Definition**
   - [ ] Define service protocol with clear method signatures
   - [ ] Add comprehensive documentation

2. **Implementation**
   - [ ] Implement service protocol methods
   - [ ] Add proper error handling and logging

3. **Application Storage**
   - [ ] Add optional property to `ServiceStorageContainer`
   - [ ] Add computed property to `Application` extension

4. **Request Accessor**
   - [ ] Add accessor property to `RequestServices` struct

5. **Initialization**
   - [ ] Initialize service in `setupServices()` function

6. **Testing**
   - [ ] Create mock implementation for testing
   - [ ] Inject mock via `app.[serviceName]Service = MockService()`

## Example Services for Reference

- **External API Service**: `Sources/App/Services/LLM/LLMService.swift`
- **Email Service**: `Sources/App/Services/Email/EmailService.swift`
- **Cache Service**: `Sources/App/Services/Cache/CacheService.swift`

## Key Patterns

1. **Protocol-First**: Define interface before implementation
2. **Property-Based DI**: Use `req.services.*` pattern
3. **Testability**: All services are mockable via property injection
4. **Simplicity**: No complex DI frameworks, just properties

## Notes

- Services are for external integrations or cross-cutting concerns
- Module-specific logic stays within module boundaries (controllers)
- Follow the Three-Strike Rule: create abstractions only after third occurrence
- Work WITH Vapor conventions, not against them
