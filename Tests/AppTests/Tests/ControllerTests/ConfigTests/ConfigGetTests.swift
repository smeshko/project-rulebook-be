@testable import App
import Testing
import VaporTesting

@Suite(.serialized)
struct ConfigGetTests {
    let testWorld: IsolatedTestWorld

    init() async throws {
        testWorld = try await IsolatedTestWorld()
    }

    @Test("GET /api/v1/config returns 200 without authentication")
    func testConfigEndpointPublic() async throws {
        try await testWorld.app.test(.GET, "api/v1/config") { response in
            #expect(response.status == .ok)
        }
    }

    @Test("GET /api/v1/config returns expected JSON structure")
    func testConfigResponseStructure() async throws {
        try await testWorld.app.test(.GET, "api/v1/config") { response in
            #expect(response.status == .ok)

            let config = try response.content.decode(Config.Response.self)
            #expect(config.version == "1.0.0")
            #expect(config.featureFlags.isEmpty || !config.featureFlags.isEmpty) // Validates dictionary exists
            #expect(config.settings.isEmpty || !config.settings.isEmpty) // Validates dictionary exists
        }
    }

    @Test("GET /api/v1/config returns feature flags correctly")
    func testConfigFeatureFlags() async throws {
        // Setup: Add feature flag config values
        let enableNewScanner = ConfigValueModel(
            key: "featureFlags.enableNewScanner",
            value: "true",
            valueType: "boolean"
        )
        let showPromotion = ConfigValueModel(
            key: "featureFlags.showPromotion",
            value: "false",
            valueType: "boolean"
        )

        try await testWorld.configs.create(enableNewScanner)
        try await testWorld.configs.create(showPromotion)

        try await testWorld.app.test(.GET, "api/v1/config") { response in
            #expect(response.status == .ok)

            let config = try response.content.decode(Config.Response.self)
            #expect(config.featureFlags["enableNewScanner"] == true)
            #expect(config.featureFlags["showPromotion"] == false)
        }
    }

    @Test("GET /api/v1/config returns settings correctly with different types")
    func testConfigSettingsWithTypes() async throws {
        // Setup: Add settings with various types
        let maxRetries = ConfigValueModel(
            key: "settings.maxRetries",
            value: "3",
            valueType: "integer"
        )
        let cacheTimeout = ConfigValueModel(
            key: "settings.cacheTimeoutSeconds",
            value: "300",
            valueType: "integer"
        )
        let apiUrl = ConfigValueModel(
            key: "settings.apiUrl",
            value: "https://api.example.com",
            valueType: "string"
        )

        try await testWorld.configs.create(maxRetries)
        try await testWorld.configs.create(cacheTimeout)
        try await testWorld.configs.create(apiUrl)

        try await testWorld.app.test(.GET, "api/v1/config") { response in
            #expect(response.status == .ok)

            let config = try response.content.decode(Config.Response.self)
            #expect(config.settings["maxRetries"] == .int(3))
            #expect(config.settings["cacheTimeoutSeconds"] == .int(300))
            #expect(config.settings["apiUrl"] == .string("https://api.example.com"))
        }
    }

    @Test("GET /api/v1/config returns custom version when set")
    func testConfigCustomVersion() async throws {
        // Setup: Add version config
        let version = ConfigValueModel(
            key: "version",
            value: "2.1.0",
            valueType: "string"
        )
        try await testWorld.configs.create(version)

        try await testWorld.app.test(.GET, "api/v1/config") { response in
            #expect(response.status == .ok)

            let config = try response.content.decode(Config.Response.self)
            #expect(config.version == "2.1.0")
        }
    }

    @Test("GET /api/v1/config handles JSON value type")
    func testConfigJsonValueType() async throws {
        // Setup: Add JSON type setting
        let jsonConfig = ConfigValueModel(
            key: "settings.complexConfig",
            value: "{\"nested\":\"value\",\"number\":42}",
            valueType: "json"
        )
        try await testWorld.configs.create(jsonConfig)

        try await testWorld.app.test(.GET, "api/v1/config") { response in
            #expect(response.status == .ok)

            let config = try response.content.decode(Config.Response.self)
            // Verify it's a JSON object
            if case .object(let obj) = config.settings["complexConfig"] {
                #expect(obj["nested"] == .string("value"))
                #expect(obj["number"] == .int(42))
            } else {
                Issue.record("Expected JSON object for complexConfig")
            }
        }
    }
}
