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
        
        // Future use cases will be registered here following the same pattern
    }
}