@testable import App
import VaporTesting
import Testing
import Fluent

@Suite(.serialized)
struct RemoteConfigGetTests {
    let app: Application
    let testWorld: IsolatedTestWorld

    init() async throws {
        testWorld = try await IsolatedTestWorld()
        app = testWorld.app
    }

    @Test("GET /api/v1/config returns correct structure")
    func getConfigReturnsCorrectStructure() async throws {
        await testWorld.resetAll()

        // Setup test data
        let repo = DatabaseRemoteConfigRepository(database: app.db)
        try await repo.setConfig(key: "feature_newScanner", value: true, type: ConfigValueType.boolean)
        try await repo.setConfig(key: "feature_showPromotion", value: false, type: ConfigValueType.boolean)
        try await repo.setConfig(key: "setting_maxRetries", value: 3, type: ConfigValueType.integer)
        try await repo.setConfig(key: "setting_cacheTimeoutSeconds", value: 300, type: ConfigValueType.integer)
        try await repo.setConfig(key: "api_version", value: "1.0.0", type: ConfigValueType.string)

        try await app.test(.GET, "api/v1/config") { response in
            #expect(response.status == .ok)

            let config = try response.content.decode(RemoteConfig.Response.self)

            // Verify feature flags
            #expect(config.featureFlags["newScanner"] == true)
            #expect(config.featureFlags["showPromotion"] == false)

            // Verify settings
            #expect(config.settings["maxRetries"]?.value as? Int == 3)
            #expect(config.settings["cacheTimeoutSeconds"]?.value as? Int == 300)

            // Verify version
            #expect(config.version == "1.0.0")
        }
    }

    @Test("GET /api/v1/config returns empty config when no data exists")
    func getConfigReturnsEmptyWhenNoData() async throws {
        await testWorld.resetAll()

        try await app.test(.GET, "api/v1/config") { response in
            #expect(response.status == .ok)

            let config = try response.content.decode(RemoteConfig.Response.self)

            #expect(config.featureFlags.isEmpty)
            #expect(config.settings.isEmpty)
            #expect(config.version == "1.0.0")
        }
    }

    @Test("GET /api/v1/config is accessible without authentication")
    func getConfigIsPublic() async throws {
        await testWorld.resetAll()

        // No authentication headers
        try await app.test(.GET, "api/v1/config") { response in
            #expect(response.status == .ok)
        }
    }

    @Test("GET /api/v1/config caches response")
    func getConfigCachesResponse() async throws {
        await testWorld.resetAll()

        let repo = DatabaseRemoteConfigRepository(database: app.db)
        try await repo.setConfig(key: "feature_test", value: true, type: ConfigValueType.boolean)

        // Reset call counters before testing
        testWorld.mockConfigCacheService.reset()

        // First request should miss cache, fetch from DB, then cache the result
        try await app.test(.GET, "api/v1/config") { response in
            #expect(response.status == .ok)
        }

        // Verify cache was accessed and set
        #expect(testWorld.mockConfigCacheService.getAllCallCount == 1, "Should check cache on first request")
        #expect(testWorld.mockConfigCacheService.setCallCount == 1, "Should cache result after first request")

        // Second request should hit cache
        try await app.test(.GET, "api/v1/config") { response in
            #expect(response.status == .ok)
        }

        // Verify cache was hit (getAll called again, but no additional set)
        #expect(testWorld.mockConfigCacheService.getAllCallCount == 2, "Should check cache on second request")
        #expect(testWorld.mockConfigCacheService.setCallCount == 1, "Should NOT cache again on cache hit")
    }

    @Test("Old unversioned route returns 404")
    func oldRouteReturns404() async throws {
        await testWorld.resetAll()

        try await app.test(.GET, "api/config") { response in
            #expect(response.status == .notFound)
        }
    }
}
