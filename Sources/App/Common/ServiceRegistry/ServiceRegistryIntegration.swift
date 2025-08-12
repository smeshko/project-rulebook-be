import Vapor

/// Application-level integration methods for ServiceRegistry lifecycle management.
///
/// These extensions provide high-level methods for integrating the ServiceRegistry
/// into the Vapor application lifecycle, handling service registration, startup,
/// and shutdown coordination.
extension Application {
    /// Initializes the ServiceRegistry and registers all application services.
    ///
    /// This method coordinates the complete service registration and startup process
    /// for the application. It should be called during application configuration
    /// to ensure all services are properly registered and initialized before
    /// request processing begins.
    ///
    /// ## Service Registration Process
    /// 1. **Provider Registration**: Register all service providers in dependency order
    /// 2. **Service Validation**: Verify all required services are registered
    /// 3. **Lifecycle Startup**: Start all services implementing ServiceLifecycle
    /// 4. **Health Check Setup**: Initialize health monitoring for all services
    ///
    /// ## Service Provider Registration
    /// ```swift
    /// try await setupServiceRegistry()
    /// // Registers services from:
    /// // - DemoServiceProvider (basic services)
    /// // - RepositoryServiceProvider (data access)
    /// // - ExternalServiceProvider (third-party integrations)
    /// ```
    ///
    /// ## Integration with Application Lifecycle
    /// ```swift
    /// // During application configuration
    /// app.lifecycle.use {
    ///     try await app.setupServiceRegistry()
    /// }
    /// 
    /// app.lifecycle.use {
    ///     try await app.shutdownServiceRegistry()
    /// }
    /// ```
    ///
    /// ## Error Handling
    /// - Service registration failures prevent application startup
    /// - Comprehensive error context for debugging registration issues
    /// - Startup failures are propagated to halt application launch
    /// - All services must successfully start before request processing begins
    ///
    /// ## Performance Considerations
    /// - Services are registered in optimal dependency order
    /// - Lazy initialization minimizes startup time
    /// - Parallel startup where dependencies allow
    /// - Health checks are initialized but not executed during startup
    ///
    /// - Throws: Service registration or startup errors that prevent application launch
    public func setupServiceRegistry() async throws {
        // Register all services in the registry in dependency order
        try await DemoServiceProvider.register(in: serviceRegistry, app: self)
        try await RepositoryServiceProvider.register(in: serviceRegistry, app: self)
        try await ExternalServiceProvider.register(in: serviceRegistry, app: self)
        
        // Validate all services are properly registered
        try await validateServiceRegistration()
        
        // Start up all services that implement ServiceLifecycle
        try await serviceRegistry.startupAll(self)
    }
    
    /// Validates that all required services are properly registered.
    ///
    /// This method performs comprehensive validation of service registration to catch
    /// configuration issues early during application startup rather than at runtime.
    ///
    /// ## Validation Benefits
    /// - **Early Detection**: Catches service registration issues during startup
    /// - **Dependency Verification**: Ensures all service dependencies are satisfied
    /// - **Configuration Validation**: Verifies proper service provider configuration
    /// - **Error Prevention**: Prevents runtime service resolution failures
    ///
    /// ## Validated Services
    /// This method validates registration of:
    /// - All repository services (users, emailTokens, refreshTokens, passwordTokens)
    /// - All external services (email, llm, aiCache, generators, validators)
    /// - All utility services (randomGenerator, uuidGenerator, ipExtractor)
    ///
    /// - Throws: Service registration errors if any required service is missing
    private func validateServiceRegistration() async throws {
        // Validate repositories are registered
        _ = try await serviceRegistry.resolveRequired((any UserRepository).self)
        _ = try await serviceRegistry.resolveRequired((any EmailTokenRepository).self)
        _ = try await serviceRegistry.resolveRequired((any RefreshTokenRepository).self)
        _ = try await serviceRegistry.resolveRequired((any PasswordTokenRepository).self)
        
        // Validate services are registered
        _ = try await serviceRegistry.resolveRequired(EmailService.self)
        _ = try await serviceRegistry.resolveRequired(LLMService.self)
        _ = try await serviceRegistry.resolveRequired(AICacheServiceInterface.self)
        _ = try await serviceRegistry.resolveRequired(RandomGeneratorService.self)
        _ = try await serviceRegistry.resolveRequired(UUIDGeneratorService.self)
        _ = try await serviceRegistry.resolveRequired(IPExtractorService.self)
        _ = try await serviceRegistry.resolveRequired(PromptSanitizerServiceInterface.self)
        _ = try await serviceRegistry.resolveRequired(AIInputValidatorServiceInterface.self)
        _ = try await serviceRegistry.resolveRequired(CacheKeyGeneratorServiceInterface.self)
    }
    
