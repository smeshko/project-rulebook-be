import Vapor

/// Core dependency injection protocol providing type-safe service registration and resolution.
///
/// This protocol defines the fundamental service registry contract that enables
/// sophisticated dependency injection patterns throughout the Vapor application.
/// It provides a type-safe, thread-safe foundation for managing service lifecycles
/// and resolving dependencies with comprehensive error handling.
///
/// ## Key Features
/// - **Type Safety**: Compile-time type checking for service registration and resolution
/// - **Factory Support**: Lazy initialization through factory functions with async support
/// - **Instance Registration**: Direct instance registration for pre-configured services
/// - **Circular Dependency Detection**: Automatic detection and prevention of dependency cycles
/// - **Thread Safety**: Safe concurrent access across multiple request processing threads
/// - **Error Handling**: Comprehensive error reporting for debugging and monitoring
///
/// ## Service Registration Patterns
///
/// The registry supports two primary registration patterns:
///
/// ### Factory Registration
/// ```swift
/// // Register with async factory function
/// registry.register(UserService.self) { app in
///     try await UserService(database: app.db)
/// }
/// ```
///
/// ### Instance Registration
/// ```swift
/// // Register pre-configured instance
/// let userService = UserService(database: database)
/// registry.register(UserService.self, instance: userService)
/// ```
///
/// ## Service Resolution Patterns
///
/// ### Required Resolution
/// ```swift
/// // Throws error if service not found
/// let userService = try await registry.resolveRequired(UserService.self)
/// ```
///
/// ### Optional Resolution
/// ```swift
/// // Returns nil if service not found
/// let userService = try await registry.resolve(UserService.self)
/// ```
///
/// ## Architecture Benefits
/// - **Testability**: Easy service mocking for comprehensive testing
/// - **Modularity**: Clean separation of concerns and loose coupling
/// - **Flexibility**: Runtime service configuration and replacement
/// - **Scalability**: Efficient service instantiation and memory management
///
/// ## Implementation Requirements
/// - All methods must be thread-safe for concurrent request processing
/// - Factory functions must be marked `@Sendable` for async safety
/// - Circular dependency detection must prevent infinite resolution loops
/// - Error handling must provide clear debugging information
public protocol ServiceRegistry: Sendable {
    /// Registers a service with a factory function for lazy initialization.
    ///
    /// This method enables lazy service instantiation where services are created
    /// only when first requested. The factory function receives the Application
    /// instance for accessing other services and configuration.
    ///
    /// ## Usage Example
    /// ```swift
    /// registry.register(DatabaseService.self) { app in
    ///     try await DatabaseService(
    ///         url: app.environment.databaseURL,
    ///         logger: app.logger
    ///     )
    /// }
    /// ```
    ///
    /// ## Thread Safety
    /// - Factory registration is thread-safe and atomic
    /// - Factory execution occurs outside critical sections to prevent deadlocks
    /// - Multiple concurrent requests for the same service will create only one instance
    ///
    /// - Parameters:
    ///   - type: The service type to register (protocol or concrete type)
    ///   - factory: Async factory function that creates the service instance
    func register<T>(_ type: T.Type, factory: @escaping @Sendable (Application) async throws -> T)
    /// Registers a pre-configured service instance for immediate availability.
    ///
    /// This method is ideal for services that are already configured or
    /// for singleton services that should be shared across the application.
    /// The instance is stored and returned for all future resolution requests.
    ///
    /// ## Usage Example
    /// ```swift
    /// let configService = ConfigurationService(environment: app.environment)
    /// registry.register(ConfigurationService.self, instance: configService)
    /// ```
    ///
    /// ## Lifecycle Integration
    /// - Services implementing `ServiceLifecycle` are automatically tracked
    /// - Services implementing `ServiceHealthCheck` are included in health monitoring
    /// - Instance registration replaces any existing factory for the same type
    ///
    /// - Parameters:
    ///   - type: The service type to register (protocol or concrete type)
    ///   - instance: The pre-configured service instance to register
    func register<T>(_ type: T.Type, instance: T)
    /// Resolves a service instance, returning nil if the service is not registered.
    ///
    /// This method provides optional service resolution that gracefully handles
    /// missing services without throwing errors. If a factory is registered,
    /// it will be executed to create the service instance.
    ///
    /// ## Resolution Logic
    /// 1. Check for existing instance in the registry
    /// 2. If not found, check for registered factory
    /// 3. Execute factory if available, storing the result
    /// 4. Return the resolved instance or nil if not registered
    ///
    /// ## Usage Example
    /// ```swift
    /// if let cacheService = try await registry.resolve(CacheService.self) {
    ///     // Use optional caching functionality
    ///     cacheService.store(key: "data", value: data)
    /// }
    /// ```
    ///
    /// ## Error Conditions
    /// - Throws `ServiceRegistryError.circularDependency` if dependency cycle detected
    /// - Throws `ServiceRegistryError.serviceInitializationFailed` if factory execution fails
    /// - Returns `nil` if service is not registered (no error thrown)
    ///
    /// - Parameter type: The service type to resolve
    /// - Returns: The service instance or nil if not registered
    /// - Throws: Service resolution errors (excluding missing service)
    func resolve<T>(_ type: T.Type) async throws -> T?
    /// Resolves a required service instance, throwing an error if not found.
    ///
    /// This method provides strict service resolution that enforces the presence
    /// of required dependencies. Use this for critical services that the application
    /// cannot function without.
    ///
    /// ## Usage Example
    /// ```swift
    /// // This will throw if DatabaseService is not registered
    /// let database = try await registry.resolveRequired(DatabaseService.self)
    /// let users = try await database.findUsers()
    /// ```
    ///
    /// ## Error Conditions
    /// - Throws `ServiceRegistryError.serviceNotFound` if service is not registered
    /// - Throws `ServiceRegistryError.circularDependency` if dependency cycle detected
    /// - Throws `ServiceRegistryError.serviceInitializationFailed` if factory execution fails
    ///
    /// - Parameter type: The service type to resolve
    /// - Returns: The service instance (guaranteed to be non-nil)
    /// - Throws: Service resolution or missing service errors
    func resolveRequired<T>(_ type: T.Type) async throws -> T
    /// Resolves all registered instances that conform to the specified type.
    ///
    /// This method is useful for plugin architectures or when multiple
    /// implementations of a protocol need to be processed together.
    /// Only returns already instantiated services, does not execute factories.
    ///
    /// ## Usage Example
    /// ```swift
    /// // Get all registered notification handlers
    /// let handlers = await registry.resolveAll(NotificationHandler.self)
    /// for handler in handlers {
    ///     await handler.process(notification)
    /// }
    /// ```
    ///
    /// ## Implementation Notes
    /// - Only returns services that have been instantiated (not factory registrations)
    /// - Performs type checking to filter compatible instances
    /// - Returns empty array if no compatible instances found
    /// - Operation is thread-safe and non-blocking
    ///
    /// - Parameter type: The service type to search for
    /// - Returns: Array of all compatible service instances
    func resolveAll<T>(_ type: T.Type) async -> [T]
    /// Removes a service registration and cleans up associated resources.
    ///
    /// This method completely removes a service from the registry, including
    /// any factory functions, instances, and lifecycle tracking. Use with
    /// caution as other services may depend on the unregistered service.
    ///
    /// ## Usage Example
    /// ```swift
    /// // Remove a service during testing or reconfiguration
    /// registry.unregister(TestService.self)
    /// ```
    ///
    /// ## Cleanup Operations
    /// - Removes factory registration if present
    /// - Removes instance registration if present
    /// - Removes from lifecycle tracking
    /// - Removes from health check monitoring
    ///
    /// ## Safety Considerations
    /// - Does not call shutdown methods on removed services
    /// - Other services may retain references to the unregistered service
    /// - Consider service dependencies before unregistering
    ///
    /// - Parameter type: The service type to unregister
    func unregister<T>(_ type: T.Type)
    /// Checks if a service type is registered in the registry.
    ///
    /// This method provides a quick way to check service availability
    /// without attempting resolution. Useful for conditional service
    /// usage and debugging registration issues.
    ///
    /// ## Usage Example
    /// ```swift
    /// if registry.isRegistered(CacheService.self) {
    ///     let cache = try await registry.resolveRequired(CacheService.self)
    ///     // Use caching functionality
    /// } else {
    ///     // Fallback to non-cached operation
    /// }
    /// ```
    ///
    /// ## Check Logic
    /// - Returns `true` if either factory or instance is registered
    /// - Returns `false` if no registration exists for the type
    /// - Does not execute factories or instantiate services
    /// - Thread-safe and non-blocking operation
    ///
    /// - Parameter type: The service type to check
    /// - Returns: `true` if the service is registered, `false` otherwise
    func isRegistered<T>(_ type: T.Type) -> Bool
}

