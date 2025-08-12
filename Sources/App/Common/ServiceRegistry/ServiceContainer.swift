import Vapor
import NIOConcurrencyHelpers

/// Thread-safe storage for services using NIOLock for synchronization
public final class ServiceContainer: ServiceRegistry, ServiceRegistryLifecycle, @unchecked Sendable {
    // Using NIOLock for thread-safe synchronization that works with async contexts
    private let lock = NIOLock()
    private var factories: [ObjectIdentifier: Any] = [:]
    private var instances: [ObjectIdentifier: Any] = [:]
    private var lifecycleServices: [ObjectIdentifier: ServiceLifecycle] = [:]
    private var healthCheckServices: [ObjectIdentifier: ServiceHealthCheck] = [:]
    private var resolutionStack: Set<ObjectIdentifier> = []
    private let application: Application
    
    public init(application: Application) {
        self.application = application
    }
    
    // MARK: - ServiceRegistry
    
    public func register<T>(_ type: T.Type, factory: @escaping @Sendable (Application) async throws -> T) {
        let key = ObjectIdentifier(type)
        
        // Validate factory type at registration time to catch issues early
        let wrappedFactory: @Sendable (Application) async throws -> Any = { app in
            try await factory(app)
        }
        
        lock.withLock {
            factories[key] = wrappedFactory
            instances.removeValue(forKey: key)
        }
    }
    
    public func register<T>(_ type: T.Type, instance: T) {
        let key = ObjectIdentifier(type)
        
        lock.withLock {
            instances[key] = instance
            factories.removeValue(forKey: key)
            
            // Track lifecycle and health check services using ObjectIdentifier for reliable removal
            if let lifecycle = instance as? ServiceLifecycle {
                lifecycleServices[key] = lifecycle
            }
            
            if let healthCheck = instance as? ServiceHealthCheck {
                healthCheckServices[key] = healthCheck
            }
        }
    }
    
    public func resolve<T>(_ type: T.Type) async throws -> T? {
        let key = ObjectIdentifier(type)
        
        // Check for circular dependency
        let isCircular = lock.withLock { resolutionStack.contains(key) }
        if isCircular {
            let chain = lock.withLock {
                resolutionStack.map { String(describing: $0) } + [String(describing: type)]
            }
            throw ServiceRegistryError.circularDependency(chain)
        }
        
        // Check for existing instance
        let existingInstance = lock.withLock { instances[key] as? T }
        if let instance = existingInstance {
            return instance
        }
        
        // Check for factory
        let factory = lock.withLock { factories[key] }
        guard let factory = factory else {
            return nil
        }
        
        // Add to resolution stack to detect circular dependencies
        lock.withLock { _ = resolutionStack.insert(key) }
        defer { lock.withLock { _ = resolutionStack.remove(key) } }
        
        // Create instance using factory (outside of lock to avoid deadlock)
        do {
            // Use the validated factory type from registration
            guard let typedFactory = factory as? @Sendable (Application) async throws -> Any else {
                throw ServiceRegistryError.serviceInitializationFailed(
                    String(describing: type),
                    ServiceRegistryError.factoryTypeMismatch(String(describing: type))
                )
            }
            
            let anyInstance = try await typedFactory(application)
            guard let instance = anyInstance as? T else {
                throw ServiceRegistryError.serviceInitializationFailed(
                    String(describing: type),
                    ServiceRegistryError.factoryTypeMismatch(String(describing: type))
                )
            }
            
            // Store the instance
            lock.withLock {
                instances[key] = instance
                
                // Track lifecycle and health check services using ObjectIdentifier for reliable removal
                if let lifecycle = instance as? ServiceLifecycle {
                    lifecycleServices[key] = lifecycle
                }
                
                if let healthCheck = instance as? ServiceHealthCheck {
                    healthCheckServices[key] = healthCheck
                }
            }
            
            return instance
        } catch {
            throw ServiceRegistryError.serviceInitializationFailed(
                String(describing: type),
                error
            )
        }
    }
    
    public func resolveRequired<T>(_ type: T.Type) async throws -> T {
        guard let service = try await resolve(type) else {
            throw ServiceRegistryError.serviceNotFound(String(describing: type))
        }
        return service
    }
    
    public func resolveAll<T>(_ type: T.Type) async -> [T] {
        lock.withLock {
            instances.compactMap { $0.value as? T }
        }
    }
    
    public func unregister<T>(_ type: T.Type) {
        let key = ObjectIdentifier(type)
        
        lock.withLock {
            // Remove from lifecycle and health check tracking using ObjectIdentifier
            lifecycleServices.removeValue(forKey: key)
            healthCheckServices.removeValue(forKey: key)
            
            instances.removeValue(forKey: key)
            factories.removeValue(forKey: key)
        }
    }
    
    public func isRegistered<T>(_ type: T.Type) -> Bool {
        let key = ObjectIdentifier(type)
        
        return lock.withLock {
            instances[key] != nil || factories[key] != nil
        }
    }
    
    // MARK: - ServiceRegistryLifecycle
    
    public func startupAll(_ app: Application) async throws {
        let services = lock.withLock {
            Array(lifecycleServices.values)
        }
        
        for service in services {
            try await service.startup(app)
        }
    }
    
    public func shutdownAll(_ app: Application) async throws {
        let services = lock.withLock {
            Array(lifecycleServices.values.reversed())
        }
        
        for service in services {
            try await service.shutdown(app)
        }
    }
    
    public func healthCheckAll() async -> [(name: String, healthy: Bool)] {
        let services = lock.withLock {
            Array(healthCheckServices.values)
        }
        
        // Sequential health checks to avoid concurrency complexity
        // TODO: Implement concurrent health checks with proper Sendable handling
        var results: [(name: String, healthy: Bool)] = []
        
        for service in services {
            let isHealthy = await service.isHealthy()
            results.append((
                name: service.healthCheckName(),
                healthy: isHealthy
            ))
        }
        
        return results
    }
}

// MARK: - Application Integration

extension Application {
    public struct ServiceRegistryKey: StorageKey {
        public typealias Value = ServiceContainer
    }
    
    public var serviceRegistry: ServiceContainer {
        get {
            if let existing = storage[ServiceRegistryKey.self] {
                return existing
            }
            let registry = ServiceContainer(application: self)
            storage[ServiceRegistryKey.self] = registry
            return registry
        }
        set {
            storage[ServiceRegistryKey.self] = newValue
        }
    }
}

extension Request {
    public var serviceRegistry: ServiceContainer {
        application.serviceRegistry
    }
}