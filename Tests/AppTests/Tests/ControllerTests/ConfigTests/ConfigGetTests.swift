@testable import App
import VaporTesting
import Testing

@Suite(.serialized)
struct ConfigGetTests {
    let app: Application
    let testWorld: IsolatedTestWorld
    let configPath = "api/v1/config"

    init() async throws {
        testWorld = try await IsolatedTestWorld()
        app = testWorld.app
    }

    @Test("GET /api/v1/config returns empty config when no entries exist")
    func getConfigReturnsEmptyWhenNoEntries() async throws {
        await testWorld.resetAll()

        try await app.test(.GET, configPath, afterResponse: { res in
            #expect(res.status == .ok)
            expectContent(Config.Response.self, res) { config in
                #expect(config.featureFlags.isEmpty)
                #expect(config.settings.isEmpty)
                #expect(config.version == "1.0.0")
            }
        })
    }

    @Test("GET /api/v1/config returns feature flags correctly")
    func getConfigReturnsFeatureFlags() async throws {
        await testWorld.resetAll()

        // Create feature flag entries
        let premiumFlag = ConfigEntryModel(
            key: "featureFlags.premiumEnabled",
            value: ConfigValue(bool: true),
            valueType: "boolean"
        )
        let betaFlag = ConfigEntryModel(
            key: "featureFlags.betaFeatures",
            value: ConfigValue(bool: false),
            valueType: "boolean"
        )

        try await testWorld.configs.create(premiumFlag)
        try await testWorld.configs.create(betaFlag)

        try await app.test(.GET, configPath, afterResponse: { res in
            #expect(res.status == .ok)
            expectContent(Config.Response.self, res) { config in
                #expect(config.featureFlags["premiumEnabled"] == true)
                #expect(config.featureFlags["betaFeatures"] == false)
            }
        })
    }

    @Test("GET /api/v1/config returns settings correctly")
    func getConfigReturnsSettings() async throws {
        await testWorld.resetAll()

        // Create settings entries
        let maxRetries = ConfigEntryModel(
            key: "settings.maxRetries",
            value: ConfigValue(int: 5),
            valueType: "integer"
        )
        let apiUrl = ConfigEntryModel(
            key: "settings.apiUrl",
            value: ConfigValue(string: "https://api.example.com"),
            valueType: "string"
        )

        try await testWorld.configs.create(maxRetries)
        try await testWorld.configs.create(apiUrl)

        try await app.test(.GET, configPath, afterResponse: { res in
            #expect(res.status == .ok)
            expectContent(Config.Response.self, res) { config in
                #expect(config.settings["maxRetries"] == .int(5))
                #expect(config.settings["apiUrl"] == .string("https://api.example.com"))
            }
        })
    }

    @Test("GET /api/v1/config returns custom version")
    func getConfigReturnsCustomVersion() async throws {
        await testWorld.resetAll()

        let versionEntry = ConfigEntryModel(
            key: "version",
            value: ConfigValue(string: "2.5.0"),
            valueType: "string"
        )

        try await testWorld.configs.create(versionEntry)

        try await app.test(.GET, configPath, afterResponse: { res in
            #expect(res.status == .ok)
            expectContent(Config.Response.self, res) { config in
                #expect(config.version == "2.5.0")
            }
        })
    }

    @Test("GET /api/v1/config is accessible without authentication")
    func getConfigIsPublic() async throws {
        await testWorld.resetAll()

        // No auth headers provided - should still work
        try await app.test(.GET, configPath, afterResponse: { res in
            #expect(res.status == .ok)
        })
    }
}