/// Protocol for managing service lifecycle operations across the application.
///
/// This protocol extends the basic service registry with comprehensive lifecycle
/// management capabilities, enabling coordinated startup, shutdown, and health
/// monitoring of all registered services.
///
/// ## Key Features
/// - **Coordinated Startup**: Sequential startup of all lifecycle-aware services
/// - **Graceful Shutdown**: Reverse-order shutdown for proper resource cleanup
/// - **Health Monitoring**: Centralized health checking across all services
/// - **Error Propagation**: Comprehensive error handling during lifecycle operations
///
/// ## Startup Process
/// Services implementing `ServiceLifecycle` are started in registration order:
/// ```swift
/// try await registry.startupAll(app)
/// // All services are now initialized and ready
/// ```
///
/// ## Shutdown Process
/// Services are shut down in reverse order to handle dependencies properly:
/// ```swift
/// try await registry.shutdownAll(app)
/// // All services have been gracefully stopped
/// ```
///
/// ## Health Monitoring
/// Continuous monitoring of service health for operational visibility:
/// ```swift
/// let healthStatus = await registry.healthCheckAll()
/// for (serviceName, isHealthy) in healthStatus {
///     if !isHealthy {
///         logger.warning("Service \(serviceName) is unhealthy")
///     }
/// }
/// ```
///
/// ## Integration Requirements
/// - Services must implement `ServiceLifecycle` for startup/shutdown coordination
/// - Services must implement `ServiceHealthCheck` for health monitoring
/// - Lifecycle operations should be idempotent and error-resilient
public protocol ServiceRegistryLifecycle {
    /// Starts up all registered services that implement the ServiceLifecycle protocol.
    ///
    /// This method coordinates the startup sequence of all lifecycle-aware services,
    /// ensuring they are properly initialized before the application begins
    /// processing requests. Services are started in registration order.
    ///
    /// ## Startup Sequence
    /// 1. Collect all services implementing `ServiceLifecycle`
    /// 2. Start each service sequentially to handle dependencies
    /// 3. Propagate any startup errors to halt application launch
    /// 4. Log startup progress for operational visibility
    ///
    /// ## Error Handling
    /// - If any service fails to start, the entire startup process fails
    /// - Services that started successfully before the failure remain running
    /// - Application should handle startup failures gracefully
    ///
    /// ## Usage in Application Lifecycle
    /// ```swift
    /// // During application configuration
    /// app.lifecycle.use {
    ///     try await app.serviceRegistry.startupAll(app)
    /// }
    /// ```
    ///
    /// - Parameter app: The Vapor application instance
    /// - Throws: Service startup errors or lifecycle coordination failures
    func startupAll(_ app: Application) async throws
    /// Shuts down all registered services in reverse order of startup.
    ///
    /// This method coordinates the graceful shutdown of all lifecycle-aware
    /// services, ensuring proper resource cleanup and dependency handling.
    /// Services are shut down in reverse order to respect dependencies.
    ///
    /// ## Shutdown Sequence
    /// 1. Collect all services implementing `ServiceLifecycle`
    /// 2. Reverse the order to shut down dependencies last
    /// 3. Shut down each service sequentially
    /// 4. Continue shutdown even if individual services fail
    ///
    /// ## Error Resilience
    /// - Individual service shutdown failures do not halt the process
    /// - All services are given the opportunity to shut down
    /// - Shutdown errors are logged but not propagated
    /// - Critical for graceful application termination
    ///
    /// ## Usage in Application Lifecycle
    /// ```swift
    /// // During application shutdown
    /// app.lifecycle.use {
    ///     try await app.serviceRegistry.shutdownAll(app)
    /// }
    /// ```
    ///
    /// - Parameter app: The Vapor application instance
    /// - Throws: Critical shutdown errors that prevent proper cleanup
    func shutdownAll(_ app: Application) async throws
    /// Performs health checks on all registered services that implement ServiceHealthCheck.
    ///
    /// This method provides comprehensive health monitoring across all services,
    /// enabling operational visibility and automated health reporting. Each
    /// service's health is checked independently and reported with its status.
    ///
    /// ## Health Check Process
    /// 1. Collect all services implementing `ServiceHealthCheck`
    /// 2. Execute health checks sequentially to avoid resource contention
    /// 3. Collect results with service names and health status
    /// 4. Return comprehensive health report for monitoring
    ///
    /// ## Health Check Results
    /// ```swift
    /// let healthStatus = await registry.healthCheckAll()
    /// // Returns: [("DatabaseService", true), ("CacheService", false)]
    /// ```
    ///
    /// ## Monitoring Integration
    /// ```swift
    /// // Use for application health endpoints
    /// app.get("health") { req async in
    ///     let health = await req.application.serviceRegistry.healthCheckAll()
    ///     let overallHealthy = health.allSatisfy { $0.healthy }
    ///     return HealthResponse(services: health, healthy: overallHealthy)
    /// }
    /// ```
    ///
    /// ## Performance Characteristics
    /// - Health checks are performed sequentially to avoid resource conflicts
    /// - Individual service timeouts should be handled within service implementations
    /// - Results are collected and returned as a complete report
    ///
    /// - Returns: Array of tuples containing service names and their health status
    func healthCheckAll() async -> [(name: String, healthy: Bool)]
}

