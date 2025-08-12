import Vapor

public protocol ServiceLifecycle {
    func startup(_ app: Application) async throws
    func shutdown(_ app: Application) async throws
}

public protocol ServiceHealthCheck {
    func isHealthy() async -> Bool
    func healthCheckName() -> String
}

public extension ServiceLifecycle {
    func startup(_ app: Application) async throws {}
    func shutdown(_ app: Application) async throws {}
}

public extension ServiceHealthCheck {
    func healthCheckName() -> String {
        String(describing: type(of: self))
    }
}