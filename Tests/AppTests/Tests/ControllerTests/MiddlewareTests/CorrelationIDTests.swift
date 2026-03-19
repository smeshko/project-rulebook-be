@testable import App
import VaporTesting
import Testing

@Suite(.serialized)
struct CorrelationIDTests {
    let app: Application
    let testWorld: IsolatedTestWorld

    init() async throws {
        testWorld = try await IsolatedTestWorld()
        app = testWorld.app
    }

    // MARK: - Correlation ID Generation

    @Test("Response includes X-Correlation-ID header when none provided", .tags(.p0Critical, .integration))
    func generatesCorrelationID() async throws {
        try await app.test(.GET, "health", afterResponse: { res async throws in
            #expect(res.status == .ok)
            let correlationID = res.headers.first(name: "X-Correlation-ID")
            #expect(correlationID != nil, "Response must include X-Correlation-ID header")
            #expect(!correlationID!.isEmpty, "Correlation ID must not be empty")
        })
    }

    // MARK: - Correlation ID Propagation

    @Test("Incoming X-Correlation-ID header is preserved in response", .tags(.p0Critical, .integration))
    func preservesIncomingCorrelationID() async throws {
        let testCorrelationID = "test-correlation-id-12345"
        try await app.test(
            .GET, "health",
            headers: ["X-Correlation-ID": testCorrelationID],
            afterResponse: { res async throws in
                #expect(res.status == .ok)
                let responseCorrelationID = res.headers.first(name: "X-Correlation-ID")
                #expect(responseCorrelationID == testCorrelationID,
                    "Response correlation ID should match the incoming header")
            }
        )
    }

    @Test("X-Request-ID header is accepted as correlation ID", .tags(.p1Core, .integration))
    func acceptsRequestIDHeader() async throws {
        let testID = "request-id-67890"
        try await app.test(
            .GET, "health",
            headers: ["X-Request-ID": testID],
            afterResponse: { res async throws in
                let responseCorrelationID = res.headers.first(name: "X-Correlation-ID")
                #expect(responseCorrelationID == testID,
                    "X-Request-ID should be used as correlation ID")
            }
        )
    }

    @Test("X-Trace-ID header is accepted as correlation ID", .tags(.p1Core, .integration))
    func acceptsTraceIDHeader() async throws {
        let testID = "trace-id-abcde"
        try await app.test(
            .GET, "health",
            headers: ["X-Trace-ID": testID],
            afterResponse: { res async throws in
                let responseCorrelationID = res.headers.first(name: "X-Correlation-ID")
                #expect(responseCorrelationID == testID,
                    "X-Trace-ID should be used as correlation ID")
            }
        )
    }

    @Test("X-Correlation-ID takes priority over X-Request-ID", .tags(.p1Core, .integration))
    func correlationIDHeaderPriority() async throws {
        let primaryID = "primary-correlation-id"
        let secondaryID = "secondary-request-id"
        try await app.test(
            .GET, "health",
            headers: [
                "X-Correlation-ID": primaryID,
                "X-Request-ID": secondaryID,
            ],
            afterResponse: { res async throws in
                let responseCorrelationID = res.headers.first(name: "X-Correlation-ID")
                #expect(responseCorrelationID == primaryID,
                    "X-Correlation-ID should take priority over X-Request-ID")
            }
        )
    }

    @Test("Correlation ID is included in error responses", .tags(.p1Core, .integration))
    func correlationIDInErrorResponse() async throws {
        let testCorrelationID = "error-test-correlation-id"
        try await app.test(
            .GET, "nonexistent-route-for-correlation-test",
            headers: ["X-Correlation-ID": testCorrelationID],
            afterResponse: { res async throws in
                let responseCorrelationID = res.headers.first(name: "X-Correlation-ID")
                #expect(responseCorrelationID == testCorrelationID,
                    "Error responses should include the correlation ID")
            }
        )
    }
}
