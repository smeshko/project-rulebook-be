@testable import App
import XCTest
import Vapor

/// Base test case for unit tests that test individual services, repositories, and business logic.
/// 
/// This class provides common functionality for testing individual components in isolation,
/// with minimal application setup and maximum control over dependencies.
/// Use this for tests that don't require HTTP functionality or full application stack.
final class UnitTestCase {
    private let app: Application
    
    /// Initializes a new unit test case with minimal application setup.
    ///
    /// Creates a lightweight application instance suitable for unit testing
    /// with just the essential services configured.
    ///
    /// - Throws: Configuration or setup errors
    init() async throws {
        self.app = try await Application.make(.testing)
        try setupMinimalConfiguration()
    }
    
    /// Cleans up resources when the test case is deallocated.
    deinit {
        app.shutdown()
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
    
    /// Sets up minimal configuration required for unit testing.
    ///
    /// This configures only the essential services and repositories needed
    /// for unit testing, without the full application stack.
    private func setupMinimalConfiguration() throws {
        // Configure SQLite in-memory database for testing
        app.databases.use(.sqlite(.memory), as: .sqlite)
        
        // Set up JWT for authentication tests (if needed)
        try app.jwt.signers.use(.es256(key: .generate()))
        
        // Configure basic services with test implementations
        app.services.randomGenerator.use(.random)
        app.services.uuidGenerator.use(.random)
        app.services.email.use(.fake)
    }
}