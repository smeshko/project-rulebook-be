import Testing
import VaporTesting
import Vapor
@testable import App

/// Swift Testing version of integration test case for HTTP endpoint testing.
/// 
/// This struct provides common functionality for testing Vapor routes and controllers,
/// including application setup, test world initialization, and endpoint testing helpers.
/// Use this for tests that involve HTTP requests/responses and full application stack.
struct SwiftTestingIntegrationTestCase {
    let app: Application
    let testWorld: TestWorld
    
    /// Initializes a new integration test case with a fully configured application.
    ///
    /// - Throws: Configuration or setup errors
    init() async throws {
        self.app = try await withApp { app in return app }
        self.testWorld = try await TestWorld(app: app)
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
        beforeRequest: @escaping (inout TestingHTTPRequest) throws -> () = { _ in },
        afterResponse: @escaping (TestingHTTPResponse) async throws -> () = { _ in }
    ) async throws -> TestingApplicationTester {
        return try await app.test(
            method,
            path,
            headers: headers,
            beforeRequest: beforeRequest,
            afterResponse: afterResponse
        )
    }
    
    /// Access to the underlying application for advanced test scenarios.
    var application: Application {
        app
    }
    
    /// Access to the test world for repository and service mocking.
    var world: TestWorld {
        testWorld
    }
}