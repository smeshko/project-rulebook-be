import XCTVapor
@testable import App

final class AspectMiddlewareTests: XCTestCase {
    
    var app: Application!
    
    override func setUp() async throws {
        app = try await Application.make(.testing)
        try configure(app)
        
        // Add test routes
        app.get("test") { _ in
            return HTTPStatus.ok
        }
    }
    
    override func tearDown() async throws {
        try await app.asyncShutdown()
    }
    
    // MARK: - Aspect Execution Order Tests
    
    func testAspectsExecuteInCorrectOrder() throws {
        // Given
        final class OrderTracker: @unchecked Sendable {
            var executionOrder: [String] = []
        }
        let tracker = OrderTracker()
        
        let aspect1 = TestAspect(
            name: "Aspect1",
            onBefore: { _, _ in tracker.executionOrder.append("Aspect1-before") },
            onAfter: { _, response, _ in tracker.executionOrder.append("Aspect1-after"); return response },
            onError: { _, _, _ in tracker.executionOrder.append("Aspect1-error") }
        )
        
        let aspect2 = TestAspect(
            name: "Aspect2",
            onBefore: { _, _ in tracker.executionOrder.append("Aspect2-before") },
            onAfter: { _, response, _ in tracker.executionOrder.append("Aspect2-after"); return response },
            onError: { _, _, _ in tracker.executionOrder.append("Aspect2-error") }
        )
        
        let middleware = AspectMiddleware(aspects: [aspect1, aspect2])
        app.middleware.use(middleware, at: .beginning)
        
        // When
        try app.test(.GET, "/test") { response in
            // Then
            XCTAssertEqual(tracker.executionOrder, [
                "Aspect1-before",
                "Aspect2-before",
                "Aspect2-after",
                "Aspect1-after"
            ])
        }
    }
    
    func testAspectContextPropagation() throws {
        // Given
        let testValue = "test-value"
        
        final class ValueHolder: @unchecked Sendable {
            var retrievedValue: String?
        }
        let holder = ValueHolder()
        
        let setAspect = TestAspect(
            name: "SetAspect",
            onBefore: { _, context in
                context.set(testValue, for: TestContextKey.self)
            }
        )
        
        let getAspect = TestAspect(
            name: "GetAspect",
            onAfter: { _, response, context in
                holder.retrievedValue = context.get(TestContextKey.self)
                return response
            }
        )
        
        let middleware = AspectMiddleware(aspects: [setAspect, getAspect])
        app.middleware.use(middleware, at: .beginning)
        
        // When
        try app.test(.GET, "/test") { response in
            // Then
            XCTAssertEqual(holder.retrievedValue, testValue)
        }
    }
    
    func testAspectErrorHandling() async throws {
        // Given
        final class ErrorTracker: @unchecked Sendable {
            var errorHandled = false
            var capturedError: Error?
        }
        let tracker = ErrorTracker()
        
        let errorAspect = TestAspect(
            name: "ErrorAspect",
            onError: { request, error, context in
                tracker.errorHandled = true
                tracker.capturedError = error
            }
        )
        
        // Create a mock request
        let testRequest = Request(
            application: app,
            method: .GET,
            url: URI(path: "/test"),
            on: app.eventLoopGroup.next()
        )
        
        let middleware = AspectMiddleware(aspects: [errorAspect])
        var context = AspectContext()
        
        // Create a mock next responder that throws an error
        let nextResponder = MockResponder { _ in
            throw Abort(.badRequest, reason: "Test error")
        }
        
        // When
        do {
            _ = try await middleware.respond(to: testRequest, chainingTo: nextResponder)
            XCTFail("Expected error to be thrown")
        } catch {
            // Then
            XCTAssertTrue(tracker.errorHandled, "Aspect should have handled the error")
            XCTAssertNotNil(tracker.capturedError, "Error should have been captured")
            XCTAssertEqual((tracker.capturedError as? Abort)?.status, .badRequest)
        }
    }
    
    // MARK: - AspectRegistry Tests
    
