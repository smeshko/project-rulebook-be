# Vapor Service Creation Template

This template provides a standardized approach for creating new services in the Vapor application, following established patterns from the codebase.

## Service Template

```swift
import Vapor

// MARK: - 1. Service Protocol Definition

/// Protocol defining the interface for [ServiceName] operations.
///
/// This service provides [brief description of service purpose].
///
/// ## Key Features
/// - [Feature 1]
/// - [Feature 2]
protocol [ServiceName]Service {
    
    // Define service methods
    func [methodName]([parameters]) async throws -> [ReturnType]
    
    /// Returns a service instance configured for the specific request context.
    /// - Parameter request: The current request context
    /// - Returns: A service instance configured for the request
    func `for`(_ request: Request) -> [ServiceName]Service
}

// MARK: - 2. Application & Request Accessors

extension Application.Services {
    /// Application-level service accessor
    var [serviceName]: Application.Service<[ServiceName]Service> {
        .init(application: application)
    }
}

extension Request.Services {
    /// Request-level service accessor (uses ServiceCache for synchronous access)
    var [serviceName]: [ServiceName]Service {
        // Use pre-resolved service from ServiceCache for immediate synchronous access
        request.application.serviceCache.[serviceName]Service.for(request)
    }
}

// MARK: - 3. Service Provider Extension

extension Application.Service.Provider where ServiceType == [ServiceName]Service {
    /// Registers [ProviderName] as the [ServiceName] service provider.
    static var [providerName]: Self {
        .init {
            $0.services.[serviceName].use { [ImplementationName](app: $0) }
        }
    }
}

// MARK: - 4. Service Implementation

/// [ProviderName] implementation of the [ServiceName] service protocol.
///
/// This service provides [detailed description].
struct [ImplementationName]: [ServiceName]Service {
    /// The Vapor application instance for accessing configuration and logging.
    let app: Application
    
    // Add any private properties needed (e.g., configuration, retry settings)
    private let maxRetries: Int = 3
    private let baseDelay: TimeInterval = 1.0
    
    /// HTTP headers for API requests (if needed for external services).
    private var headers: HTTPHeaders {
        do {
            let config = try app.configuration.services
            return [
                "Content-Type": "application/json",
                "Authorization": "Bearer \(config.[apiKeyName])",
            ]
        } catch {
            app.logger.error("Failed to get [ServiceName] configuration: \(error)")
            // Fallback to environment variable if needed
            return [
                "Content-Type": "application/json",
                "Authorization": "Bearer \(Environment.[envVarName])",
            ]
        }
    }
    
    // Implement protocol methods
    func [methodName]([parameters]) async throws -> [ReturnType] {
        // Implementation with error handling and retry logic if needed
        // For external services, consider using withRetry pattern from OpenAIService
    }
    
    /// Returns a service instance configured for the specific request context.
    func `for`(_ request: Request) -> [ServiceName]Service {
        Self(app: request.application)
    }
}

// MARK: - 5. ServiceLifecycle Implementation (Optional)

extension [ImplementationName]: ServiceLifecycle {
    /// Initializes the service during application startup.
    func startup(_ app: Application) async throws {
        do {
            let config = try app.configuration.services
            
            // Validate configuration
            guard !config.[configKey].isEmpty else {
                throw ConfigurationError.missingRequired(
                    key: "[CONFIG_KEY]", 
                    suggestion: "Set the [service] configuration in environment variables"
                )
            }
            
            // Test connectivity (if external service)
            // Perform any initialization needed
            
            app.logger.info("[ServiceName] service started successfully", metadata: [
                "config_key": .string(config.[configKey])
            ])
            
        } catch {
            app.logger.error("[ServiceName] service startup failed", metadata: [
                "error": .string(error.localizedDescription)
            ])
            throw error
        }
    }
    
    /// Gracefully shuts down the service during application termination.
    func shutdown(_ app: Application) async throws {
        // Clean up resources if needed
        app.logger.info("[ServiceName] service shut down gracefully")
    }
}

// MARK: - 6. ServiceHealthCheck Implementation (Optional)

extension [ImplementationName]: ServiceHealthCheck {
    /// Performs a health check to determine if service is operating correctly.
    func isHealthy() async -> Bool {
        do {
            // Perform lightweight health check
            // For external services: test API connectivity
            // For internal services: verify critical resources
            
            // Example for external API:
            let config = try app.configuration.services
            let response = try await app.client.get(
                URI(string: config.[healthEndpoint]),
                headers: headers
            )
            
            return response.status == .ok
            
        } catch {
            app.logger.warning("[ServiceName] health check failed", metadata: [
                "error": .string(error.localizedDescription)
            ])
            return false
        }
    }
    
    /// Provides a human-readable name for this service's health check.
    func healthCheckName() -> String {
        "[ServiceName] Service"
    }
}

// MARK: - 7. Service Registration (in ExternalServiceProvider.swift)

// Add to ExternalServiceProvider.register():
if !registry.isRegistered([ServiceName]Service.self) {
    registry.register([ServiceName]Service.self) { app in
        [ImplementationName](app: app)
    }
}

// MARK: - 8. ServiceCache Integration (in ServiceCache.swift)

// Add to ServiceCache class:

// Property declaration:
private let _[serviceName]Service: [ServiceName]Service

// In init() parameters:
[serviceName]Service: [ServiceName]Service,

// In init() body:
self._[serviceName]Service = [serviceName]Service

// Accessor property:
var [serviceName]Service: [ServiceName]Service {
    _[serviceName]Service
}

// MARK: - 9. ServiceCache Initialization (in ServiceRegistryIntegration.swift)

// Add to createServiceCache() in ServiceRegistryIntegration.swift:
let [serviceName]Service = try await serviceRegistry.resolveRequired([ServiceName]Service.self)

// Include in ServiceCache initialization:
let serviceCache = ServiceCache(
    // ... other services ...
    [serviceName]Service: [serviceName]Service
)
```

