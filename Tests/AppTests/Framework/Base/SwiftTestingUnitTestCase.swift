import Testing
import Vapor
@testable import App

/// Swift Testing version of unit test case for isolated business logic testing.
/// 
/// This struct provides common functionality for testing individual components in isolation,
/// with minimal application setup and maximum control over dependencies.
/// Use this for tests that don't require HTTP functionality or full application stack.
///
/// Uses IsolatedTestWorld for complete suite-level isolation, preventing shared state
/// contamination between concurrent test suites in Swift Testing.
struct SwiftTestingUnitTestCase {
    let app: Application
    let testWorld: IsolatedTestWorld
    
    /// Initializes a new unit test case with isolated application setup.
    ///
    /// Creates an IsolatedTestWorld instance suitable for unit testing
    /// with all necessary services configured in isolation.
    ///
    /// - Throws: Configuration or setup errors
    init() async throws {
        self.testWorld = try await IsolatedTestWorld()
        self.app = testWorld.app
    }
    
    /// Access to the application instance for service and repository access.
    var application: Application {
        app
    }
    
    /// Creates a mock request for testing services that require request context.
    ///
    /// Many services in the application follow the pattern of requiring a Request
    /// parameter for dependency injection. This method creates a minimal request
    /// for testing those services.
    ///
    /// - Returns: Mock request instance
    func makeMockRequest() -> Request {
        Request(
            application: app,
            method: .GET,
            url: "http://localhost/test",
            on: app.eventLoopGroup.next()
        )
    }
}