    /// Gracefully shuts down all services in the registry.
    ///
    /// This method coordinates the graceful shutdown of all registered services,
    /// ensuring proper resource cleanup and dependency management. It should be
    /// called during application termination to prevent resource leaks.
    ///
    /// ## Shutdown Process
    /// 1. **Service Shutdown**: Stop all services implementing ServiceLifecycle
    /// 2. **Resource Cleanup**: Close connections, files, and other resources
    /// 3. **Dependency Management**: Shut down services in reverse dependency order
    /// 4. **Error Resilience**: Continue shutdown even if individual services fail
    ///
    /// ## Shutdown Coordination
    /// - Services are shut down in reverse order of startup
    /// - Dependencies remain available until their dependents shut down
    /// - Individual service failures don't halt the shutdown process
    /// - Critical resources are cleaned up even in error conditions
    ///
    /// ## Integration with Application Lifecycle
    /// ```swift
    /// // Automatic shutdown on application termination
    /// app.lifecycle.use {
    ///     try await app.shutdownServiceRegistry()
    /// }
    /// ```
    ///
    /// ## Error Handling
    /// - Individual service shutdown errors are logged but don't propagate
    /// - Critical shutdown failures are reported for operational awareness
    /// - Timeout protection prevents hanging during shutdown
    /// - Resource cleanup continues even with partial failures
    ///
    /// - Throws: Critical shutdown errors that require immediate attention
    public func shutdownServiceRegistry() async throws {
        try await serviceRegistry.shutdownAll(self)
    }
}

// MARK: - Request Extensions for Service Resolution

/// Request-level service resolution methods for controller and middleware access.
///
/// These extensions provide convenient service resolution methods that can be
/// used throughout the request processing pipeline, enabling clean dependency
/// injection patterns in controllers, middleware, and other request handlers.
extension Request {
    /// Resolves a required service from the registry with error propagation.
    ///
    /// This method provides strict service resolution for critical dependencies
    /// that controllers and middleware require to function properly. It throws
    /// a clear error if the service is not available.
    ///
    /// ## Usage in Controllers
    /// ```swift
    /// func handleUserProfile(_ req: Request) async throws -> Response {
    ///     let userService = try await req.resolveService(UserService.self)
    ///     let user = try await userService.findUser(id: userID)
    ///     return req.view.render("profile", ["user": user])
    /// }
    /// ```
    ///
    /// ## Usage in Middleware
    /// ```swift
    /// func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
    ///     let authService = try await request.resolveService(AuthenticationService.self)
    ///     guard await authService.isValidToken(request.headers.bearerAuthorization) else {
    ///         throw Abort(.unauthorized)
    ///     }
    ///     return try await next.respond(to: request)
    /// }
    /// ```
    ///
    /// ## Error Handling
    /// - Throws ServiceRegistryError.serviceNotFound if service not registered
    /// - Throws ServiceRegistryError.circularDependency if dependency cycle detected
    /// - Throws ServiceRegistryError.serviceInitializationFailed if factory fails
    /// - All errors include context for debugging and monitoring
    ///
    /// ## Performance
    /// - Services are cached after first resolution for optimal performance
    /// - Thread-safe concurrent access across multiple requests
    /// - Minimal overhead for subsequent resolutions
    ///
    /// - Parameter type: The required service type to resolve
    /// - Returns: The service instance (guaranteed to be non-nil)
    /// - Throws: Service resolution errors with detailed context
    public func resolveService<T>(_ type: T.Type) async throws -> T {
        try await application.serviceRegistry.resolveRequired(type)
    }
    
