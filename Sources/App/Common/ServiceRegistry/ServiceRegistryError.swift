import Vapor

/// Comprehensive error types for ServiceRegistry operations with detailed diagnostics.
///
/// This error enum provides specific error cases for all ServiceRegistry operations,
/// enabling precise error handling and debugging. Each error includes contextual
/// information to help developers identify and resolve issues quickly.
///
/// ## Error Categories
/// - **Registration Errors**: Issues during service registration and setup
/// - **Resolution Errors**: Problems when resolving services from the registry
/// - **Lifecycle Errors**: Failures during service startup or shutdown
/// - **Dependency Errors**: Issues with service dependencies and circular references
///
/// ## Usage Example
/// ```swift
/// do {
///     let service = try await registry.resolveRequired(MyService.self)
/// } catch let error as ServiceRegistryError {
///     switch error {
///     case .serviceNotFound(let type):
///         logger.error("Service not registered: \(type)")
///     case .circularDependency(let chain):
///         logger.error("Circular dependency: \(chain.joined(separator: " -> "))")
///     case .serviceInitializationFailed(let type, let underlying):
///         logger.error("Failed to initialize \(type): \(underlying)")
///     case .factoryTypeMismatch(let type):
///         logger.error("Factory type mismatch for \(type)")
///     }
/// }
/// ```
public enum ServiceRegistryError: AppError {
    /// Service type not found in the registry.
    ///
    /// This error occurs when attempting to resolve a service that hasn't been
    /// registered with the ServiceRegistry. The error includes the type name
    /// for debugging purposes.
    ///
    /// **Common Causes:**
    /// - Service not registered during application startup
    /// - Typo in service type name
    /// - Service provider not included in setup
    ///
    /// - Parameter type: String representation of the missing service type
    case serviceNotFound(String)
    
    /// Service initialization failed during factory execution.
    ///
    /// This error wraps underlying initialization failures that occur when
    /// creating service instances through factory functions. It preserves
    /// the original error for detailed debugging.
    ///
    /// **Common Causes:**
    /// - Missing dependencies required by service constructor
    /// - Configuration errors (database connection, API keys, etc.)
    /// - Resource unavailability (network, file system, etc.)
    ///
    /// - Parameters:
    ///   - type: String representation of the service type that failed
    ///   - underlying: The original error that caused the initialization failure
    case serviceInitializationFailed(String, Error)
    
    /// Circular dependency detected in service resolution chain.
    ///
    /// This error prevents infinite loops when services depend on each other
    /// in a circular manner. The error includes the complete dependency chain
    /// to help identify where the cycle occurs.
    ///
    /// **Resolution Strategy:**
    /// - Review service dependencies to break circular references
    /// - Use lazy initialization or optional dependencies
    /// - Restructure services to eliminate cycles
    ///
    /// - Parameter chain: Array of service type names showing the circular dependency path
    case circularDependency([String])
    
    /// Factory function type mismatch during service registration or resolution.
    ///
    /// This error occurs when the stored factory function doesn't match the
    /// expected type signature. This typically indicates a programming error
    /// in service registration or type casting.
    ///
    /// **Common Causes:**
    /// - Incorrect factory function signature during registration
    /// - Type system inconsistencies in generic constraints
    /// - Manual factory casting errors
    ///
    /// - Parameter type: String representation of the service type with type mismatch
    case factoryTypeMismatch(String)
    
    /// Service registry initialization timed out.
    ///
    /// This error occurs when the service registry setup takes longer than the
    /// configured timeout period. This prevents indefinite blocking during
    /// application startup and provides clear feedback about setup issues.
    ///
    /// **Common Causes:**
    /// - Slow external service connections during startup
    /// - Deadlock in service initialization
    /// - Resource contention during concurrent test execution
    ///
    /// - Parameter message: Descriptive message about the timeout condition
    case initializationTimeout(String)
    
    // MARK: - AppError Conformance
    
    /// HTTP status code for ServiceRegistry errors.
    ///
    /// All ServiceRegistry errors are considered internal server errors since
    /// they represent system configuration issues rather than client errors.
    public var status: HTTPResponseStatus {
        .internalServerError
    }
    
    /// Human-readable error description with context.
    ///
    /// Provides detailed error messages that include relevant context for
    /// debugging and logging purposes.
    public var reason: String {
        switch self {
        case .serviceNotFound(let type):
            return "Service '\(type)' not found in registry. Ensure the service is registered during application startup."
        case .serviceInitializationFailed(let type, let error):
            return "Failed to initialize service '\(type)': \(error.localizedDescription)"
        case .circularDependency(let chain):
            return "Circular dependency detected in service resolution: \(chain.joined(separator: " → "))"
        case .factoryTypeMismatch(let type):
            return "Factory function type mismatch for service '\(type)'. Verify factory signature matches service type."
        case .initializationTimeout(let message):
            return "Service registry initialization timed out: \(message)"
        }
    }
    
    /// Unique identifier for each error type.
    ///
    /// Used for error categorization, logging, and monitoring systems.
    /// Each identifier corresponds to a specific error condition.
    public var identifier: String {
        switch self {
        case .serviceNotFound:
            return "service_not_found"
        case .serviceInitializationFailed:
            return "service_initialization_failed"
        case .circularDependency:
            return "circular_dependency"
        case .factoryTypeMismatch:
            return "factory_type_mismatch"
        case .initializationTimeout:
            return "initialization_timeout"
        }
    }
    
    /// HTTP status for compatibility with existing error handling.
    ///
    /// Maps ServiceRegistry errors to appropriate HTTP status codes
    /// for web request processing.
    public var suggestedHTTPStatus: HTTPStatus {
        .internalServerError
    }
}