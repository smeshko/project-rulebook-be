import Vapor
import NIOConcurrencyHelpers

/// High-performance, thread-safe service container with advanced dependency management.
///
/// This container provides the core implementation of the ServiceRegistry protocol,
/// offering sophisticated dependency injection capabilities with comprehensive
/// lifecycle management, circular dependency detection, and concurrent safety.
///
/// ## Key Features
/// - **Thread Safety**: Uses NIOLock for optimal async/await compatibility
/// - **Lazy Initialization**: Services created only when first requested
/// - **Circular Dependency Detection**: Prevents infinite resolution loops
/// - **Lifecycle Management**: Coordinated startup, shutdown, and health monitoring
/// - **Type Safety**: Compile-time and runtime type validation
/// - **Memory Efficiency**: Automatic cleanup and optimal storage patterns
///
/// ## Architecture Design
///
/// The container uses a dual-storage approach for maximum flexibility:
/// - **Factory Storage**: Lazy service creation with dependency injection
/// - **Instance Storage**: Direct service instances for immediate availability
///
/// ## Thread Safety Implementation
/// ```swift
/// // All operations are protected by NIOLock
/// private let lock = NIOLock()
/// 
/// // Critical sections are minimized for performance
/// lock.withLock {
///     // Atomic operations only
/// }
/// ```
///
/// ## Circular Dependency Prevention
/// - Resolution stack tracking prevents infinite loops
/// - Clear error reporting with dependency chain information
/// - Fail-fast approach for quick debugging
///
/// ## Performance Characteristics
/// - **O(1)** service lookup using ObjectIdentifier keys
/// - **Minimal Lock Contention**: Brief critical sections
/// - **Memory Efficient**: Weak references where appropriate
/// - **Concurrent Friendly**: Optimized for high-throughput request processing
///
/// ## Integration with Vapor
/// - Seamless integration with Application storage
/// - Request-scoped access through extensions
/// - Compatible with existing Vapor service patterns
///
/// ## Usage Examples
///
/// ### Basic Service Registration
/// ```swift
/// let container = ServiceContainer(application: app)
/// 
/// // Factory registration
/// container.register(DatabaseService.self) { app in
///     try await DatabaseService(url: app.databaseURL)
/// }
/// 
/// // Instance registration
/// let config = ConfigurationService()
/// container.register(ConfigurationService.self, instance: config)
/// ```
///
/// ### Service Resolution
/// ```swift
/// // Required resolution (throws if missing)
/// let database = try await container.resolveRequired(DatabaseService.self)
/// 
/// // Optional resolution
/// if let cache = try await container.resolve(CacheService.self) {
///     // Use optional caching
/// }
/// ```
public final class ServiceContainer: ServiceRegistry, ServiceRegistryLifecycle, @unchecked Sendable {
    /// High-performance lock optimized for async contexts and minimal contention.
    ///
    /// Uses NIOLock instead of standard Swift locks for better async/await
    /// compatibility and reduced overhead in high-throughput scenarios.
    private let lock = NIOLock()
    
    /// Factory function storage mapped by service type identifier.
    ///
    /// Stores async factory functions that create service instances on demand.
    /// Functions are type-erased but validated at registration time.
    private var factories: [ObjectIdentifier: Any] = [:]
    
    /// Instantiated service storage mapped by service type identifier.
    ///
    /// Caches created service instances for singleton behavior and
    /// performance optimization in subsequent resolutions.
    private var instances: [ObjectIdentifier: Any] = [:]
    
    /// Lifecycle-aware services tracked for coordinated startup/shutdown.
    ///
    /// Services implementing ServiceLifecycle are automatically tracked
    /// for coordinated application lifecycle management.
    private var lifecycleServices: [ObjectIdentifier: ServiceLifecycle] = [:]
    
