import XCTVapor
@testable import App

final class AspectMiddlewareTests: IntegrationTestCase {
    
    // MARK: - Aspect Execution Order Tests
    
    func testAspectsExecuteInCorrectOrder() async throws {
        // Given
        var executionOrder: [String] = []
        
        let aspect1 = TestAspect(
            name: "Aspect1",
            onBefore: { _, _ in executionOrder.append("Aspect1-before") },
            onAfter: { _, _, _ in executionOrder.append("Aspect1-after"); return nil },
            onError: { _, _, _ in executionOrder.append("Aspect1-error") }
        )
        
        let aspect2 = TestAspect(
            name: "Aspect2",
            onBefore: { _, _ in executionOrder.append("Aspect2-before") },
            onAfter: { _, _, _ in executionOrder.append("Aspect2-after"); return nil },
            onError: { _, _, _ in executionOrder.append("Aspect2-error") }
        )
        
        let middleware = AspectMiddleware(aspects: [aspect1, aspect2])
        app.middleware.use(middleware, at: .beginning)
        
        // When
        try await app.test(.GET, "/test") { response in
            // Then
            XCTAssertEqual(executionOrder, [
                "Aspect1-before",
                "Aspect2-before",
                "Aspect2-after",
                "Aspect1-after"
            ])
        }
    }
    
    func testAspectContextPropagation() async throws {
        // Given
        let testKey = TestContextKey()
        let testValue = "test-value"
        
        let setAspect = TestAspect(
            name: "SetAspect",
            onBefore: { _, context in
                context.set(testValue, for: TestContextKey.self)
            }
        )
        
        var retrievedValue: String?
        let getAspect = TestAspect(
            name: "GetAspect",
            onAfter: { _, _, context in
                retrievedValue = context.get(TestContextKey.self)
                return nil
            }
        )
        
        let middleware = AspectMiddleware(aspects: [setAspect, getAspect])
        app.middleware.use(middleware, at: .beginning)
        
        // When
        try await app.test(.GET, "/test") { response in
            // Then
            XCTAssertEqual(retrievedValue, testValue)
        }
    }
    
    func testAspectErrorHandling() async throws {
        // Given
        let testError = TestError.testCase
        var errorHandled = false
        
        let errorAspect = TestAspect(
            name: "ErrorAspect",
            onBefore: { _, _ in
                throw testError
            },
            onError: { _, error, _ in
                errorHandled = true
                XCTAssertEqual(error as? TestError, testError)
            }
        )
        
        let middleware = AspectMiddleware(aspects: [errorAspect])
        app.middleware.use(middleware, at: .beginning)
        
        // When
        try await app.test(.GET, "/test") { response in
            // Then
            XCTAssertTrue(errorHandled)
            XCTAssertEqual(response.status, .internalServerError)
        }
    }
    
    // MARK: - AspectRegistry Tests
    
    func testAspectRegistryPriorityOrdering() {
        // Given
        let registry = AspectRegistry()
        
        var executionOrder: [String] = []
        let lowPriority = TestAspect(
            name: "Low",
            onBefore: { _, _ in executionOrder.append("Low") }
        )
        let highPriority = TestAspect(
            name: "High",
            onBefore: { _, _ in executionOrder.append("High") }
        )
        let mediumPriority = TestAspect(
            name: "Medium",
            onBefore: { _, _ in executionOrder.append("Medium") }
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
    
    func testAspectCanModifyResponse() async throws {
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
        try await app.test(.GET, "/test") { response in
            // Then
            XCTAssertEqual(response.headers[headerName].first, headerValue)
        }
    }
    
    // MARK: - Integration Tests
    
    func testApplicationAspectRegistry() async throws {
        // Given
        let aspect = TestAspect(name: "AppAspect")
        
        // When
        app.aspectRegistry.register(aspect, priority: 100)
        
        // Then
        XCTAssertEqual(app.aspectRegistry.all().count, 1)
        
        // Test middleware creation
        let middleware = app.aspectRegistry.middleware()
        XCTAssertNotNil(middleware)
    }
    
    func testRequestAspectContext() async throws {
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
        try await app.test(.GET, "/context-test") { response in
            let content = try response.content.decode([String: String].self)
            XCTAssertEqual(content["value"], "test-value")
        }
    }
}

// MARK: - Test Helpers

private struct TestAspect: Aspect {
    let name: String
    var onBefore: ((Request, inout AspectContext) async throws -> Void)?
    var onAfter: ((Request, Response, AspectContext) async throws -> Response?)?
    var onError: ((Request, Error, AspectContext) async throws -> Void)?
    
    init(
        name: String,
        onBefore: ((Request, inout AspectContext) async throws -> Void)? = nil,
        onAfter: ((Request, Response, AspectContext) async throws -> Response?)? = nil,
        onError: ((Request, Error, AspectContext) async throws -> Void)? = nil
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