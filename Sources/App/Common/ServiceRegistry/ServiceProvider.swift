import Vapor

/// Protocol for organizing and registering related services as a cohesive unit.
///
/// Service providers enable modular organization of service registrations,
/// allowing related services to be grouped together and registered as a unit.
/// This pattern promotes clean architecture and simplifies dependency management
/// across application modules.
///
/// ## Key Features
/// - **Modular Organization**: Group related services for better code organization
/// - **Batch Registration**: Register multiple services in a single operation
/// - **Dependency Coordination**: Handle complex service dependencies in one place
/// - **Configuration Management**: Apply consistent configuration across related services
/// - **Testing Support**: Easy service group mocking and replacement
///
/// ## Service Provider Patterns
///
/// ### Simple Service Group
/// ```swift
/// struct DatabaseServiceProvider: ServiceProvider {
///     static func register(in registry: ServiceContainer, app: Application) async throws {
///         // Register database connection
///         registry.register(DatabaseConnection.self) { app in
///             try await PostgreSQLConnection(url: app.databaseURL)
///         }
///         
///         // Register repository implementations
///         registry.register(UserRepository.self) { app in
///             try await PostgreSQLUserRepository(
///                 connection: try await registry.resolveRequired(DatabaseConnection.self)
///             )
///         }
///     }
/// }
/// ```
///
/// ### Complex Service Provider with Configuration
/// ```swift
/// struct NotificationServiceProvider: ServiceProvider {
///     static func register(in registry: ServiceContainer, app: Application) async throws {
///         // Register configuration
///         let config = NotificationConfig.configure(from: app.environment)
///         registry.register(NotificationConfig.self, instance: config)
///         
///         // Register email service
///         registry.register(EmailService.self) { app in
///             try await BrevoEmailService(
///                 apiKey: config.brevoAPIKey,
///                 logger: app.logger
///             )
///         }
///         
///         // Register SMS service
///         registry.register(SMSService.self) { app in
///             try await TwilioSMSService(
///                 config: config.twilioConfig,
///                 logger: app.logger
///             )
///         }
///         
///         // Register notification coordinator
///         registry.register(NotificationCoordinator.self) { app in
///             try await NotificationCoordinator(
///                 emailService: try await registry.resolveRequired(EmailService.self),
///                 smsService: try await registry.resolveRequired(SMSService.self)
///             )
///         }
///     }
/// }
/// ```
///
/// ## Registration Best Practices
/// - **Dependency Order**: Register dependencies before services that use them
/// - **Error Handling**: Provide clear error messages for registration failures
/// - **Configuration**: Use environment-based configuration for flexibility
/// - **Testability**: Make services easily mockable for testing
/// - **Performance**: Use lazy initialization for expensive services
///
/// ## Integration with Application
/// ```swift
/// // During application setup
/// try await DatabaseServiceProvider.register(in: app.serviceRegistry, app: app)
/// try await NotificationServiceProvider.register(in: app.serviceRegistry, app: app)
/// try await AuthenticationServiceProvider.register(in: app.serviceRegistry, app: app)
/// ```
public protocol ServiceProvider {
    /// Registers all services provided by this service provider.
    ///
    /// This method is responsible for registering all related services in the
    /// service registry. It should handle service dependencies, configuration,
    /// and any complex initialization logic required for the service group.
    ///
    /// ## Registration Responsibilities
    /// - Register all services provided by this service provider
    /// - Ensure proper dependency ordering
    /// - Apply appropriate configuration from the application environment
    /// - Handle service initialization errors gracefully
    /// - Set up service lifecycle and health check tracking
    ///
    /// ## Error Handling
    /// - Throw descriptive errors for registration failures
    /// - Provide context about which service failed to register
    /// - Include underlying error information for debugging
    /// - Fail fast to prevent application startup with incomplete services
    ///
    /// ## Performance Considerations
    /// - Use factory registration for expensive services
    /// - Avoid unnecessary service instantiation during registration
    /// - Implement proper async patterns for I/O-bound initialization
    /// - Consider service startup order for optimal performance
    ///
    /// ## Example Implementation
    /// ```swift
    /// static func register(in registry: ServiceContainer, app: Application) async throws {
    ///     // Register configuration first
    ///     let config = MyServiceConfig.configure(from: app.environment)
    ///     registry.register(MyServiceConfig.self, instance: config)
    ///     
    ///     // Register core service with dependencies
    ///     registry.register(MyService.self) { app in
    ///         try await MyService(
    ///             config: try await registry.resolveRequired(MyServiceConfig.self),
    ///             logger: app.logger
    ///         )
    ///     }
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - registry: The service container to register services in
    ///   - app: The Vapor application instance for accessing configuration and services
    /// - Throws: Service registration errors that prevent proper application startup
    static func register(in registry: ServiceContainer, app: Application) async throws
}