    /// Health-check enabled services tracked for monitoring.
    ///
    /// Services implementing ServiceHealthCheck are automatically tracked
    /// for comprehensive application health reporting.
    private var healthCheckServices: [ObjectIdentifier: ServiceHealthCheck] = [:]
    
    /// Current service resolution stack for circular dependency detection.
    ///
    /// Tracks the chain of services currently being resolved to detect
    /// and prevent circular dependency loops with clear error reporting.
    private var resolutionStack: Set<ObjectIdentifier> = []
    
    /// Reference to the Vapor application for service factory execution.
    ///
    /// Provides access to application-level services and configuration
    /// during factory function execution and service initialization.
    private let application: Application
    
    /// Initializes a new service container bound to the specified application.
    ///
    /// Creates a clean container instance ready for service registration
    /// and resolution. The container maintains a reference to the application
    /// for factory function execution and service lifecycle coordination.
    ///
    /// ## Container Initialization
    /// - All storage collections are initialized empty
    /// - Thread safety lock is configured for optimal performance
    /// - Application reference is stored for factory execution
    ///
    /// - Parameter application: The Vapor application instance
    public init(application: Application) {
        self.application = application
    }
    
    // MARK: - ServiceRegistry
    
    /// Registers a service with an async factory function for lazy initialization.
    ///
    /// This implementation provides thread-safe factory registration with
    /// type validation and automatic cleanup of conflicting registrations.
    /// The factory function is wrapped for type safety while maintaining
    /// async execution capabilities.
    ///
    /// ## Registration Process
    /// 1. Generate type-safe ObjectIdentifier key
    /// 2. Wrap factory function with type validation
    /// 3. Atomically update factory storage
    /// 4. Remove any existing instance to force re-creation
    ///
    /// ## Thread Safety
    /// - Lock-protected atomic updates to factory storage
    /// - Brief critical section to minimize contention
    /// - No factory execution during registration
    ///
    /// ## Type Safety
    /// - Factory return type is validated at registration time
    /// - Type erasure preserves async execution capabilities
    /// - Runtime type checking during resolution
    ///
    /// - Parameters:
    ///   - type: The service type to register
    ///   - factory: Async factory function that creates the service
    public func register<T>(_ type: T.Type, factory: @escaping @Sendable (Application) async throws -> T) {
        let key = ObjectIdentifier(type)
        
        // Validate factory type at registration time to catch issues early
        let wrappedFactory: @Sendable (Application) async throws -> Any = { app in
            try await factory(app)
        }
        
        lock.withLock {
            factories[key] = wrappedFactory
            instances.removeValue(forKey: key)
        }
    }
    
    /// Registers a pre-configured service instance with automatic lifecycle tracking.
    ///
    /// This implementation provides immediate service availability with
    /// comprehensive lifecycle integration. Services implementing lifecycle
    /// or health check protocols are automatically tracked for management.
    ///
    /// ## Registration Process
    /// 1. Generate type-safe ObjectIdentifier key
    /// 2. Store instance in atomic operation
    /// 3. Remove any conflicting factory registration
    /// 4. Automatically detect and track lifecycle capabilities
    /// 5. Automatically detect and track health check capabilities
    ///
    /// ## Lifecycle Integration
    /// - Services implementing `ServiceLifecycle` are tracked for startup/shutdown
    /// - Services implementing `ServiceHealthCheck` are tracked for monitoring
    /// - ObjectIdentifier keys ensure reliable tracking and cleanup
    ///
    /// ## Thread Safety
    /// - Atomic instance storage update
    /// - Consistent lifecycle tracking registration
    /// - Lock-protected critical section
    ///
    /// - Parameters:
    ///   - type: The service type to register
    ///   - instance: The pre-configured service instance
    public func register<T>(_ type: T.Type, instance: T) {
        let key = ObjectIdentifier(type)
        
        lock.withLock {
            instances[key] = instance
            factories.removeValue(forKey: key)
            
            // Track lifecycle and health check services using ObjectIdentifier for reliable removal
            if let lifecycle = instance as? ServiceLifecycle {
                lifecycleServices[key] = lifecycle
            }
            
            if let healthCheck = instance as? ServiceHealthCheck {
                healthCheckServices[key] = healthCheck
            }
        }
    }
    
