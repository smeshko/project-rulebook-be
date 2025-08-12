import Vapor

/// Service provider for registering use cases in the ServiceRegistry.
///
/// This provider manages the registration of all use case implementations,
/// providing dependency injection for business logic components.
///
/// ## Registration Pattern
///
/// Use cases are registered with their dependencies resolved from the ServiceRegistry:
/// ```swift
/// registry.register(LogoutUseCase.self) { app in
///     LogoutUseCase(
///         refreshTokenRepository: try await app.serviceRegistry.resolveRequired((any RefreshTokenRepository).self)
///     )
/// }
/// ```
///
/// ## Integration
///
/// This provider is called during application setup to register all use cases
/// in the dependency injection container for later resolution by controllers.
public struct UseCaseServiceProvider: ServiceProvider {
    
    /// Registers all use cases in the ServiceRegistry.
    ///
    /// This method registers use cases with their required dependencies resolved
    /// from the ServiceRegistry, enabling clean dependency injection patterns.
    ///
    /// - Parameters:
    ///   - registry: The ServiceContainer to register use cases in
    ///   - app: The Vapor Application instance
    /// - Throws: Service registration errors
    public static func register(in registry: ServiceContainer, app: Application) async throws {
        
        // MARK: - Authentication Use Cases
        
        /// Logout use case for handling user logout business logic
        registry.register(LogoutUseCase.self) { app in
            LogoutUseCase(
                refreshTokenRepository: try await app.serviceRegistry.resolveRequired((any RefreshTokenRepository).self)
            )
        }
        
        /// Sign-up use case for handling user registration business logic
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
        
        /// Sign-in use case for handling user authentication business logic
        registry.register(SignInUseCase.self) { app in
            SignInUseCase(
                refreshTokenRepository: try await app.serviceRegistry.resolveRequired((any RefreshTokenRepository).self),
                randomGenerator: try await app.serviceRegistry.resolveRequired(RandomGeneratorService.self)
            )
        }
        
        /// Apple Sign-In use case for handling Apple authentication business logic
        // TODO: Fix Apple JWT verification service integration
        // registry.register(AppleSignInUseCase.self) { app in
        //     AppleSignInUseCase(
        //         userRepository: try await app.serviceRegistry.resolveRequired((any UserRepository).self),
        //         refreshTokenRepository: try await app.serviceRegistry.resolveRequired((any RefreshTokenRepository).self),
        //         appleJWTVerifier: { token, appId in try await app.jwt.apple.verify(token, applicationIdentifier: appId) },
        //         randomGenerator: try await app.serviceRegistry.resolveRequired(RandomGeneratorService.self),
        //         appIdentifier: Environment.appIdentifier
        //     )
        // }
        
        /// Refresh token use case for handling JWT token refresh business logic
        registry.register(RefreshTokenUseCase.self) { app in
            RefreshTokenUseCase(
                refreshTokenRepository: try await app.serviceRegistry.resolveRequired((any RefreshTokenRepository).self),
                userRepository: try await app.serviceRegistry.resolveRequired((any UserRepository).self),
                jwtSigner: app.jwt.signers.get()!,
                randomGenerator: try await app.serviceRegistry.resolveRequired(RandomGeneratorService.self)
            )
        }
        
        // MARK: - Rules Generation Use Cases
        
        /// Analyze game box use case for AI-powered game identification business logic
        registry.register(AnalyzeGameBoxUseCase.self) { app in
            AnalyzeGameBoxUseCase(
                gameIdentificationService: try await app.serviceRegistry.resolveRequired(GameIdentificationService.self)
            )
        }
        
        /// Generate rules use case for AI-powered rules generation business logic
        registry.register(GenerateRulesUseCase.self) { app in
            GenerateRulesUseCase(
                rulesOrchestrationService: try await app.serviceRegistry.resolveRequired(RulesOrchestrationService.self)
            )
        }
        
        // MARK: - User Management Use Cases
        
        /// Get current user use case for retrieving authenticated user profile business logic
        registry.register(GetCurrentUserUseCase.self) { app in
            GetCurrentUserUseCase()
        }
        
        /// Update user profile use case for modifying user profile data business logic
        registry.register(UpdateUserProfileUseCase.self) { app in
            UpdateUserProfileUseCase(
                userRepository: try await app.serviceRegistry.resolveRequired((any UserRepository).self)
            )
        }
        
        /// Delete user account use case for removing user accounts business logic
        registry.register(DeleteUserAccountUseCase.self) { app in
            DeleteUserAccountUseCase(
                userRepository: try await app.serviceRegistry.resolveRequired((any UserRepository).self)
            )
        }
        
        /// List users use case for admin user listing business logic
        registry.register(ListUsersUseCase.self) { app in
            ListUsersUseCase(
                userRepository: try await app.serviceRegistry.resolveRequired((any UserRepository).self)
            )
        }
        
        // MARK: - Cache Administration Use Cases
        
        /// Get cache statistics use case for retrieving cache performance metrics business logic
        registry.register(GetCacheStatsUseCase.self) { app in
            GetCacheStatsUseCase(
                aiCacheService: app.serviceCache.aiCacheService,
                logger: app.logger
            )
        }
        
        /// Clear cache use case for removing all cache entries business logic
        registry.register(ClearCacheUseCase.self) { app in
            ClearCacheUseCase(
                aiCacheService: app.serviceCache.aiCacheService,
                logger: app.logger
            )
        }
        
        /// Get cache entries use case for listing cached entries with metadata business logic
        registry.register(GetCacheEntriesUseCase.self) { app in
            GetCacheEntriesUseCase(
                aiCacheService: app.serviceCache.aiCacheService,
                logger: app.logger
            )
        }
        
        /// Manual cleanup use case for triggering expired entries cleanup business logic
        registry.register(ManualCleanupUseCase.self) { app in
            ManualCleanupUseCase(
                aiCacheService: app.serviceCache.aiCacheService,
                logger: app.logger
            )
        }
        
        /// Get cache health use case for assessing cache performance and health status business logic
        registry.register(GetCacheHealthUseCase.self) { app in
            GetCacheHealthUseCase(
                aiCacheService: app.serviceCache.aiCacheService,
                configurationService: app.configuration,
                logger: app.logger
            )
        }
    }
}