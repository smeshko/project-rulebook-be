import Testing
import VaporTesting
import Vapor
@testable import App

/// Integration test case for HTTP endpoint testing.
/// 
/// This struct provides common functionality for testing Vapor routes and controllers,
/// including application setup, test world initialization, and endpoint testing helpers.
/// Use this for tests that involve HTTP requests/responses and full application stack.
///
/// Uses IsolatedTestWorld for complete suite-level isolation, preventing shared state
/// contamination between concurrent test suites in Swift Testing.
struct IntegrationTestCase {
    let app: Application
    let testWorld: IsolatedTestWorld
    
    /// Initializes a new integration test case with a fully isolated application.
    ///
    /// Creates a fresh IsolatedTestWorld instance for complete suite isolation.
    ///
    /// - Throws: Configuration or setup errors
    init() async throws {
        self.testWorld = try await IsolatedTestWorld()
        self.app = testWorld.app
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
    var world: IsolatedTestWorld {
        testWorld
    }
}