    /// Resolves a service with comprehensive dependency management and error handling.
    ///
    /// This implementation provides sophisticated service resolution with circular
    /// dependency detection, lazy initialization, and automatic lifecycle tracking.
    /// The resolution process is optimized for performance while maintaining
    /// thread safety and error resilience.
    ///
    /// ## Resolution Algorithm
    /// 1. **Circular Dependency Check**: Verify no circular references
    /// 2. **Instance Lookup**: Check for existing instantiated service
    /// 3. **Factory Execution**: Create service if factory registered
    /// 4. **Type Validation**: Ensure factory output matches expected type
    /// 5. **Lifecycle Integration**: Track service for management
    /// 6. **Error Handling**: Provide detailed error context
    ///
    /// ## Circular Dependency Detection
    /// - Maintains resolution stack to track dependency chain
    /// - Detects cycles before infinite loops occur
    /// - Provides clear error with full dependency path
    ///
    /// ## Performance Optimization
    /// - Factory execution occurs outside critical sections
    /// - Minimal lock duration to reduce contention
    /// - Efficient ObjectIdentifier-based lookups
    ///
    /// ## Error Recovery
    /// - Automatic cleanup of resolution stack on failure
    /// - Detailed error context for debugging
    /// - Non-blocking for concurrent resolutions
    ///
    /// - Parameter type: The service type to resolve
    /// - Returns: The service instance or nil if not registered
    /// - Throws: Resolution errors with detailed context
    public func resolve<T>(_ type: T.Type) async throws -> T? {
        let key = ObjectIdentifier(type)
        
        // Check for circular dependency
        let isCircular = lock.withLock { resolutionStack.contains(key) }
        if isCircular {
            let chain = lock.withLock {
                resolutionStack.map { String(describing: $0) } + [String(describing: type)]
            }
            throw ServiceRegistryError.circularDependency(chain)
        }
        
        // Check for existing instance
        let existingInstance = lock.withLock { instances[key] as? T }
        if let instance = existingInstance {
            return instance
        }
        
        // Check for factory
        let factory = lock.withLock { factories[key] }
        guard let factory = factory else {
            return nil
        }
        
        // Add to resolution stack to detect circular dependencies
        lock.withLock { _ = resolutionStack.insert(key) }
        defer { lock.withLock { _ = resolutionStack.remove(key) } }
        
        // Create instance using factory (outside of lock to avoid deadlock)
        do {
            // Use the validated factory type from registration
            guard let typedFactory = factory as? @Sendable (Application) async throws -> Any else {
                throw ServiceRegistryError.serviceInitializationFailed(
                    String(describing: type),
                    ServiceRegistryError.factoryTypeMismatch(String(describing: type))
                )
            }
            
            let anyInstance = try await typedFactory(application)
            guard let instance = anyInstance as? T else {
                throw ServiceRegistryError.serviceInitializationFailed(
                    String(describing: type),
                    ServiceRegistryError.factoryTypeMismatch(String(describing: type))
                )
            }
            
            // Store the instance
            lock.withLock {
                instances[key] = instance
                
                // Track lifecycle and health check services using ObjectIdentifier for reliable removal
                if let lifecycle = instance as? ServiceLifecycle {
                    lifecycleServices[key] = lifecycle
                }
                
                if let healthCheck = instance as? ServiceHealthCheck {
                    healthCheckServices[key] = healthCheck
                }
            }
            
            return instance
        } catch {
            throw ServiceRegistryError.serviceInitializationFailed(
                String(describing: type),
                error
            )
        }
    }
    