    /// Resolves an optional service from the registry without error propagation.
    ///
    /// This method provides graceful service resolution for optional dependencies
    /// that enhance functionality but are not required for basic operation.
    /// Returns nil if the service is not available instead of throwing an error.
    ///
    /// ## Usage for Optional Services
    /// ```swift
    /// func handleUserRegistration(_ req: Request) async throws -> Response {
    ///     let userService = try await req.resolveService(UserService.self)
    ///     let user = try await userService.createUser(from: req.body)
    ///     
    ///     // Optional email notification
    ///     if let emailService = try await req.resolveServiceOptional(EmailService.self) {
    ///         await emailService.sendWelcomeEmail(to: user)
    ///     }
    ///     
    ///     return user.response()
    /// }
    /// ```
    ///
    /// ## Graceful Degradation
    /// ```swift
    /// func handleAnalytics(_ req: Request) async throws -> Response {
    ///     // Core functionality
    ///     let dataService = try await req.resolveService(DataService.self)
    ///     let data = try await dataService.fetchData()
    ///     
    ///     // Optional analytics tracking
    ///     if let analytics = try await req.resolveServiceOptional(AnalyticsService.self) {
    ///         await analytics.trackDataAccess(data: data, user: req.user)
    ///     }
    ///     
    ///     return data.response()
    /// }
    /// ```
    ///
    /// ## Error Handling
    /// - Returns nil if service is not registered (no error thrown)
    /// - Throws ServiceRegistryError.circularDependency if dependency cycle detected
    /// - Throws ServiceRegistryError.serviceInitializationFailed if factory fails
    /// - Only throws errors for resolution failures, not missing services
    ///
    /// - Parameter type: The optional service type to resolve
    /// - Returns: The service instance or nil if not registered
    /// - Throws: Service resolution errors (excluding missing service)
    public func resolveServiceOptional<T>(_ type: T.Type) async throws -> T? {
        try await application.serviceRegistry.resolve(type)
    }
}

// MARK: - Service Registry Usage Examples

/// Comprehensive usage examples demonstrating ServiceRegistry integration patterns.
///
/// These examples show best practices for using the ServiceRegistry throughout
/// a Vapor application, including controllers, middleware, and service providers.
///
/// ## Controller Integration Examples
///
/// ### Basic Service Resolution
/// ```swift
/// struct UserController {
///     func getProfile(_ req: Request) async throws -> UserProfile {
///         let userRepo = try await req.resolveService(UserRepository.self)
///         let userID = try req.parameters.require("userID", as: UUID.self)
///         return try await userRepo.findProfile(userID: userID)
///     }
/// }
/// ```
///
/// ### Multiple Service Dependencies
/// ```swift
/// struct GameRulesController {
///     func generateRules(_ req: Request) async throws -> RulesResponse {
///         let llmService = try await req.resolveService(LLMService.self)
///         let gameRepo = try await req.resolveService(GameRepository.self)
///         let imageService = try await req.resolveServiceOptional(ImageAnalysisService.self)
///         
///         let gameData = try await gameRepo.getGame(id: gameID)
///         
///         if let imageService = imageService {
///             let imageAnalysis = try await imageService.analyzeGameBox(gameData.imageURL)
///             return try await llmService.generateRules(game: gameData, analysis: imageAnalysis)
///         } else {
///             return try await llmService.generateRules(game: gameData)
///         }
///     }
/// }
/// ```
///
/// ## Middleware Integration Examples
///
/// ### Authentication Middleware
/// ```swift
/// struct AuthenticationMiddleware: AsyncMiddleware {
///     func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
///         let authService = try await request.resolveService(AuthenticationService.self)
///         
///         guard let token = request.headers.bearerAuthorization?.token else {
///             throw Abort(.unauthorized, reason: "Missing authentication token")
///         }
///         
///         let user = try await authService.validateToken(token)
///         request.auth.login(user)
///         
///         return try await next.respond(to: request)
///     }
/// }
/// ```
///
/// ### Rate Limiting with Service Integration
/// ```swift
/// struct ServiceAwareRateLimitMiddleware: AsyncMiddleware {
///     func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
///         let rateLimitService = try await request.resolveService(RateLimitService.self)
///         let userService = try await request.resolveServiceOptional(UserService.self)
///         
///         let clientID = request.remoteAddress?.hostname ?? "unknown"
///         
///         // Enhanced rate limiting based on user tier
///         if let userService = userService,
///            let user = request.auth.get(User.self) {
///             let userTier = try await userService.getUserTier(user.id)
///             try await rateLimitService.checkLimit(clientID: clientID, tier: userTier)
///         } else {
///             try await rateLimitService.checkLimit(clientID: clientID, tier: .anonymous)
///         }
///         
///         return try await next.respond(to: request)
///     }
/// }
/// ```