@testable import App
import VaporTesting
import Testing

@Suite(.serialized)
struct ConfigPublicEndpointTests {
    let app: Application
    let testWorld: IsolatedTestWorld

    init() async throws {
        testWorld = try await IsolatedTestWorld()
        app = testWorld.app
    }

    @Test("Public config endpoint returns valid JSON")
    func publicConfigReturnsValidJSON() async throws {
        await testWorld.resetAll()

        // Seed config data
        try await testWorld.configs.seed()

        try await app.test(.GET, "api/v1/config", afterResponse: { response in
            #expect(response.status == .ok)
            let config = try response.content.decode(Config.Response.self)
            #expect(config.version == "1.0.0")
            #expect(config.featureFlags["enableNewScanner"] == true)
            #expect(config.featureFlags["showPromotion"] == false)
        })
    }

    @Test("Public config endpoint requires no authentication")
    func publicConfigNoAuth() async throws {
        await testWorld.resetAll()

        // Seed config data
        try await testWorld.configs.seed()

        // Request without any authorization header should still succeed
        try await app.test(.GET, "api/v1/config", afterResponse: { response in
            #expect(response.status == .ok)
            #expect(response.status != .unauthorized)
        })
    }

    @Test("Old unversioned config route returns 404")
    func oldConfigRouteReturns404() async throws {
        await testWorld.resetAll()

        try await app.test(.GET, "api/config", afterResponse: { response in
            #expect(response.status == .notFound)
        })
    }

    @Test("Public config endpoint returns feature flags and settings")
    func publicConfigReturnsFeatureFlagsAndSettings() async throws {
        await testWorld.resetAll()

        // Seed config data
        try await testWorld.configs.seed()

        try await app.test(.GET, "api/v1/config", afterResponse: { response in
            #expect(response.status == .ok)
            let config = try response.content.decode(Config.Response.self)

            // Verify feature flags
            #expect(config.featureFlags.count >= 2)
            #expect(config.featureFlags.keys.contains("enableNewScanner"))
            #expect(config.featureFlags.keys.contains("showPromotion"))

            // Verify settings exist
            #expect(config.settings.count >= 2)
        })
    }

    @Test("Versioned config endpoint exists and accepts GET")
    func versionedConfigEndpointExists() async throws {
        await testWorld.resetAll()

        try await app.test(.GET, "api/v1/config", afterResponse: { response in
            // Should not be 404 (route exists)
            #expect(response.status != .notFound)
        })
    }
}