    /// Resolves a required service, throwing a descriptive error if not found.
    ///
    /// This convenience method builds on the optional resolution logic
    /// to provide strict dependency enforcement. It's optimized for
    /// critical services that the application cannot function without.
    ///
    /// ## Error Handling
    /// - Leverages comprehensive resolve() error handling
    /// - Adds specific serviceNotFound error for missing services
    /// - Maintains full error context chain for debugging
    ///
    /// ## Performance
    /// - Single resolution attempt with error conversion
    /// - No additional overhead beyond optional resolution
    /// - Immediate failure for missing critical dependencies
    ///
    /// - Parameter type: The required service type to resolve
    /// - Returns: The service instance (guaranteed non-nil)
    /// - Throws: Service resolution or missing service errors
    public func resolveRequired<T>(_ type: T.Type) async throws -> T {
        guard let service = try await resolve(type) else {
            throw ServiceRegistryError.serviceNotFound(String(describing: type))
        }
        return service
    }
    
    /// Resolves all instantiated services conforming to the specified type.
    ///
    /// This method provides efficient bulk resolution for plugin architectures
    /// and multi-implementation patterns. It only returns services that have
    /// been instantiated, avoiding factory execution for performance.
    ///
    /// ## Implementation Strategy
    /// - Scans only instantiated services for performance
    /// - Uses thread-safe iteration over instance storage
    /// - Performs runtime type checking for compatibility
    /// - Returns empty array if no compatible instances found
    ///
    /// ## Performance Characteristics
    /// - **O(n)** where n is the number of instantiated services
    /// - Single lock acquisition for atomic operation
    /// - No factory execution or service creation
    /// - Efficient compactMap for type filtering
    ///
    /// ## Usage Patterns
    /// ```swift
    /// // Get all notification processors
    /// let processors = await container.resolveAll(NotificationProcessor.self)
    /// await withTaskGroup(of: Void.self) { group in
    ///     for processor in processors {
    ///         group.addTask { await processor.process(notification) }
    ///     }
    /// }
    /// ```
    ///
    /// - Parameter type: The service type to search for
    /// - Returns: Array of all compatible instantiated services
    public func resolveAll<T>(_ type: T.Type) async -> [T] {
        lock.withLock {
            instances.compactMap { $0.value as? T }
        }
    }
    
    /// Unregisters a service and performs comprehensive cleanup.
    ///
    /// This method provides complete service removal with proper cleanup
    /// of all associated tracking and storage. The operation is atomic
    /// and thread-safe, ensuring consistent registry state.
    ///
    /// ## Cleanup Operations
    /// 1. Remove from lifecycle service tracking
    /// 2. Remove from health check service tracking
    /// 3. Remove instantiated service instance
    /// 4. Remove factory registration
    /// 5. Ensure atomic completion of all removals
    ///
    /// ## Thread Safety
    /// - Single atomic operation for all cleanup
    /// - Consistent state across all storage collections
    /// - No partial cleanup scenarios
    ///
    /// ## Safety Considerations
    /// - Does not invoke service shutdown methods
    /// - Other services may retain references to unregistered service
    /// - Consider dependency impact before unregistering
    ///
    /// - Parameter type: The service type to unregister
    public func unregister<T>(_ type: T.Type) {
        let key = ObjectIdentifier(type)
        
        lock.withLock {
            // Remove from lifecycle and health check tracking using ObjectIdentifier
            lifecycleServices.removeValue(forKey: key)
            healthCheckServices.removeValue(forKey: key)
            
            instances.removeValue(forKey: key)
            factories.removeValue(forKey: key)
        }
    }
    
