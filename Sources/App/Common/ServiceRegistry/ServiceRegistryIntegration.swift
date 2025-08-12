import Vapor

extension Application {
    /// Initializes the ServiceRegistry and registers all services
    public func setupServiceRegistry() async throws {
        // Register all services in the registry
        try await RepositoryServiceProvider.register(in: serviceRegistry, app: self)
        try await ExternalServiceProvider.register(in: serviceRegistry, app: self)
        
        // Start up all services that implement ServiceLifecycle
        try await serviceRegistry.startupAll(self)
    }
    
    /// Shuts down all services in the registry
    public func shutdownServiceRegistry() async throws {
        try await serviceRegistry.shutdownAll(self)
    }
}

// MARK: - Request Extensions for Service Resolution

extension Request {
    /// Resolves a service from the registry
    public func resolveService<T>(_ type: T.Type) async throws -> T {
        try await application.serviceRegistry.resolveRequired(type)
    }
    
    /// Resolves a service from the registry (optional)
    public func resolveServiceOptional<T>(_ type: T.Type) async throws -> T? {
        try await application.serviceRegistry.resolve(type)
    }
}

// MARK: - Service Registry Usage Examples for Controllers
// Controllers can now access services like this:
// let userRepo = try await request.resolveService(any UserRepository.self)
// let llmService = try await request.resolveService(LLMService.self)
// etc.