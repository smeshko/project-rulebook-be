import NIOCore
import NIOConcurrencyHelpers
import Vapor

/// Registry for managing application-wide aspects.
///
/// AspectRegistry provides centralized management of aspects, allowing
/// dynamic registration and configuration of cross-cutting concerns.
///
/// ## Features
/// - **Centralized Management**: Single point of aspect configuration
/// - **Priority Ordering**: Aspects can be registered with priorities
/// - **Dynamic Configuration**: Add or remove aspects at runtime
/// - **Type Safety**: Compile-time verification of aspect types
///
/// ## Usage Example
/// ```swift
/// // Register in Application extension
/// extension Application {
///     var aspectRegistry: AspectRegistry {
///         get { storage[AspectRegistryKey.self] ?? AspectRegistry() }
///         set { storage[AspectRegistryKey.self] = newValue }
///     }
/// }
///
/// // Register aspects
/// app.aspectRegistry.register(LoggingAspect(), priority: 100)
/// app.aspectRegistry.register(SecurityAspect(), priority: 200)
/// ```
public final class AspectRegistry: @unchecked Sendable {
    /// Registered aspects with their priorities.
    private var registrations: [(aspect: any Aspect, priority: Int)] = []
    
    /// Lock for thread-safe access to registrations.
    private let lock = NIOLock()
    
    /// Creates a new empty aspect registry.
    public init() {}
    
    /// Registers an aspect with a specific priority.
    ///
    /// Higher priority aspects execute first in the before phase
    /// and last in the after phase.
    ///
    /// - Parameters:
    ///   - aspect: The aspect to register
    ///   - priority: The execution priority (higher = earlier execution)
    public func register(_ aspect: any Aspect, priority: Int = 0) {
        lock.withLock {
            registrations.append((aspect, priority))
            // Sort by priority (descending)
            registrations.sort { $0.priority > $1.priority }
        }
    }
    
    /// Removes all registered aspects.
    public func clear() {
        lock.withLock {
            registrations.removeAll()
        }
    }
    
    /// Gets all registered aspects in execution order.
    ///
    /// - Returns: Array of aspects sorted by priority
    public func all() -> [any Aspect] {
        lock.withLock {
            registrations.map { $0.aspect }
        }
    }
    
    /// Creates middleware configured with all registered aspects.
    ///
    /// - Returns: AspectMiddleware with registered aspects
    public func middleware() -> AspectMiddleware {
        AspectMiddleware(aspects: all())
    }
}

// MARK: - Storage Keys

/// Storage key for AspectRegistry in Application.
private struct AspectRegistryKey: StorageKey {
    typealias Value = AspectRegistry
}

/// Storage key for AspectContext in Request.
private struct RequestAspectContextKey: StorageKey {
    typealias Value = AspectContext
}

// MARK: - Application Extensions

public extension Application {
    /// The application's aspect registry.
    var aspectRegistry: AspectRegistry {
        get {
            if let registry = storage[AspectRegistryKey.self] {
                return registry
            }
            let registry = AspectRegistry()
            storage[AspectRegistryKey.self] = registry
            return registry
        }
        set {
            storage[AspectRegistryKey.self] = newValue
        }
    }
}

// MARK: - Request Extensions

public extension Request {
    /// The current aspect context for this request.
    var aspectContext: AspectContext {
        get {
            storage[RequestAspectContextKey.self] ?? AspectContext()
        }
        set {
            storage[RequestAspectContextKey.self] = newValue
        }
    }
}
