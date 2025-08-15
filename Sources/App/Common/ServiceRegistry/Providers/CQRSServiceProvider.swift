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
/// ├── Authentication Commands (login, logout, registration)
/// ├── User Management Commands (create, update, delete)
/// ├── Cache Management Commands (clear, cleanup)
/// └── Content Generation Commands (AI rules generation)
///
/// Queries (Read-Only)
/// ├── User Queries (profile, listing)
/// ├── Cache Queries (stats, health, entries)
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
        
        // Authentication Commands
        try await registerAuthenticationCommands(in: registry, app: app)
        
        // User Management Commands
        try await registerUserManagementCommands(in: registry, app: app)
        
        // Cache Administration Commands
        try await registerCacheManagementCommands(in: registry, app: app)
        
        // Content Generation Commands
        try await registerContentGenerationCommands(in: registry, app: app)
    }
    
    /// Authentication commands for login, logout, registration operations.
    private static func registerAuthenticationCommands(in registry: ServiceContainer, app: Application) async throws {
        
        // Logout command - invalidates refresh tokens
        registry.register(LogoutUseCase.self) { app in
            LogoutUseCase(
                refreshTokenRepository: try await app.serviceRegistry.resolveRequired((any RefreshTokenRepository).self)
            )
        }
        
        // Sign up command - creates new user account
        registry.register(SignUpUseCase.self) { app in
            SignUpUseCase(
                userRepository: try await app.serviceRegistry.resolveRequired((any UserRepository).self),
                refreshTokenRepository: try await app.serviceRegistry.resolveRequired((any RefreshTokenRepository).self),
                emailTokenRepository: try await app.serviceRegistry.resolveRequired((any EmailTokenRepository).self),
                passwordHasher: { password in try await app.password.async.hash(password) },
                randomGenerator: try await app.serviceRegistry.resolveRequired(RandomGeneratorService.self),
                emailService: try await app.serviceRegistry.resolveRequired(EmailService.self),
                configurationService: app.configuration
            )
        }
        
        // Sign in command - authenticates user and creates tokens
        registry.register(SignInUseCase.self) { app in
            SignInUseCase(
                refreshTokenRepository: try await app.serviceRegistry.resolveRequired((any RefreshTokenRepository).self),
                randomGenerator: try await app.serviceRegistry.resolveRequired(RandomGeneratorService.self)
            )
        }
        
        // Token refresh command - rotates authentication tokens
        registry.register(RefreshTokenUseCase.self) { app in
            RefreshTokenUseCase(
                refreshTokenRepository: try await app.serviceRegistry.resolveRequired((any RefreshTokenRepository).self),
                userRepository: try await app.serviceRegistry.resolveRequired((any UserRepository).self),
                jwtSigner: app.jwt.signers.get()!,
                randomGenerator: try await app.serviceRegistry.resolveRequired(RandomGeneratorService.self)
            )
        }
        
        // Apple Sign-In command - handles Apple authentication
        registry.register(AppleSignInUseCase.self) { app in
            AppleSignInUseCase(
                userRepository: try await app.serviceRegistry.resolveRequired((any UserRepository).self),
                refreshTokenRepository: try await app.serviceRegistry.resolveRequired((any RefreshTokenRepository).self),
                appleJWTVerifier: { token, appId in
                    // TODO: Implement proper Apple JWT verification
                    // For now, temporarily disable Apple Sign-In until JWT integration is fixed
                    throw AuthenticationError.invalidEmailOrPassword
                },
                randomGenerator: try await app.serviceRegistry.resolveRequired(RandomGeneratorService.self),
                appIdentifier: Environment.appIdentifier
            )
        }
    }
    
    /// User management commands for profile operations.
    private static func registerUserManagementCommands(in registry: ServiceContainer, app: Application) async throws {
        
        // Update user profile command
        registry.register(UpdateUserProfileUseCase.self) { app in
            UpdateUserProfileUseCase(
                userRepository: try await app.serviceRegistry.resolveRequired((any UserRepository).self)
            )
        }
        
        // Delete user account command
        registry.register(DeleteUserAccountUseCase.self) { app in
            DeleteUserAccountUseCase(
                userRepository: try await app.serviceRegistry.resolveRequired((any UserRepository).self)
            )
        }
    }
    
    /// Cache management commands for cache operations.
    private static func registerCacheManagementCommands(in registry: ServiceContainer, app: Application) async throws {
        
        // Clear cache command
        registry.register(ClearCacheUseCase.self) { app in
            ClearCacheUseCase(
                aiCacheService: try await app.serviceRegistry.resolveRequired(AICacheServiceInterface.self),
                logger: app.logger
            )
        }
        
        // Manual cleanup command
        registry.register(ManualCleanupUseCase.self) { app in
            ManualCleanupUseCase(
                aiCacheService: try await app.serviceRegistry.resolveRequired(AICacheServiceInterface.self),
                logger: app.logger
            )
        }
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
                cacheConfiguration: try app.configuration.cache
            )
        }
    }
    
    // MARK: - Queries (Read-Only Operations)
    
    /// Registers all query use cases that read system state.
    ///
    /// Queries are read-only operations that retrieve data from the system
    /// without causing side effects or modifying state.
    private static func registerQueries(in registry: ServiceContainer, app: Application) async throws {
        
        // User Queries
        try await registerUserQueries(in: registry, app: app)
        
        // Cache Queries
        try await registerCacheQueries(in: registry, app: app)
        
        // Content Queries
        try await registerContentQueries(in: registry, app: app)
    }
    
    /// User-related queries for profile and listing operations.
    private static func registerUserQueries(in registry: ServiceContainer, app: Application) async throws {
        
        // Get current user query
        registry.register(GetCurrentUserUseCase.self) { app in
            GetCurrentUserUseCase()
        }
        
        // List users query
        registry.register(ListUsersUseCase.self) { app in
            ListUsersUseCase(
                userRepository: try await app.serviceRegistry.resolveRequired((any UserRepository).self)
            )
        }
    }
    
    /// Cache-related queries for statistics and monitoring.
    private static func registerCacheQueries(in registry: ServiceContainer, app: Application) async throws {
        
        // Cache statistics query
        registry.register(GetCacheStatsUseCase.self) { app in
            GetCacheStatsUseCase(
                aiCacheService: try await app.serviceRegistry.resolveRequired(AICacheServiceInterface.self),
                logger: app.logger
            )
        }
        
        // Cache entries query
        registry.register(GetCacheEntriesUseCase.self) { app in
            GetCacheEntriesUseCase(
                aiCacheService: try await app.serviceRegistry.resolveRequired(AICacheServiceInterface.self),
                logger: app.logger
            )
        }
        
        // Cache health query
        registry.register(GetCacheHealthUseCase.self) { app in
            GetCacheHealthUseCase(
                aiCacheService: try await app.serviceRegistry.resolveRequired(AICacheServiceInterface.self),
                configurationService: app.configuration,
                logger: app.logger
            )
        }
        
        // Redis health query
        registry.register(GetRedisHealthUseCase.self) { app in
            GetRedisHealthUseCase(
                cacheService: try await app.serviceRegistry.resolveRequired(CacheService.self),
                logger: app.logger
            )
        }
    }
    
    /// Content-related queries for AI analysis operations.
    private static func registerContentQueries(in registry: ServiceContainer, app: Application) async throws {
        
        // Game box analysis query - reads/analyzes game images
        registry.register(AnalyzeGameBoxUseCase.self) { app in
            AnalyzeGameBoxUseCase(
                aiInputValidator: try await app.serviceRegistry.resolveRequired(AIInputValidatorServiceInterface.self),
                cacheKeyGenerator: try await app.serviceRegistry.resolveRequired(CacheKeyGeneratorServiceInterface.self),
                aiCache: try await app.serviceRegistry.resolveRequired(AICacheServiceInterface.self),
                llmService: try await app.serviceRegistry.resolveRequired(LLMService.self),
                aiResponseValidator: try await app.serviceRegistry.resolveRequired(AIResponseValidationService.self),
                cacheConfiguration: try app.configuration.cache
            )
        }
    }
}