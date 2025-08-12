import XCTVapor
@testable import App

final class ServiceContainerTests: XCTestCase {
    var app: Application!
    
    override func setUp() async throws {
        // Use full application setup for ServiceRegistry tests since they need configuration
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
        
        // Register demo service
        try await DemoServiceProvider.register(in: registry, app: app)
        
        // Test service resolution
        let demoService = try await registry.resolveRequired(DemoService.self)
        let message = demoService.getMessage()
        
        XCTAssertEqual(message, "Demo Service: ServiceRegistry is working!")
    }
    
    func testServiceLifecycle() async throws {
        let registry = ServiceContainer(application: app)
        
        // Register demo service
        try await DemoServiceProvider.register(in: registry, app: app)
        
        // Test startup
        try await registry.startupAll(app)
        
        // Verify service is accessible after startup
        let demoService = try await registry.resolveRequired(DemoService.self)
        XCTAssertEqual(demoService.getMessage(), "Demo Service: ServiceRegistry is working!")
        
        // Test shutdown
        try await registry.shutdownAll(app)
    }
    
    func testHealthChecks() async throws {
        let registry = ServiceContainer(application: app)
        
        // Register demo service
        try await DemoServiceProvider.register(in: registry, app: app)
        
        // Ensure service is instantiated
        _ = try await registry.resolveRequired(DemoService.self)
        
        // Test health checks
        let healthChecks = await registry.healthCheckAll()
        XCTAssertEqual(healthChecks.count, 1)
        XCTAssertEqual(healthChecks.first?.name, "Demo Service")
        XCTAssertTrue(healthChecks.first?.healthy ?? false)
    }
    
    func testServiceNotFound() async throws {
        let registry = ServiceContainer(application: app)
        
        // Test resolving non-existent service
        let nonExistentService = try await registry.resolve(DemoService.self)
        XCTAssertNil(nonExistentService)
        
        // Test requiring non-existent service throws
        do {
            _ = try await registry.resolveRequired(DemoService.self)
            XCTFail("Should have thrown ServiceRegistryError.serviceNotFound")
        } catch let error as ServiceRegistryError {
            if case .serviceNotFound(let type) = error {
                XCTAssertTrue(type.contains("DemoService"))
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        }
    }
    
    func testServiceSingleton() async throws {
        let registry = ServiceContainer(application: app)
        
        // Register demo service
        try await DemoServiceProvider.register(in: registry, app: app)
        
        // Resolve service twice
        let service1 = try await registry.resolveRequired(DemoService.self)
        let service2 = try await registry.resolveRequired(DemoService.self)
        
        // Verify same instance (singleton behavior) by casting to concrete type
        guard let concrete1 = service1 as? SimpleDemoService,
              let concrete2 = service2 as? SimpleDemoService else {
            XCTFail("Services should be SimpleDemoService instances")
            return
        }
        
        XCTAssertTrue(concrete1 === concrete2)
    }
    
    func testRequestServiceResolution() async throws {
        // Test Application.setupServiceRegistry integration
        // Note: Configuration is already initialized by the test framework
        try await app.setupServiceRegistry()
        
        // Register demo service in the app's registry
        try await DemoServiceProvider.register(in: app.serviceRegistry, app: app)
        
        // Create a mock request
        let request = Request(application: app, on: app.eventLoopGroup.next())
        
        // Test service resolution through Request extension
        let demoService = try await request.resolveService(DemoService.self)
        let message = demoService.getMessage()
        
        XCTAssertEqual(message, "Demo Service: ServiceRegistry is working!")
    }
}