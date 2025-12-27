@testable import App
import Fluent
import VaporTesting
import Testing

@Suite(.serialized)
struct RemoteConfigGetTests {
    let app: Application
    let testWorld: IsolatedTestWorld
    let path = "api/v1/config"

    init() async throws {
        testWorld = try await IsolatedTestWorld()
        app = testWorld.app
    }

    @Test("GET /api/v1/config returns configuration")
    func testGetConfig() async throws {
        await testWorld.resetAll()

        // Seed test data
        let config1 = RemoteConfigModel(
            key: "enableNewScanner",
            value: "true",
            valueType: .boolean
        )
        let config2 = RemoteConfigModel(
            key: "maxRetries",
            value: "3",
            valueType: .integer
        )

        try await config1.create(on: app.db)
        try await config2.create(on: app.db)

        try await app.test(.GET, path) { response in
            #expect(response.status == .ok)

            let getResponse = try response.content.decode(RemoteConfig.GetResponse.self)
            // Feature flags should contain "NewScanner" (prefix "enable" removed)
            #expect(getResponse.featureFlags.count == 1)
            // Settings should contain "maxRetries"
            #expect(getResponse.settings.count == 1)
            #expect(getResponse.version == "1.0.0")
        }
    }

    @Test("GET /api/v1/config returns empty object when no configs exist")
    func testGetConfigEmpty() async throws {
        await testWorld.resetAll()

        try await app.test(.GET, path) { response in
            #expect(response.status == .ok)

            let getResponse = try response.content.decode(RemoteConfig.GetResponse.self)
            #expect(getResponse.featureFlags.isEmpty)
            #expect(getResponse.settings.isEmpty)
            #expect(getResponse.version == "1.0.0")
        }
    }

    @Test("GET /api/v1/config caches response")
    func testCacheHit() async throws {
        await testWorld.resetAll()

        // Seed test data
        let config = RemoteConfigModel(
            key: "testConfig",
            value: "testValue",
            valueType: .string
        )
        try await config.create(on: app.db)

        // First request - cache miss
        try await app.test(.GET, path) { response in
            #expect(response.status == .ok)
        }

        // Second request - should hit cache
        try await app.test(.GET, path) { response in
            #expect(response.status == .ok)
            let getResponse = try response.content.decode(RemoteConfig.GetResponse.self)
            // testConfig should be in settings
            #expect(getResponse.settings.count == 1)
        }

        // Verify cache exists
        let cached = try await app.services.cache.get(
            "remote_config:latest",
            as: RemoteConfig.GetResponse.self
        )
        #expect(cached != nil)
    }

    @Test("GET /api/v1/config does not require authentication")
    func testPublicAccess() async throws {
        await testWorld.resetAll()

        // No authentication required - should succeed
        try await app.test(.GET, path) { response in
            #expect(response.status == .ok)
        }
    }

    @Test("GET /api/v1/config supports all value types")
    func testAllValueTypes() async throws {
        await testWorld.resetAll()

        // Create configs with different types
        let boolConfig = RemoteConfigModel(key: "boolValue", value: "true", valueType: .boolean)
        let intConfig = RemoteConfigModel(key: "intValue", value: "42", valueType: .integer)
        let stringConfig = RemoteConfigModel(key: "stringValue", value: "hello", valueType: .string)
        let jsonConfig = RemoteConfigModel(
            key: "jsonValue",
            value: "{\"nested\":\"data\"}",
            valueType: .json
        )

        try await boolConfig.create(on: app.db)
        try await intConfig.create(on: app.db)
        try await stringConfig.create(on: app.db)
        try await jsonConfig.create(on: app.db)

        try await app.test(.GET, path) { response in
            #expect(response.status == .ok)

            let configs = try response.content.decode([String: RemoteConfig.ConfigValue].self)
            #expect(configs.count == 4)
            #expect(configs["boolValue"]?.type == .boolean)
            #expect(configs["intValue"]?.type == .integer)
            #expect(configs["stringValue"]?.type == .string)
            #expect(configs["jsonValue"]?.type == .json)
        }
    }
}
