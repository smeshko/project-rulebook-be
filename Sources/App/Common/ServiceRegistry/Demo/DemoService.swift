import Vapor

// MARK: - Demo Service for ServiceRegistry Testing

protocol DemoService: Sendable {
    func getMessage() -> String
    func performHealthCheck() async -> Bool
}

final class SimpleDemoService: DemoService, ServiceLifecycle, ServiceHealthCheck {
    private let message: String
    private let app: Application
    
    init(message: String, app: Application) {
        self.message = message
        self.app = app
    }
    
    func getMessage() -> String {
        return "Demo Service: \(message)"
    }
    
    func performHealthCheck() async -> Bool {
        return true
    }
    
    // MARK: - ServiceLifecycle
    
    func startup(_ app: Application) async throws {
        app.logger.info("Demo Service started with message: \(message)")
    }
    
    func shutdown(_ app: Application) async throws {
        app.logger.info("Demo Service shutting down")
    }
    
    // MARK: - ServiceHealthCheck
    
    func isHealthy() async -> Bool {
        return await performHealthCheck()
    }
    
    func healthCheckName() -> String {
        return "Demo Service"
    }
}

// MARK: - Demo Service Provider

public struct DemoServiceProvider: ServiceProvider {
    public static func register(in registry: ServiceContainer, app: Application) async throws {
        registry.register(DemoService.self) { app in
            SimpleDemoService(message: "ServiceRegistry is working!", app: app)
        }
    }
}