@testable import App
import Fluent
import VaporTesting
import Testing

@Suite(.serialized)
struct HealthCheckTests {
    let app: Application
    let testWorld: IsolatedTestWorld
    let healthPath = "health"

    init() async throws {
        testWorld = try await IsolatedTestWorld()
        app = testWorld.app
    }

    // MARK: - Happy Path

    @Test("Health check returns 200 with healthy status when all services are up", .tags(.p0Critical, .health, .integration))
    func healthyResponse() async throws {
        try await app.test(.GET, healthPath, afterResponse: { res async throws in
            #expect(res.status == .ok)
            expectContent(Health.Check.Response.self, res) { content in
                #expect(content.status == "healthy")
                #expect(content.checks.database == "ok")
                #expect(content.checks.redis == "ok")
            }
        })
    }

    @Test("Health check response contains valid ISO8601 timestamp", .tags(.p0Critical, .health, .integration))
    func validTimestamp() async throws {
        try await app.test(.GET, healthPath, afterResponse: { res async throws in
            #expect(res.status == .ok)
            expectContent(Health.Check.Response.self, res) { content in
                let formatter = ISO8601DateFormatter()
                let date = formatter.date(from: content.timestamp)
                #expect(date != nil, "Timestamp should be valid ISO8601")
            }
        })
    }

    @Test("Health check response has correct JSON structure", .tags(.p0Critical, .health, .integration))
    func responseStructure() async throws {
        try await app.test(.GET, healthPath, afterResponse: { res async throws in
            #expect(res.status == .ok)

            // Verify Content-Type
            let contentType = res.headers.first(name: .contentType)
            #expect(contentType?.contains("application/json") == true)

            // Verify full structure
            expectContent(Health.Check.Response.self, res) { content in
                #expect(content.status == "healthy")
                #expect(!content.timestamp.isEmpty)
                #expect(content.checks.database == "ok")
                #expect(content.checks.redis == "ok")
            }
        })
    }

    @Test("Health check does not require authentication", .tags(.p0Critical, .health, .integration))
    func noAuthRequired() async throws {
        // Make request without any auth token — should still succeed
        try await app.test(.GET, healthPath, afterResponse: { res async throws in
            #expect(res.status == .ok)
            expectContent(Health.Check.Response.self, res) { content in
                #expect(content.status == "healthy")
            }
        })
    }
}
