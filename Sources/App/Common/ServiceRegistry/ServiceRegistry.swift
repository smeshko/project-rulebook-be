import Vapor

public protocol ServiceRegistry: Sendable {
    func register<T>(_ type: T.Type, factory: @escaping @Sendable (Application) async throws -> T)
    func register<T>(_ type: T.Type, instance: T)
    func resolve<T>(_ type: T.Type) async throws -> T?
    func resolveRequired<T>(_ type: T.Type) async throws -> T
    func resolveAll<T>(_ type: T.Type) async -> [T]
    func unregister<T>(_ type: T.Type)
    func isRegistered<T>(_ type: T.Type) -> Bool
}

public protocol ServiceRegistryLifecycle {
    func startupAll(_ app: Application) async throws
    func shutdownAll(_ app: Application) async throws
    func healthCheckAll() async -> [(name: String, healthy: Bool)]
}

public enum ServiceRegistryError: AppError {
    case serviceNotFound(String)
    case serviceInitializationFailed(String, Error)
    case circularDependency([String])
    
    public var status: HTTPResponseStatus {
        .internalServerError
    }
    
    public var reason: String {
        switch self {
        case .serviceNotFound(let type):
            return "Service \(type) not found in registry"
        case .serviceInitializationFailed(let type, let error):
            return "Failed to initialize service \(type): \(error)"
        case .circularDependency(let chain):
            return "Circular dependency detected: \(chain.joined(separator: " -> "))"
        }
    }
    
    public var identifier: String {
        switch self {
        case .serviceNotFound:
            return "service_not_found"
        case .serviceInitializationFailed:
            return "service_initialization_failed"
        case .circularDependency:
            return "circular_dependency"
        }
    }
    
    public var suggestedHTTPStatus: HTTPStatus {
        .internalServerError
    }
}