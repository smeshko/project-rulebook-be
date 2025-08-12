import Vapor

/// Protocol for services requiring coordinated lifecycle management across application startup and shutdown.
///
/// This protocol enables services to participate in the application's lifecycle
/// coordination, ensuring proper initialization and cleanup of resources in
/// a structured manner. Services implementing this protocol are automatically
/// tracked by the ServiceRegistry for coordinated management.
///
/// ## Key Features
/// - **Coordinated Startup**: Sequential startup with dependency awareness
/// - **Graceful Shutdown**: Reverse-order shutdown for proper resource cleanup
/// - **Error Propagation**: Startup failures halt application launch
/// - **Resource Management**: Structured approach to external resource handling
///
/// ## Lifecycle Coordination
///
/// Services are started and stopped in a coordinated manner:
/// - **Startup Order**: Services start in registration order
/// - **Shutdown Order**: Services shut down in reverse registration order
/// - **Error Handling**: Startup errors halt the process, shutdown errors are logged
///
/// ## Implementation Guidelines
///
/// ### Startup Implementation
/// ```swift
/// func startup(_ app: Application) async throws {
///     // Initialize external connections
///     try await connectToDatabase(app.databaseURL)
///     
///     // Verify resource availability
///     guard await isDatabaseHealthy() else {
///         throw ServiceError.databaseUnavailable
///     }
///     
///     // Log successful startup
///     app.logger.info("DatabaseService started successfully")
/// }
/// ```
///
/// ### Shutdown Implementation
/// ```swift
/// func shutdown(_ app: Application) async throws {
///     // Close connections gracefully
///     await closeConnections()
///     
///     // Clean up resources
///     await cleanupTempFiles()
///     
///     // Log shutdown completion
///     app.logger.info("DatabaseService shut down gracefully")
/// }
/// ```
///
/// ## Best Practices
/// - **Idempotent Operations**: Startup and shutdown should be safe to call multiple times
/// - **Resource Cleanup**: Always clean up resources in shutdown, even if startup failed
/// - **Error Reporting**: Provide clear error messages for debugging
/// - **Logging**: Log significant lifecycle events for operational visibility
/// - **Timeout Handling**: Implement reasonable timeouts for external resource operations
///
/// ## Integration with ServiceRegistry
/// Services implementing this protocol are automatically detected and tracked:
/// ```swift
/// // Automatic lifecycle tracking when registered
/// registry.register(DatabaseService.self, instance: databaseService)
/// 
/// // Coordinated startup during application launch
/// try await registry.startupAll(app)
/// 
/// // Graceful shutdown during application termination
/// try await registry.shutdownAll(app)
/// ```
public protocol ServiceLifecycle {
    /// Initializes the service during application startup.
    ///
    /// This method is called during the application startup sequence to
    /// initialize external resources, establish connections, and prepare
    /// the service for operation. Services are started in registration order.
    ///
    /// ## Startup Responsibilities
    /// - Initialize external connections (databases, APIs, message queues)
    /// - Verify resource availability and health
    /// - Set up internal state and configuration
    /// - Register for system notifications if needed
    /// - Perform any required migrations or setup tasks
    ///
    /// ## Error Handling
    /// - Startup failures should throw descriptive errors
    /// - Errors halt the entire application startup process
    /// - Provide clear diagnostic information for troubleshooting
    ///
    /// ## Performance Considerations
    /// - Use reasonable timeouts for external resource connections
    /// - Implement retries for transient failures where appropriate
    /// - Avoid blocking operations that could delay application startup
    ///
    /// - Parameter app: The Vapor application instance for accessing configuration and services
    /// - Throws: Service initialization errors that prevent startup
    func startup(_ app: Application) async throws
    