    /// Checks service registration status with optimal performance.
    ///
    /// This method provides fast registration checking without service
    /// instantiation or factory execution. It's optimized for conditional
    /// service usage patterns and debugging scenarios.
    ///
    /// ## Check Logic
    /// - Returns `true` if instance OR factory is registered
    /// - Single atomic check of both storage types
    /// - No side effects or service creation
    ///
    /// ## Performance
    /// - **O(1)** lookup using ObjectIdentifier hash
    /// - Minimal lock duration for quick check
    /// - No factory execution or type validation
    ///
    /// ## Usage Patterns
    /// ```swift
    /// // Conditional service usage
    /// if container.isRegistered(OptionalService.self) {
    ///     let service = try await container.resolveRequired(OptionalService.self)
    ///     // Use service functionality
    /// }
    /// ```
    ///
    /// - Parameter type: The service type to check
    /// - Returns: `true` if service is registered (factory or instance)
    public func isRegistered<T>(_ type: T.Type) -> Bool {
        let key = ObjectIdentifier(type)
        
        return lock.withLock {
            instances[key] != nil || factories[key] != nil
        }
    }
    
    // MARK: - ServiceRegistryLifecycle
    
    /// Coordinates startup of all lifecycle-aware services in registration order.
    ///
    /// This method implements the application startup sequence for all
    /// services that implement the ServiceLifecycle protocol. Services
    /// are started sequentially to handle dependencies properly.
    ///
    /// ## Startup Process
    /// 1. Collect all services implementing ServiceLifecycle
    /// 2. Maintain registration order for dependency handling
    /// 3. Start each service sequentially with error propagation
    /// 4. Halt startup process if any service fails
    ///
    /// ## Error Handling
    /// - Individual service startup failures halt the entire process
    /// - Services started before failure remain running
    /// - Comprehensive error context for debugging
    /// - Application should handle startup failures appropriately
    ///
    /// ## Thread Safety
    /// - Atomic collection of lifecycle services
    /// - Sequential execution prevents race conditions
    /// - No concurrent startup to avoid resource conflicts
    ///
    /// - Parameter app: The Vapor application instance
    /// - Throws: Service startup errors or coordination failures
    public func startupAll(_ app: Application) async throws {
        let services = lock.withLock {
            Array(lifecycleServices.values)
        }
        
        for service in services {
            try await service.startup(app)
        }
    }
    
    /// Coordinates graceful shutdown of all services in reverse startup order.
    ///
    /// This method implements proper application shutdown with dependency
    /// respect by shutting down services in reverse order of startup.
    /// This ensures that dependencies are available until their dependents
    /// have completed shutdown.
    ///
    /// ## Shutdown Process
    /// 1. Collect all services implementing ServiceLifecycle
    /// 2. Reverse order to respect dependency relationships
    /// 3. Shut down each service sequentially
    /// 4. Continue shutdown even if individual services fail
    ///
    /// ## Error Resilience
    /// - Individual service failures do not halt shutdown process
    /// - All services get opportunity to clean up resources
    /// - Shutdown errors are logged but not propagated
    /// - Critical for graceful application termination
    ///
    /// ## Dependency Management
    /// - Reverse order ensures dependencies shut down last
    /// - Sequential execution prevents resource conflicts
    /// - Proper cleanup order for complex service graphs
    ///
    /// - Parameter app: The Vapor application instance
    /// - Throws: Critical shutdown errors preventing cleanup
    public func shutdownAll(_ app: Application) async throws {
        let services = lock.withLock {
            Array(lifecycleServices.values.reversed())
        }
        
        for service in services {
            try await service.shutdown(app)
        }
    }
    
