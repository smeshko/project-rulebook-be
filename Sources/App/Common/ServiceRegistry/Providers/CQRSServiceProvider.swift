import Vapor

/// Service provider for CQRS-based use case registration.
///
/// NOTE: All use cases have been migrated to inline controller logic as part of
/// the architecture simplification. This provider is now empty but retained
/// for potential future use cases or as a reference point.
///
/// ## Migration History
/// - Auth use cases → AuthController (Phase 1)
/// - User use cases → UserController (Phase 2)
/// - CacheAdmin use cases → CacheAdminController (Phase 3)
/// - RulesGeneration use cases → RulesGenerationController (Phase 4)
public struct CQRSServiceProvider: ServiceProvider {

    /// Registers all CQRS-organized use cases in the ServiceRegistry.
    ///
    /// Currently empty as all use cases have been migrated to controllers.
    ///
    /// - Parameters:
    ///   - registry: The ServiceContainer to register use cases in
    ///   - app: The Vapor Application instance
    /// - Throws: Service registration errors
    public static func register(in registry: ServiceContainer, app: Application) async throws {
        // All use cases have been migrated to inline controller logic.
        // This provider is retained for potential future use.
    }
}