    /// Gracefully shuts down the service during application termination.
    ///
    /// This method is called during application shutdown to clean up resources,
    /// close connections, and perform final cleanup tasks. Services are shut down
    /// in reverse order of startup to respect dependencies.
    ///
    /// ## Shutdown Responsibilities
    /// - Close external connections gracefully
    /// - Save any pending data or state
    /// - Clean up temporary resources and files
    /// - Cancel ongoing operations and background tasks
    /// - Release system resources (file handles, memory)
    ///
    /// ## Error Resilience
    /// - Shutdown should continue even if some operations fail
    /// - Log errors but don't propagate them to avoid cascade failures
    /// - Clean up what's possible even in error conditions
    /// - Implement timeouts to prevent hanging the shutdown process
    ///
    /// ## Best Practices
    /// - Make shutdown operations idempotent
    /// - Use reasonable timeouts for cleanup operations
    /// - Log significant cleanup actions for operational visibility
    /// - Handle the case where startup never completed successfully
    ///
    /// - Parameter app: The Vapor application instance for accessing logging and configuration
    /// - Throws: Critical shutdown errors that require immediate attention
    func shutdown(_ app: Application) async throws
}

/// Protocol for services providing health monitoring capabilities.
///
/// This protocol enables services to participate in application health monitoring
/// by providing standardized health check capabilities. Services implementing
/// this protocol are automatically tracked by the ServiceRegistry for
/// comprehensive health reporting.
///
/// ## Key Features
/// - **Health Status Reporting**: Boolean health indicators for monitoring systems
/// - **Service Identification**: Clear naming for operational visibility
/// - **Monitoring Integration**: Automatic inclusion in application health endpoints
/// - **Operational Insight**: Real-time service status for debugging and alerting
///
/// ## Health Check Implementation
///
/// ### Basic Health Check
/// ```swift
/// func isHealthy() async -> Bool {
///     // Check database connection
///     guard await database.isConnected else { return false }
///     
///     // Verify recent successful operations
///     guard await hasRecentSuccessfulOperations() else { return false }
///     
///     // Check resource availability
///     return await hasAdequateResources()
/// }
/// ```
///
/// ### Advanced Health Check with Metrics
/// ```swift
/// func isHealthy() async -> Bool {
///     let metrics = await gatherHealthMetrics()
///     
///     // Multi-criteria health assessment
///     return metrics.connectionPoolHealthy &&
///            metrics.errorRate < 0.05 &&
///            metrics.responseTime < 1000 &&
///            metrics.resourceUsage < 0.8
/// }
/// ```
///
/// ## Health Check Guidelines
/// - **Fast Execution**: Keep health checks lightweight and quick
/// - **Representative Status**: Check critical functionality, not just availability
/// - **Timeout Protection**: Implement timeouts to prevent hanging
/// - **Error Isolation**: Don't let health check failures affect service operation
/// - **Meaningful Assessment**: Check actual service capability, not just process existence
///
/// ## Monitoring Integration
/// Health checks are automatically included in application health endpoints:
/// ```swift
/// // GET /health returns:
/// {
///   "healthy": true,
///   "services": [
///     {"name": "DatabaseService", "healthy": true},
///     {"name": "CacheService", "healthy": false}
///   ]
/// }
/// ```
///
/// ## Best Practices
/// - **Dependency Checks**: Verify external dependencies are accessible
/// - **Performance Metrics**: Include performance indicators in health assessment
/// - **Resource Monitoring**: Check memory, connections, and other resource usage
/// - **Error Rate Analysis**: Consider recent error rates in health determination
/// - **Graceful Degradation**: Distinguish between degraded and failed states
public protocol ServiceHealthCheck {
    /// Performs a health check to determine if the service is operating correctly.
    ///
    /// This method should quickly assess the service's operational status by
    /// checking critical functionality, external dependencies, and resource
    /// availability. The result is used for monitoring, alerting, and load balancing.
    ///
    /// ## Health Assessment Criteria
    /// - **External Dependencies**: Verify connections to databases, APIs, message queues
    /// - **Internal State**: Check service configuration and internal consistency
    /// - **Resource Availability**: Assess memory, disk space, and connection pools
    /// - **Recent Performance**: Consider error rates and response times
    /// - **Critical Functionality**: Test core service capabilities
    ///
    /// ## Implementation Guidelines
    /// - Keep checks lightweight and fast (< 100ms ideal)
    /// - Test actual functionality, not just process existence
    /// - Return `false` for any condition that affects service capability
    /// - Use timeouts to prevent hanging health checks
    /// - Don't perform expensive operations that impact service performance
    ///
    /// ## Common Health Check Patterns
    /// ```swift
    /// func isHealthy() async -> Bool {
    ///     // Check database connectivity
    ///     guard await database.ping() else { return false }
    ///     
    ///     // Verify recent operations succeeded
    ///     let recentErrors = await errorCounter.getRecentErrors()
    ///     guard recentErrors < errorThreshold else { return false }
    ///     
    ///     // Check resource usage
    ///     return await memoryUsage() < memoryThreshold
    /// }
    /// ```
    ///
    /// ## Error Handling
    /// - Catch and handle all exceptions within the health check
    /// - Return `false` for any unexpected errors or timeouts
    /// - Log health check failures for debugging
    /// - Don't let health check errors affect normal service operation
    ///
    /// - Returns: `true` if the service is healthy and operational, `false` otherwise
    func isHealthy() async -> Bool
    
