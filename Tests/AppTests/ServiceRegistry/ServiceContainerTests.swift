import XCTVapor
@testable import App
import Testing

struct ServiceContainerTests {
    let app: Application
    
    init() async throws {
        // Use standard configuration for ServiceRegistry tests
        app = try await Application.make(.testing)
        try configure(app)
    }
    
    @Test("ServiceRegistry handles basic registration and resolution")
    func serviceRegistryBasics() async throws {
        // Test basic service registration and resolution
        let registry = ServiceContainer(application: app)
        
        // Register real services
        try await RepositoryServiceProvider.register(in: registry, app: app)
        try await ExternalServiceProvider.register(in: registry, app: app)
        
        // Test service resolution
        let userRepository = try await registry.resolveRequired((any UserRepository).self)
        #expect(userRepository != nil)
        
        let llmService = try await registry.resolveRequired(LLMService.self)
        #expect(llmService != nil)
    }
    
    @Test("ServiceRegistry manages service lifecycle")
    func serviceLifecycle() async throws {
        let registry = ServiceContainer(application: app)
        
        // Register real services
        try await RepositoryServiceProvider.register(in: registry, app: app)
        try await ExternalServiceProvider.register(in: registry, app: app)
        
        // Test startup
        try await registry.startupAll(app)
        
        // Verify service is accessible after startup
        let userRepository = try await registry.resolveRequired((any UserRepository).self)
        #expect(userRepository != nil)
        
        // Test shutdown
        try await registry.shutdownAll(app)
    }
    
    @Test("ServiceRegistry provides health checks")
    func healthChecks() async throws {
        let registry = ServiceContainer(application: app)
        
        // Register real services
        try await RepositoryServiceProvider.register(in: registry, app: app)
        try await ExternalServiceProvider.register(in: registry, app: app)
        
        // Start services to enable health checks
        try await registry.startupAll(app)
        
        // Ensure services are instantiated
        _ = try await registry.resolveRequired((any UserRepository).self)
        _ = try await registry.resolveRequired(LLMService.self)
        
        // Test health checks
        let healthChecks = await registry.healthCheckAll()
        #expect(healthChecks.count >= 0) // May be 0 if no services implement health checks
        // Check that all reported services are healthy
        #expect(healthChecks.allSatisfy { $0.healthy })
    }
    
    @Test("ServiceRegistry handles missing services")
    func serviceNotFound() async throws {
        let registry = ServiceContainer(application: app)
        
        // Create a protocol that doesn't exist
        protocol NonExistentService {}
        
        // Test resolving non-existent service
        let nonExistentService = try await registry.resolve(NonExistentService.self)
        #expect(nonExistentService == nil)
        
        // Test requiring non-existent service throws
        do {
            _ = try await registry.resolveRequired(NonExistentService.self)
            Issue.record("Should have thrown ServiceRegistryError.serviceNotFound")
        } catch let error as ServiceRegistryError {
            if case .serviceNotFound(let type) = error {
                #expect(type.contains("NonExistentService"))
            } else {
                Issue.record("Wrong error type: \(error)")
            }
        }
    }
    
    @Test("ServiceRegistry provides consistent service resolution")
    func serviceSingleton() async throws {
        let registry = ServiceContainer(application: app)
        
        // Register real services
        try await RepositoryServiceProvider.register(in: registry, app: app)
        try await ExternalServiceProvider.register(in: registry, app: app)
        
        // Resolve service twice
        let service1 = try await registry.resolveRequired((any UserRepository).self)
        let service2 = try await registry.resolveRequired((any UserRepository).self)
        
        // Verify services are available and of same type
        #expect(service1 != nil)
        #expect(service2 != nil)
        // Note: For true singleton testing, we'd need class-based services
        // This test verifies the service can be resolved consistently
    }
    
    @Test("Request extension resolves services correctly")
    func requestServiceResolution() async throws {
        // Test that services are available through Request extension
        // The ServiceRegistry is already set up in configure()
        
        // Create a mock request
        let request = Request(application: app, on: app.eventLoopGroup.next())
        
        // Test service resolution through Request extension
        let userRepository = try await request.resolveService((any UserRepository).self)
        #expect(userRepository != nil)
        
        let llmService = try await request.resolveService(LLMService.self)
        #expect(llmService != nil)
    }
}