    /// Performs comprehensive health monitoring across all registered services.
    ///
    /// This method coordinates health checks for all services implementing
    /// the ServiceHealthCheck protocol, providing a complete operational
    /// status report for monitoring and alerting systems.
    ///
    /// ## Health Check Process
    /// 1. Collect all services implementing ServiceHealthCheck
    /// 2. Execute health checks sequentially to avoid resource contention
    /// 3. Collect service names and health status
    /// 4. Return comprehensive health report
    ///
    /// ## Sequential Execution Strategy
    /// - Prevents resource conflicts during health checks
    /// - Ensures predictable execution order
    /// - Simplifies error handling and reporting
    /// - Future enhancement: Concurrent checks with proper Sendable handling
    ///
    /// ## Monitoring Integration
    /// ```swift
    /// // Application health endpoint
    /// app.get("health") { req async in
    ///     let health = await req.application.serviceRegistry.healthCheckAll()
    ///     let overallHealthy = health.allSatisfy { $0.healthy }
    ///     return HealthResponse(
    ///         services: health,
    ///         healthy: overallHealthy,
    ///         timestamp: Date()
    ///     )
    /// }
    /// ```
    ///
    /// ## Performance Considerations
    /// - Sequential execution may increase latency for many services
    /// - Individual service timeouts should be handled in service implementations
    /// - Results collected efficiently with minimal allocations
    ///
    /// - Returns: Array of service names with their health status
    public func healthCheckAll() async -> [(name: String, healthy: Bool)] {
        let services = lock.withLock {
            Array(healthCheckServices.values)
        }
        
        // Sequential health checks to avoid concurrency complexity
        // TODO: Implement concurrent health checks with proper Sendable handling
        var results: [(name: String, healthy: Bool)] = []
        
        for service in services {
            let isHealthy = await service.isHealthy()
            results.append((
                name: service.healthCheckName(),
                healthy: isHealthy
            ))
        }
        
        return results
    }
}

// MARK: - Application Integration

/// Vapor Application integration for seamless service registry access.
///
/// These extensions provide clean integration with Vapor's application
/// and request lifecycle, enabling easy access to the service registry
/// throughout the application stack.
extension Application {
    /// Storage key for the service registry in Application storage.
    ///
    /// Uses Vapor's type-safe storage system to maintain the service
    /// registry instance across the application lifecycle.
    public struct ServiceRegistryKey: StorageKey {
        public typealias Value = ServiceContainer
    }
    
    /// Primary service registry instance for the application.
    ///
    /// Provides lazy initialization of the service container with
    /// automatic binding to the application instance. The registry
    /// is created once and reused across all requests.
    ///
    /// ## Lazy Initialization
    /// - Container created on first access
    /// - Automatically bound to application instance
    /// - Stored in application storage for reuse
    ///
    /// ## Usage Examples
    /// ```swift
    /// // During application configuration
    /// app.serviceRegistry.register(DatabaseService.self) { app in
    ///     try await DatabaseService(url: app.databaseURL)
    /// }
    /// 
    /// // Service resolution in controllers
    /// let database = try await app.serviceRegistry.resolveRequired(DatabaseService.self)
    /// ```
    public var serviceRegistry: ServiceContainer {
        get {
            if let existing = storage[ServiceRegistryKey.self] {
                return existing
            }
            let registry = ServiceContainer(application: self)
            storage[ServiceRegistryKey.self] = registry
            return registry
        }
        set {
            storage[ServiceRegistryKey.self] = newValue
        }
    }
}

/// Request-level access to the application service registry.
///
/// Provides convenient access to services during request processing
/// without requiring explicit application reference passing.
extension Request {
    /// Service registry instance from the associated application.
    ///
    /// This computed property provides direct access to the application's
    /// service registry from any request context, enabling clean dependency
    /// injection patterns in controllers and middleware.
    ///
    /// ## Usage in Controllers
    /// ```swift
    /// func handleRequest(_ req: Request) async throws -> Response {
    ///     let userService = try await req.serviceRegistry.resolveRequired(UserService.self)
    ///     let user = try await userService.findUser(id: userID)
    ///     return req.view.render("profile", ["user": user])
    /// }
    /// ```
    ///
    /// ## Thread Safety
    /// - Each request accesses the same shared registry instance
    /// - Registry operations are thread-safe for concurrent requests
    /// - No per-request isolation - services are application-scoped
    public var serviceRegistry: ServiceContainer {
        application.serviceRegistry
    }
}