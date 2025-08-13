import XCTVapor
@testable import App

final class SimpleAspectTests: XCTestCase {
    
    var app: Application!
    
    override func setUp() async throws {
        app = try await Application.make(.testing)
        try configure(app)
    }
    
    override func tearDown() async throws {
        try await app.asyncShutdown()
    }
    
    func testBasicAspectMiddleware() throws {
        // Given
        let middleware = AspectMiddleware(aspects: [])
        app.middleware.use(middleware)
        
        app.get("test") { _ in
            return HTTPStatus.ok
        }
        
        // When
        try app.test(.GET, "/test") { response in
            // Then
            XCTAssertEqual(response.status, .ok)
        }
    }
    
    func testAspectRegistryCreation() {
        // Given/When
        let registry = AspectRegistry()
        
        // Then
        XCTAssertEqual(registry.all().count, 0)
    }
}