    /// Provides a human-readable name for this service's health check.
    ///
    /// This method returns a descriptive name used in health monitoring reports,
    /// operational dashboards, and debugging tools. The name should clearly
    /// identify the service and its primary function.
    ///
    /// ## Naming Guidelines
    /// - Use clear, descriptive names that identify the service purpose
    /// - Include service type and key functionality
    /// - Keep names concise but informative
    /// - Use consistent naming patterns across services
    /// - Avoid generic names like "Service" or "Component"
    ///
    /// ## Naming Examples
    /// ```swift
    /// // Good naming examples
    /// "DatabaseService" // Clear service identification
    /// "RedisCache" // Technology and purpose
    /// "EmailNotificationService" // Function and method
    /// "UserAuthentication" // Domain and capability
    /// 
    /// // Avoid generic names
    /// "Service" // Too generic
    /// "Component" // Doesn't identify function
    /// "Handler" // Unclear purpose
    /// ```
    ///
    /// ## Usage in Monitoring
    /// The returned name appears in health check reports and monitoring dashboards:
    /// ```json
    /// {
    ///   "services": [
    ///     {"name": "DatabaseService", "healthy": true},
    ///     {"name": "EmailService", "healthy": false}
    ///   ]
    /// }
    /// ```
    ///
    /// - Returns: A descriptive name for this service's health check
    func healthCheckName() -> String
}

/// Default implementations for ServiceLifecycle methods.
///
/// These default implementations provide no-op behavior for services that
/// need to implement the protocol but don't require custom lifecycle logic.
/// Services can implement either or both methods as needed.
public extension ServiceLifecycle {
    /// Default no-op startup implementation.
    ///
    /// Services that don't require startup logic can rely on this default
    /// implementation. Override this method to provide custom startup behavior.
    ///
    /// - Parameter app: The Vapor application instance
    func startup(_ app: Application) async throws {}
    
    /// Default no-op shutdown implementation.
    ///
    /// Services that don't require shutdown logic can rely on this default
    /// implementation. Override this method to provide custom cleanup behavior.
    ///
    /// - Parameter app: The Vapor application instance
    func shutdown(_ app: Application) async throws {}
}

/// Default implementations for ServiceHealthCheck methods.
///
/// These default implementations provide sensible behavior for services that
/// implement the protocol but don't need custom naming logic.
public extension ServiceHealthCheck {
    /// Default health check name based on the service type.
    ///
    /// This implementation uses Swift's type reflection to generate a name
    /// from the service's type. Override this method to provide a custom
    /// name that's more descriptive or user-friendly.
    ///
    /// ## Generated Name Format
    /// - Returns the full type name including module information
    /// - Example: "MyApp.DatabaseService" becomes "DatabaseService"
    /// - Automatically strips module prefixes for cleaner names
    ///
    /// ## Custom Naming
    /// ```swift
    /// func healthCheckName() -> String {
    ///     "PostgreSQL Database Connection"
    /// }
    /// ```
    ///
    /// - Returns: The service type name as a string
    func healthCheckName() -> String {
        String(describing: type(of: self))
    }
}