/// Protocol for environment-based service configuration with type-safe factory methods.
///
/// This protocol provides a standardized approach to service configuration that
/// integrates with Vapor's environment system and the service registry. It enables
/// services to be configured based on the application environment while maintaining
/// type safety and testability.
///
/// ## Key Features
/// - **Environment-Based Configuration**: Automatic configuration based on application environment
/// - **Type Safety**: Compile-time configuration validation
/// - **Factory Integration**: Seamless integration with service registry factories
/// - **Testing Support**: Easy configuration overrides for testing scenarios
/// - **Validation**: Built-in configuration validation and error reporting
///
/// ## Configuration Implementation
///
/// ### Basic Configuration
/// ```swift
/// struct DatabaseConfiguration: ServiceConfiguration {
///     typealias ServiceType = DatabaseService
///     
///     let url: String
///     let maxConnections: Int
///     let timeout: TimeInterval
///     
///     static func configure(from environment: Environment) -> DatabaseConfiguration {
///         DatabaseConfiguration(
///             url: environment.databaseURL ?? "postgresql://localhost/app",
///             maxConnections: environment.isRelease ? 20 : 5,
///             timeout: environment.isRelease ? 30 : 10
///         )
///     }
///     
///     func makeService(app: Application) async throws -> DatabaseService {
///         try await DatabaseService(
///             url: url,
///             maxConnections: maxConnections,
///             timeout: timeout,
///             logger: app.logger
///         )
///     }
/// }
/// ```
///
/// ### Advanced Configuration with Validation
/// ```swift
/// struct EmailConfiguration: ServiceConfiguration {
///     typealias ServiceType = EmailService
///     
///     let apiKey: String
///     let defaultSender: String
///     let rateLimitPerHour: Int
///     
///     static func configure(from environment: Environment) -> EmailConfiguration {
///         guard let apiKey = environment.emailAPIKey else {
///             fatalError("EMAIL_API_KEY environment variable required")
///         }
///         
///         return EmailConfiguration(
///             apiKey: apiKey,
///             defaultSender: environment.emailDefaultSender ?? "noreply@example.com",
///             rateLimitPerHour: environment.emailRateLimit ?? 1000
///         )
///     }
///     
///     func makeService(app: Application) async throws -> EmailService {
///         let service = try await BrevoEmailService(
///             apiKey: apiKey,
///             defaultSender: defaultSender,
///             logger: app.logger
///         )
///         
///         // Configure rate limiting
///         service.setRateLimit(rateLimitPerHour)
///         
///         return service
///     }
/// }
/// ```
///
/// ## Integration with Service Registry
/// ```swift
/// // Register service using configuration
/// let config = DatabaseConfiguration.configure(from: app.environment)
/// registry.register(DatabaseService.self) { app in
///     try await config.makeService(app: app)
/// }
/// ```
///
/// ## Testing Configuration
/// ```swift
/// // Override configuration for testing
/// struct TestDatabaseConfiguration: ServiceConfiguration {
///     static func configure(from environment: Environment) -> TestDatabaseConfiguration {
///         TestDatabaseConfiguration()
///     }
///     
///     func makeService(app: Application) async throws -> DatabaseService {
///         MockDatabaseService()
///     }
/// }
/// ```
public protocol ServiceConfiguration {
    /// The type of service that this configuration creates.
    ///
    /// This associated type ensures type safety between the configuration
    /// and the service it produces. The makeService method must return
    /// an instance of this type.
    associatedtype ServiceType
    
