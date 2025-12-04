import Vapor
import JWT

/// Enhanced service provider for CQRS-based use case registration.
///
/// This provider organizes use case registration by Command/Query separation,
/// enabling CQRS patterns and future optimizations such as separate read/write
/// service configurations or command/query-specific middleware.
///
/// ## CQRS Architecture Benefits
///
/// - **Clear Separation**: Commands and queries are registered separately
/// - **Performance Optimization**: Can optimize command vs query dependencies differently
/// - **Security Enhancement**: Can apply different authorization patterns to commands vs queries
/// - **Future Flexibility**: Foundation for advanced CQRS patterns like event sourcing
/// - **Testing Benefits**: Can mock command/query dependencies independently
///
/// ## Organization Structure
/// ```
/// Commands (State-Changing)
/// └── Content Generation Commands (AI rules generation)
///
/// Queries (Read-Only)
/// └── Content Queries (game analysis)
/// ```
public struct CQRSServiceProvider: ServiceProvider {
    
    /// Registers all CQRS-organized use cases in the ServiceRegistry.
    ///
    /// Use cases are organized by Command/Query separation to enable
    /// CQRS patterns and future architectural optimizations.
    ///
    /// - Parameters:
    ///   - registry: The ServiceContainer to register use cases in
    ///   - app: The Vapor Application instance
    /// - Throws: Service registration errors
    public static func register(in registry: ServiceContainer, app: Application) async throws {
        
        // Register Commands (State-Changing Operations)
        try await registerCommands(in: registry, app: app)
        
        // Register Queries (Read-Only Operations)  
        try await registerQueries(in: registry, app: app)
    }
    
    // MARK: - Commands (State-Changing Operations)
    
    /// Registers all command use cases that modify system state.
    ///
    /// Commands are operations that change the state of the system,
    /// such as creating, updating, or deleting entities.
    private static func registerCommands(in registry: ServiceContainer, app: Application) async throws {
        // Content Generation Commands
        try await registerContentGenerationCommands(in: registry, app: app)
    }

    /// Content generation commands for AI-powered operations.
    private static func registerContentGenerationCommands(in registry: ServiceContainer, app: Application) async throws {
        
        // Rules generation command - creates AI-generated game rules
        registry.register(GenerateRulesUseCase.self) { app in
            GenerateRulesUseCase(
                aiInputValidator: try await app.serviceRegistry.resolveRequired(AIInputValidatorServiceInterface.self),
                cacheKeyGenerator: try await app.serviceRegistry.resolveRequired(CacheKeyGeneratorServiceInterface.self),
                aiCache: try await app.serviceRegistry.resolveRequired(AICacheServiceInterface.self),
                llmService: try await app.serviceRegistry.resolveRequired(LLMService.self),
                aiResponseValidator: try await app.serviceRegistry.resolveRequired(AIResponseValidationService.self),
                cacheConfiguration: try app.configuration.cache,
                generatedRuleRepository: try await app.serviceRegistry.resolveRequired((any GeneratedRuleRepository).self)
            )
        }
    }
    
    // MARK: - Queries (Read-Only Operations)
    
    /// Registers all query use cases that read system state.
    ///
    /// Queries are read-only operations that retrieve data from the system
    /// without causing side effects or modifying state.
    private static func registerQueries(in registry: ServiceContainer, app: Application) async throws {
        // Content Queries
        try await registerContentQueries(in: registry, app: app)
    }

    /// Content-related queries for AI analysis operations.
    private static func registerContentQueries(in registry: ServiceContainer, app: Application) async throws {
        
        // Game box analysis query - reads/analyzes game images
        registry.register(AnalyzeGameBoxUseCase.self) { app in
            AnalyzeGameBoxUseCase(
                aiInputValidator: try await app.serviceRegistry.resolveRequired(AIInputValidatorServiceInterface.self),
                llmService: try await app.serviceRegistry.resolveRequired(LLMService.self),
                aiResponseValidator: try await app.serviceRegistry.resolveRequired(AIResponseValidationService.self)
            )
        }
    }
}
