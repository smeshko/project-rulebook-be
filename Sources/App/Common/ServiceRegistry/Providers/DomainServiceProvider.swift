import Vapor

/// Service provider for registering domain services in the ServiceRegistry.
///
/// This provider manages the registration of all domain service implementations,
/// providing dependency injection for business logic components that encapsulate
/// complex workflows and coordinate between multiple external services.
///
/// ## Domain Services Overview
///
/// Domain services contain the core business logic that was previously embedded
/// in controllers. They provide clean, testable, reusable business operations
/// that can be composed into use cases and accessed by different interfaces.
///
/// ### Game Identification Domain
/// - **GameIdentificationService**: AI-powered game box image analysis
///   - Coordinates image processing, validation, AI analysis, and caching
///   - Handles security validation and response processing
///   - Provides intelligent caching for cost optimization
///
/// ### Rules Generation Domain
/// - Rules generation logic moved directly to GenerateRulesUseCase for simplified architecture
///   - Eliminates unnecessary service abstraction layer
///   - Direct implementation in use case reduces complexity
///
/// ### AI Response Validation Domain
/// - **AIResponseValidationService**: Centralized AI response security validation
///   - Validates responses for security threats and structural integrity
///   - Provides type-specific validation for different response formats
///   - Ensures comprehensive content filtering and quality assurance
///
/// ## Registration Pattern
///
/// Domain services are registered with their dependencies resolved from the ServiceRegistry:
/// ```swift
/// registry.register(GameIdentificationService.self) { app in
///     DefaultGameIdentificationService(
///         llmService: try await app.serviceRegistry.resolveRequired(LLMService.self),
///         aiCache: try await app.serviceRegistry.resolveRequired(AICacheServiceInterface.self),
///         aiInputValidator: try await app.serviceRegistry.resolveRequired(AIInputValidatorService.self),
///         cacheKeyGenerator: try await app.serviceRegistry.resolveRequired(CacheKeyGeneratorService.self),
///         cacheConfiguration: try app.configuration.cache
///     )
/// }
/// ```
///
/// ## Architecture Benefits
/// - **Separation of Concerns**: Business logic is separated from HTTP and infrastructure concerns
/// - **Testability**: Domain services can be easily mocked and tested in isolation
/// - **Reusability**: Services can be used by different interfaces (HTTP, CLI, scheduled tasks)
/// - **Maintainability**: Complex business logic is centralized and well-organized
/// - **Scalability**: Services can be optimized and scaled independently
///
/// ## Integration
///
/// This provider is called during application setup to register all domain services
/// in the dependency injection container for later resolution by use cases and controllers.
public struct DomainServiceProvider: ServiceProvider {
    
    /// Registers all domain services in the ServiceRegistry.
    ///
    /// This method registers domain services with their required dependencies resolved
    /// from the ServiceRegistry, enabling clean dependency injection patterns throughout
    /// the application's business logic layer.
    ///
    /// - Parameters:
    ///   - registry: The ServiceContainer to register domain services in
    ///   - app: The Vapor Application instance for accessing configuration and other services
    /// - Throws: Service registration errors if dependencies cannot be resolved
    public static func register(in registry: ServiceContainer, app: Application) async throws {
        
        // MARK: - Game Identification Domain Services
        
        /// GameIdentificationService for AI-powered game box image analysis
        registry.register(GameIdentificationService.self) { app in
            DefaultGameIdentificationService()
        }
        
        // MARK: - Rules Generation Domain Services
        
        // Rules generation logic has been moved directly to GenerateRulesUseCase
        // for simplified architecture without unnecessary abstraction layers
        
        // MARK: - AI Response Validation Domain Services
        
        /// AIResponseValidationService for centralized AI response security validation
        registry.register(AIResponseValidationService.self) { app in
            DefaultAIResponseValidationService()
        }
    }
}