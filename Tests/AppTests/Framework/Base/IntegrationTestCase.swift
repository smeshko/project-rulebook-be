@testable import App
import XCTVapor
import XCTest
import Vapor

/// Base test case for integration tests that test HTTP endpoints.
/// 
/// This struct provides common functionality for testing Vapor routes and controllers,
/// including application setup, test world initialization, and endpoint testing helpers.
/// Use this for tests that involve HTTP requests/responses and full application stack.
struct IntegrationTestCase {
    private let testWorld: TestWorld
    
    /// Initializes a new integration test case with a fully configured application.
    ///
    /// - Throws: Configuration or setup errors
    init() async throws {
        let app = try await withApp { app in return app }
        self.testWorld = try TestWorld(app: app)
    }
    
    /// Performs an HTTP test against the application.
    ///
    /// This is a convenience method that wraps Vapor's testing functionality
    /// with proper application lifecycle management.
    ///
    /// - Parameters:
    ///   - method: HTTP method to use
    ///   - path: URL path to test
    ///   - headers: HTTP headers to include
    ///   - beforeRequest: Optional closure to configure the request
    ///   - afterResponse: Closure to validate the response
    /// - Throws: Any errors from the test execution
    @discardableResult
    func test(
        _ method: HTTPMethod,
        _ path: String,
        headers: HTTPHeaders = [:],
        beforeRequest: @escaping (inout XCTHTTPRequest) throws -> () = { _ in },
        afterResponse: @escaping (XCTHTTPResponse) throws -> () = { _ in }
    ) throws -> XCTApplicationTester {
        return try testWorld.app.test(
            method,
            path,
            headers: headers,
            beforeRequest: beforeRequest,
            afterResponse: afterResponse
        )
    }
    
    /// Access to the underlying application for advanced test scenarios.
    var app: Application {
        testWorld.app
    }
    
    /// Access to the test world for repository and service mocking.
    var world: TestWorld {
        testWorld
    }
}

/// Creates and configures a test application.
///
/// This function handles the complete lifecycle of a Vapor application for testing,
/// ensuring proper setup and cleanup.
///
/// - Parameter configure: Optional closure to perform additional configuration
/// - Returns: Configured application instance
/// - Throws: Any configuration errors
func withApp<T>(_ closure: (Application) throws -> T) async throws -> T {
    let app = try await Application.make(.testing)
    
    do {
        try configure(app)
        let result = try closure(app)
        try await app.asyncShutdown()
        return result
    } catch {
        try await app.asyncShutdown()
        throw error
    }
}