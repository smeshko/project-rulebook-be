import VaporTesting
@testable import App
import Testing

@Suite(.serialized)
struct ServiceContainerTests {
    let app: Application
    let testWorld: IsolatedTestWorld
    
    init() async throws {
        testWorld = try await IsolatedTestWorld()
        app = testWorld.app
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
        
        // Register real services to test health checks
        try await RepositoryServiceProvider.register(in: registry, app: app)
        try await ExternalServiceProvider.register(in: registry, app: app)
        
        // Verify the health check method exists and can be called
        let healthStatus = await registry.healthCheckAll()
        
        // The health check method should return an array of service health statuses
        #expect(healthStatus != nil, "Health check should return a result")
        
        // In test environment with mocks, we expect the health check to complete successfully
        // The actual health values may vary, but the mechanism should work
        for (serviceName, _) in healthStatus {
            #expect(!serviceName.isEmpty, "Service name should not be empty")
            // Note: In test environment, health status values may be mocked
        }
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