    func testAspectRegistryPriorityOrdering() {
        // Given
        let registry = AspectRegistry()
        
        final class OrderTracker: @unchecked Sendable {
            var executionOrder: [String] = []
        }
        let tracker = OrderTracker()
        
        let lowPriority = TestAspect(
            name: "Low",
            onBefore: { _, _ in tracker.executionOrder.append("Low") }
        )
        let highPriority = TestAspect(
            name: "High",
            onBefore: { _, _ in tracker.executionOrder.append("High") }
        )
        let mediumPriority = TestAspect(
            name: "Medium",
            onBefore: { _, _ in tracker.executionOrder.append("Medium") }
        )
        
        // When
        registry.register(lowPriority, priority: 100)
        registry.register(highPriority, priority: 1000)
        registry.register(mediumPriority, priority: 500)
        
        // Then
        let aspects = registry.all()
        XCTAssertEqual(aspects.count, 3)
        // Verify they are sorted by priority (descending)
        XCTAssertTrue(aspects[0] is TestAspect)
        XCTAssertEqual((aspects[0] as? TestAspect)?.name, "High")
        XCTAssertEqual((aspects[1] as? TestAspect)?.name, "Medium")
        XCTAssertEqual((aspects[2] as? TestAspect)?.name, "Low")
    }
    
    func testAspectRegistryClear() {
        // Given
        let registry = AspectRegistry()
        let aspect = TestAspect(name: "Test")
        registry.register(aspect)
        
        // When
        registry.clear()
        
        // Then
        XCTAssertEqual(registry.all().count, 0)
    }
    
    // MARK: - Response Modification Tests
    
    func testAspectCanModifyResponse() throws {
        // Given
        let headerName = "X-Test-Header"
        let headerValue = "test-value"
        
        let modifyAspect = TestAspect(
            name: "ModifyAspect",
            onAfter: { _, response, _ in
                response.headers.add(name: headerName, value: headerValue)
                return response
            }
        )
        
        let middleware = AspectMiddleware(aspects: [modifyAspect])
        app.middleware.use(middleware, at: .beginning)
        
        // When
        try app.test(.GET, "/test") { response in
            // Then
            XCTAssertEqual(response.headers[headerName].first, headerValue)
        }
    }
    
    // MARK: - Integration Tests
    
    func testApplicationAspectRegistry() throws {
        // Given
        let aspect = TestAspect(name: "AppAspect")
        let initialCount = app.aspectRegistry.all().count
        
        // When
        app.aspectRegistry.register(aspect, priority: 100)
        
        // Then
        XCTAssertEqual(app.aspectRegistry.all().count, initialCount + 1)
        
        // Test middleware creation
        let middleware = app.aspectRegistry.middleware()
        XCTAssertNotNil(middleware)
    }
    
    func testRequestAspectContext() throws {
        // Given
        app.get("context-test") { request in
            // When
            var context = request.aspectContext
            context.set("test-value", for: TestContextKey.self)
            request.aspectContext = context
            
            // Then
            let value = request.aspectContext.get(TestContextKey.self)
            return ["value": value ?? ""]
        }
        
        // When/Then
        try app.test(.GET, "/context-test") { response in
            let content = try response.content.decode([String: String].self)
            XCTAssertEqual(content["value"], "test-value")
        }
    }
}

// MARK: - Test Helpers

private struct MockResponder: AsyncResponder {
    private let closure: @Sendable (Request) async throws -> Response
    
    init(_ closure: @escaping @Sendable (Request) async throws -> Response) {
        self.closure = closure
    }
    
    func respond(to request: Request) async throws -> Response {
        try await closure(request)
    }
}

private struct TestAspect: Aspect {
    let name: String
    var onBefore: (@Sendable (Request, inout AspectContext) async throws -> Void)?
    var onAfter: (@Sendable (Request, Response, AspectContext) async throws -> Response?)?
    var onError: (@Sendable (Request, Error, AspectContext) async throws -> Void)?
    
    init(
        name: String,
        onBefore: (@Sendable (Request, inout AspectContext) async throws -> Void)? = nil,
        onAfter: (@Sendable (Request, Response, AspectContext) async throws -> Response?)? = nil,
        onError: (@Sendable (Request, Error, AspectContext) async throws -> Void)? = nil
    ) {
        self.name = name
        self.onBefore = onBefore
        self.onAfter = onAfter
        self.onError = onError
    }
    
    func before(request: Request, context: inout AspectContext) async throws {
        try await onBefore?(request, &context)
    }
    
    func after(request: Request, response: Response, context: AspectContext) async throws -> Response {
        if let modifiedResponse = try await onAfter?(request, response, context) {
            return modifiedResponse
        }
        return response
    }
    
    func onError(request: Request, error: Error, context: AspectContext) async throws {
        try await onError?(request, error, context)
        throw error
    }
}

private struct TestContextKey: AspectContextKey {
    typealias Value = String
}

private enum TestError: Error {
    case testCase
}