/// Comprehensive error types for service registry operations with detailed diagnostics.
///
/// This enum provides specific error cases for different service registry failure
/// modes, enabling precise error handling and debugging capabilities. Each error
/// includes detailed context information for troubleshooting and monitoring.
///
/// ## Error Categories
///
/// ### Service Resolution Errors
/// - `serviceNotFound`: Requested service is not registered
/// - `serviceInitializationFailed`: Factory execution or service creation failed
///
/// ### Dependency Management Errors
/// - `circularDependency`: Circular reference detected in service dependencies
/// - `factoryTypeMismatch`: Factory return type doesn't match expected service type
///
/// ## Error Handling Patterns
///
/// ### Required Service Resolution
/// ```swift
/// do {
///     let service = try await registry.resolveRequired(DatabaseService.self)
/// } catch ServiceRegistryError.serviceNotFound(let typeName) {
///     logger.error("Critical service missing: \(typeName)")
///     throw Abort(.internalServerError)
/// }
/// ```
///
/// ### Factory Registration
/// ```swift
/// do {
///     registry.register(ComplexService.self) { app in
///         try await ComplexService(dependency: app.someService)
///     }
/// } catch ServiceRegistryError.serviceInitializationFailed(let type, let error) {
///     logger.error("Failed to create \(type): \(error)")
/// }
/// ```
///
/// ## Monitoring Integration
/// - All errors implement `AppError` for consistent HTTP response handling
/// - Error identifiers enable structured logging and alerting
/// - Detailed error reasons support debugging and operational troubleshooting
public enum ServiceRegistryError: AppError {
    case serviceNotFound(String)
    case serviceInitializationFailed(String, Error)
    case circularDependency([String])
    case factoryTypeMismatch(String)
    
    public var status: HTTPResponseStatus {
        .internalServerError
    }
    
    public var reason: String {
        switch self {
        case .serviceNotFound(let type):
            return "Service \(type) not found in registry"
        case .serviceInitializationFailed(let type, let error):
            return "Failed to initialize service \(type): \(error)"
        case .circularDependency(let chain):
            return "Circular dependency detected: \(chain.joined(separator: " -> "))"
        case .factoryTypeMismatch(let type):
            return "Factory type mismatch for service \(type)"
        }
    }
    
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
        }
    }
    
    public var suggestedHTTPStatus: HTTPStatus {
        .internalServerError
    }
}