## Usage Checklist

When creating a new service, follow these steps:

1. **Protocol Definition**
   - [ ] Define service protocol with clear method signatures
   - [ ] Include `for(_ request:)` method for request-scoped instances
   - [ ] Add comprehensive documentation

2. **Service Accessors**
   - [ ] Add `Application.Services` extension for app-level access
   - [ ] Add `Request.Services` extension using ServiceCache

3. **Provider Extension**
   - [ ] Create provider extension for service registration
   - [ ] Use descriptive provider name (e.g., `.openAI`, `.brevo`)

4. **Implementation**
   - [ ] Implement service protocol methods
   - [ ] Add proper error handling and logging
   - [ ] Include retry logic for external services if needed

5. **Lifecycle (Optional)**
   - [ ] Implement `ServiceLifecycle` for services needing startup/shutdown
   - [ ] Validate configuration during startup
   - [ ] Test connectivity for external services

6. **Health Check (Optional)**
   - [ ] Implement `ServiceHealthCheck` for monitorable services
   - [ ] Keep health checks lightweight (< 100ms ideal)
   - [ ] Provide descriptive health check name

7. **Registration**
   - [ ] Add to `ExternalServiceProvider.register()`
   - [ ] Check if already registered (for testing compatibility)

8. **Cache Integration**
   - [ ] Add private property to ServiceCache
   - [ ] Update ServiceCache init parameters and body
   - [ ] Add public accessor property

9. **Cache Initialization**
   - [ ] Resolve service in `createServiceCache()` method in `ServiceRegistryIntegration.swift`
   - [ ] Include in ServiceCache initialization

## Example Services for Reference

- **Complex External Service**: `Sources/App/Services/LLM/OpenAIService.swift`
  - Full lifecycle implementation
  - Retry logic with exponential backoff
  - Comprehensive health checks
  
- **Simple External Service**: `Sources/App/Services/Email/BrevoClient.swift`
  - Basic lifecycle for configuration validation
  - Simple health check implementation
  
- **Internal Services**: Check services in `Sources/App/Services/` directory
  - Various patterns for different service types

## Key Patterns to Follow

1. **Dependency Injection**: Always use DI, never static methods
2. **Request Scoping**: Use `for(_ request:)` for request-specific instances
3. **Configuration**: Access via `app.configuration.services`
4. **Error Handling**: Throw descriptive errors, use proper logging
5. **ServiceCache**: Pre-resolve for synchronous access patterns
6. **Testing**: Ensure all services are mockable

## Notes

- Services are for external integrations or cross-cutting concerns
- Module-specific logic stays within module boundaries
- Follow the Three-Strike Rule: create abstractions only after third occurrence
- Work WITH Vapor conventions, not against them