import Vapor

public protocol ServiceProvider {
    static func register(in registry: ServiceContainer, app: Application) async throws
}

public protocol ServiceConfiguration {
    associatedtype ServiceType
    
    static func configure(from environment: Environment) -> Self
    func makeService(app: Application) async throws -> ServiceType
}

// MARK: - Backward Compatibility Bridge

public struct ServiceRegistryBridge {
    private let registry: ServiceContainer
    private let app: Application
    
    public init(registry: ServiceContainer, app: Application) {
        self.registry = registry
        self.app = app
    }
    
    public func bridgeExistingService<T>(
        _ type: T.Type,
        from keyPath: KeyPath<Application.Services, Application.Service<T>>
    ) async throws {
        // Get the existing service through Vapor's DI
        let service = app.services[keyPath: keyPath].service
        
        // Register it in our new registry
        registry.register(type, instance: service)
    }
    
    public func bridgeRepository<T>(
        _ type: T.Type,
        factory: @escaping @Sendable (Application) async throws -> T
    ) {
        registry.register(type, factory: factory)
    }
}