    /// Creates a configuration instance from the application environment.
    ///
    /// This method reads configuration values from the application environment
    /// and creates a properly configured instance. It should handle environment
    /// variable parsing, provide sensible defaults, and validate required values.
    ///
    /// ## Environment Integration
    /// - Read configuration from environment variables
    /// - Provide environment-specific defaults (development vs production)
    /// - Validate required configuration values
    /// - Handle configuration parsing errors gracefully
    ///
    /// ## Implementation Guidelines
    /// - Use Environment.get() for optional values with defaults
    /// - Use Environment.require() for mandatory configuration
    /// - Provide different defaults for development and production
    /// - Log configuration values (excluding secrets) for debugging
    ///
    /// ## Example Implementation
    /// ```swift
    /// static func configure(from environment: Environment) -> MyServiceConfig {
    ///     MyServiceConfig(
    ///         apiURL: environment.get("API_URL") ?? "https://api.example.com",
    ///         timeout: environment.get("API_TIMEOUT").flatMap(Double.init) ?? 30.0,
    ///         apiKey: environment.require("API_KEY"), // Throws if missing
    ///         retryAttempts: environment.isRelease ? 3 : 1
    ///     )
    /// }
    /// ```
    ///
    /// - Parameter environment: The Vapor application environment
    /// - Returns: A configured instance of this configuration type
    static func configure(from environment: Environment) -> Self
    
    /// Creates a service instance using this configuration.
    ///
    /// This method uses the configuration values to create and initialize
    /// a service instance. It should handle service initialization, dependency
    /// resolution, and any required setup operations.
    ///
    /// ## Service Creation
    /// - Use configuration values to initialize the service
    /// - Resolve dependencies through the application or service registry
    /// - Perform any required service setup or validation
    /// - Handle initialization errors with descriptive error messages
    ///
    /// ## Dependency Resolution
    /// ```swift
    /// func makeService(app: Application) async throws -> MyService {
    ///     // Resolve dependencies
    ///     let database = try await app.serviceRegistry.resolveRequired(DatabaseService.self)
    ///     let cache = try await app.serviceRegistry.resolve(CacheService.self)
    ///     
    ///     // Create service with configuration and dependencies
    ///     return MyService(
    ///         apiURL: apiURL,
    ///         database: database,
    ///         cache: cache,
    ///         logger: app.logger
    ///     )
    /// }
    /// ```
    ///
    /// ## Error Handling
    /// - Provide clear error messages for initialization failures
    /// - Include configuration context in error messages
    /// - Handle dependency resolution failures gracefully
    /// - Use async/await patterns for I/O-bound initialization
    ///
    /// - Parameter app: The Vapor application instance for dependency resolution
    /// - Returns: A configured service instance
    /// - Throws: Service initialization errors with context
    func makeService(app: Application) async throws -> ServiceType
}

// MARK: - Backward Compatibility Bridge

/// Bridge for integrating existing Vapor services with the new ServiceRegistry system.
///
/// This bridge provides backward compatibility by allowing existing services
/// registered through Vapor's traditional dependency injection system to be
/// accessed through the new ServiceRegistry. This enables gradual migration
/// without breaking existing code.
///
/// ## Key Features
/// - **Gradual Migration**: Migrate services incrementally without breaking changes
/// - **Legacy Integration**: Access existing Vapor services through new registry
/// - **Repository Bridging**: Bridge repository patterns to new service registry
/// - **Dual Access**: Services accessible through both old and new systems during transition
///
/// ## Migration Strategy
///
/// ### Phase 1: Bridge Existing Services
/// ```swift
/// let bridge = ServiceRegistryBridge(registry: app.serviceRegistry, app: app)
/// 
/// // Bridge existing services to new registry
/// try await bridge.bridgeExistingService(
///     UserService.self,
///     from: \.userService
/// )
/// ```
///
/// ### Phase 2: Migrate to Factory Pattern
/// ```swift
/// // Replace bridged service with factory registration
/// bridge.bridgeRepository(UserRepository.self) { app in
///     try await DatabaseUserRepository(
///         database: app.db,
///         logger: app.logger
///     )
/// }
/// ```
///
/// ### Phase 3: Remove Bridge (Future)
/// Once all services are migrated, the bridge can be removed and services
/// accessed directly through the service registry.
///
/// ## Compatibility Notes
/// - Services bridged through this system maintain their original behavior
/// - No performance overhead for bridged services
/// - Full lifecycle and health check support for bridged services
/// - Thread safety maintained across both access patterns
public struct ServiceRegistryBridge {
    /// The service registry to bridge services into.
    ///
    /// Services bridged through this bridge will be registered in this
    /// registry and accessible through the new service resolution patterns.
    private let registry: ServiceContainer
    
