import Vapor
import Fluent

public struct RepositoryServiceProvider: ServiceProvider {
    public static func register(in registry: ServiceContainer, app: Application) async throws {
        // Register User Repository
        registry.register((any UserRepository).self) { app in
            DatabaseUserRepository(database: app.db)
        }
        
        // Register Email Token Repository
        registry.register((any EmailTokenRepository).self) { app in
            DatabaseEmailTokenRepository(database: app.db)
        }
        
        // Register Refresh Token Repository
        registry.register((any RefreshTokenRepository).self) { app in
            DatabaseRefreshTokenRepository(database: app.db)
        }
        
        // Register Password Token Repository
        registry.register((any PasswordTokenRepository).self) { app in
            DatabasePasswordTokenRepository(database: app.db)
        }

        // Register Generated Rule Repository
        registry.register((any GeneratedRuleRepository).self) { app in
            DatabaseGeneratedRuleRepository(database: app.db)
        }
    }
}
