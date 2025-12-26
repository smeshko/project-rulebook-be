@testable import App
import VaporTesting
import Testing

@Suite(.serialized)
struct RulesGenerationRouteVersioningTests {
    let app: Application
    let testWorld: IsolatedTestWorld

    init() async throws {
        testWorld = try await IsolatedTestWorld()
        app = testWorld.app
    }

    // VERSIONED ROUTE TESTS - These should pass after implementation

    @Test("Versioned rules-summary endpoint exists and accepts POST")
    func versionedRulesSummaryExists() async throws {
        await testWorld.resetAll()

        let request = RulesSummary.Request(gameTitle: "Wingspan")

        try await app.test(.POST, "api/v1/rules-generation/rules-summary", content: request, afterResponse: { response in
            // Should not be 404 (route exists)
            // May fail with 429 (rate limit) or 500 (LLM error) but route should exist
            #expect(response.status != .notFound)
        })
    }

    // NEGATIVE TESTS - Old unversioned routes should return 404

    @Test("Old unversioned rules-summary route returns 404")
    func oldRulesSummaryReturns404() async throws {
        await testWorld.resetAll()

        let request = RulesSummary.Request(gameTitle: "Wingspan")

        try await app.test(.POST, "api/rules-generation/rules-summary", content: request, afterResponse: { response in
            #expect(response.status == .notFound)
        })
    }
}
