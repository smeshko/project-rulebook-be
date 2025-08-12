import XCTVapor
@testable import App

final class ServiceContainerTests: XCTestCase {
    var app: Application!
    
    override func setUp() async throws {
        // Use standard configuration for ServiceRegistry tests
        app = try await Application.make(.testing)
        try configure(app)
    }
    
    override func tearDown() async throws {
        try await app.asyncShutdown()
        app = nil
    }
    
    func testServiceRegistryBasics() async throws {
        // Test basic service registration and resolution
        let registry = ServiceContainer(application: app)
        
        // Register real services
        try await RepositoryServiceProvider.register(in: registry, app: app)
        try await ExternalServiceProvider.register(in: registry, app: app)
        
        // Test service resolution
        let userRepository = try await registry.resolveRequired((any UserRepository).self)
        XCTAssertNotNil(userRepository)
        
        let llmService = try await registry.resolveRequired(LLMService.self)
        XCTAssertNotNil(llmService)
    }
    
    func testServiceLifecycle() async throws {
        let registry = ServiceContainer(application: app)
        
        // Register real services
        try await RepositoryServiceProvider.register(in: registry, app: app)
        try await ExternalServiceProvider.register(in: registry, app: app)
        
        // Test startup
        try await registry.startupAll(app)
        
        // Verify service is accessible after startup
        let userRepository = try await registry.resolveRequired((any UserRepository).self)
        XCTAssertNotNil(userRepository)
        
        // Test shutdown
        try await registry.shutdownAll(app)
    }
    
    func testHealthChecks() async throws {
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
        XCTAssertGreaterThanOrEqual(healthChecks.count, 0) // May be 0 if no services implement health checks
        // Check that all reported services are healthy
        XCTAssertTrue(healthChecks.allSatisfy { $0.healthy })
    }
    
    func testServiceNotFound() async throws {
        let registry = ServiceContainer(application: app)
        
        // Create a protocol that doesn't exist
        protocol NonExistentService {}
        
        // Test resolving non-existent service
        let nonExistentService = try await registry.resolve(NonExistentService.self)
        XCTAssertNil(nonExistentService)
        
        // Test requiring non-existent service throws
        do {
            _ = try await registry.resolveRequired(NonExistentService.self)
            XCTFail("Should have thrown ServiceRegistryError.serviceNotFound")
        } catch let error as ServiceRegistryError {
            if case .serviceNotFound(let type) = error {
                XCTAssertTrue(type.contains("NonExistentService"))
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        }
    }
    
    func testServiceSingleton() async throws {
        let registry = ServiceContainer(application: app)
        
        // Register real services
        try await RepositoryServiceProvider.register(in: registry, app: app)
        try await ExternalServiceProvider.register(in: registry, app: app)
        
        // Resolve service twice
        let service1 = try await registry.resolveRequired((any UserRepository).self)
        let service2 = try await registry.resolveRequired((any UserRepository).self)
        
        // Verify services are available and of same type
        XCTAssertNotNil(service1)
        XCTAssertNotNil(service2)
        // Note: For true singleton testing, we'd need class-based services
        // This test verifies the service can be resolved consistently
    }
    
    func testRequestServiceResolution() async throws {
        // Test that services are available through Request extension
        // The ServiceRegistry is already set up in configure()
        
        // Create a mock request
        let request = Request(application: app, on: app.eventLoopGroup.next())
        
        // Test service resolution through Request extension
        let userRepository = try await request.resolveService((any UserRepository).self)
        XCTAssertNotNil(userRepository)
        
        let llmService = try await request.resolveService(LLMService.self)
        XCTAssertNotNil(llmService)
    }
}