    /// The Vapor application for accessing existing services.
    ///
    /// Used to resolve services from the traditional Vapor dependency
    /// injection system and bridge them to the new registry.
    private let app: Application
    
    /// Creates a new service registry bridge.
    ///
    /// This bridge enables integration between existing Vapor services
    /// and the new ServiceRegistry system, allowing for gradual migration.
    ///
    /// - Parameters:
    ///   - registry: The service registry to bridge services into
    ///   - app: The Vapor application instance for accessing existing services
    public init(registry: ServiceContainer, app: Application) {
        self.registry = registry
        self.app = app
    }
    
    /// Bridges an existing Vapor service to the new service registry.
    ///
    /// This method takes a service that was registered through Vapor's
    /// traditional dependency injection system and makes it available
    /// through the new ServiceRegistry. The service maintains its
    /// original instance and behavior.
    ///
    /// ## Bridging Process
    /// 1. Resolve the service from Vapor's traditional DI system
    /// 2. Register the same instance in the new service registry
    /// 3. Enable access through both systems during migration
    ///
    /// ## Usage Example
    /// ```swift
    /// // Bridge existing user service
    /// try await bridge.bridgeExistingService(
    ///     UserService.self,
    ///     from: \.userService
    /// )
    /// 
    /// // Now accessible through both systems:
    /// let userService1 = app.userService.service // Old way
    /// let userService2 = try await app.serviceRegistry.resolveRequired(UserService.self) // New way
    /// // userService1 === userService2 (same instance)
    /// ```
    ///
    /// ## Lifecycle Integration
    /// - Services implementing ServiceLifecycle are automatically tracked
    /// - Services implementing ServiceHealthCheck are included in monitoring
    /// - No change to service behavior or lifecycle management
    ///
    /// - Parameters:
    ///   - type: The service type to bridge
    ///   - keyPath: KeyPath to the service in the Vapor services container
    /// - Throws: Service resolution errors if the service is not available
    public func bridgeExistingService<T>(
        _ type: T.Type,
        from keyPath: KeyPath<Application.Services, Application.Service<T>>
    ) async throws {
        // Get the existing service through Vapor's DI
        let service = app.services[keyPath: keyPath].service
        
        // Register it in our new registry
        registry.register(type, instance: service)
    }
    
    /// Registers a repository or service using the new factory pattern.
    ///
    /// This method enables registration of new services using the modern
    /// factory pattern while maintaining compatibility with the existing
    /// codebase. It's ideal for migrating repositories and services to
    /// the new dependency injection system.
    ///
    /// ## Factory Registration
    /// - Services are created lazily when first requested
    /// - Factory functions can resolve dependencies from the new registry
    /// - Full async/await support for service initialization
    /// - Automatic lifecycle and health check integration
    ///
    /// ## Migration Pattern
    /// ```swift
    /// // Replace bridged service with factory
    /// bridge.bridgeRepository(UserRepository.self) { app in
    ///     // Resolve dependencies through new registry
    ///     let database = try await app.serviceRegistry.resolveRequired(DatabaseService.self)
    ///     let cache = try await app.serviceRegistry.resolve(CacheService.self)
    ///     
    ///     return DatabaseUserRepository(
    ///         database: database,
    ///         cache: cache,
    ///         logger: app.logger
    ///     )
    /// }
    /// ```
    ///
    /// ## Dependency Resolution
    /// Factory functions can access both old and new dependency injection systems:
    /// ```swift
    /// bridge.bridgeRepository(EmailService.self) { app in
    ///     // Access traditional Vapor services
    ///     let config = app.configurationService.service
    ///     
    ///     // Access new registry services
    ///     let validator = try await app.serviceRegistry.resolveRequired(EmailValidator.self)
    ///     
    ///     return EmailService(config: config, validator: validator)
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - type: The service type to register
    ///   - factory: Factory function that creates the service instance
    public func bridgeRepository<T>(
        _ type: T.Type,
        factory: @escaping @Sendable (Application) async throws -> T
    ) {
        registry.register(type, factory: factory)
    }
}