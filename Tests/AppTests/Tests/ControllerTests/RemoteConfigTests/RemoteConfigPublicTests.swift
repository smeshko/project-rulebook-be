@testable import App
import Fluent
import VaporTesting
import Testing

@Suite(.serialized)
struct RemoteConfigPublicTests {
    let app: Application
    let testWorld: IsolatedTestWorld
    let configPath = "api/v1/config"

    init() async throws {
        testWorld = try await IsolatedTestWorld()
        app = testWorld.app
    }

    @Test("Public config endpoint returns correct structure", .tags(.p1Core, .config, .integration))
    func getConfigReturnsCorrectStructure() async throws {
        await testWorld.resetAll()

        // Create some config entries
        let boolEntry = RemoteConfigEntryModel(
            key: "feature_dark_mode",
            value: "true",
            valueType: .boolean,
            description: "Enable dark mode"
        )
        let intEntry = RemoteConfigEntryModel(
            key: "max_retries",
            value: "3",
            valueType: .integer,
            description: "Maximum retry attempts"
        )
        let stringEntry = RemoteConfigEntryModel(
            key: "welcome_message",
            value: "Hello, World!",
            valueType: .string,
            description: "Welcome message"
        )

        await testWorld.remoteConfig.add(boolEntry)
        await testWorld.remoteConfig.add(intEntry)
        await testWorld.remoteConfig.add(stringEntry)

        try await app.test(.GET, configPath) { response in
            #expect(response.status == .ok)
            expectContent(RemoteConfig.Response.self, response) { config in
                #expect(config.featureFlags["feature_dark_mode"] == true)
                #expect(config.settings["max_retries"] != nil)
                #expect(config.settings["welcome_message"] != nil)
                #expect(!config.version.isEmpty)
            }
        }
    }

    @Test("Public config endpoint returns empty config when no entries exist", .tags(.p1Core, .config, .integration))
    func getConfigReturnsEmptyWhenNoEntries() async throws {
        await testWorld.resetAll()

        try await app.test(.GET, configPath) { response in
            #expect(response.status == .ok)
            expectContent(RemoteConfig.Response.self, response) { config in
                #expect(config.featureFlags.isEmpty)
                #expect(config.settings.isEmpty)
            }
        }
    }

    @Test("Public config endpoint separates booleans into featureFlags", .tags(.p1Core, .config, .integration))
    func getConfigSeparatesBooleanIntoFeatureFlags() async throws {
        await testWorld.resetAll()

        let boolTrue = RemoteConfigEntryModel(
            key: "feature_enabled",
            value: "true",
            valueType: .boolean
        )
        let boolFalse = RemoteConfigEntryModel(
            key: "feature_disabled",
            value: "false",
            valueType: .boolean
        )
        let nonBool = RemoteConfigEntryModel(
            key: "api_url",
            value: "https://api.example.com",
            valueType: .string
        )

        await testWorld.remoteConfig.add(boolTrue)
        await testWorld.remoteConfig.add(boolFalse)
        await testWorld.remoteConfig.add(nonBool)

        try await app.test(.GET, configPath) { response in
            #expect(response.status == .ok)
            expectContent(RemoteConfig.Response.self, response) { config in
                // Booleans should be in featureFlags
                #expect(config.featureFlags["feature_enabled"] == true)
                #expect(config.featureFlags["feature_disabled"] == false)
                // Non-booleans should not be in featureFlags
                #expect(config.featureFlags["api_url"] == nil)
                // Non-booleans should be in settings
                #expect(config.settings["api_url"] != nil)
            }
        }
    }

    @Test("Public config endpoint handles JSON values", .tags(.p2Extended, .config, .integration))
    func getConfigHandlesJSONValues() async throws {
        await testWorld.resetAll()

        let jsonEntry = RemoteConfigEntryModel(
            key: "app_settings",
            value: "{\"theme\":\"dark\",\"version\":2}",
            valueType: .json
        )

        await testWorld.remoteConfig.add(jsonEntry)

        try await app.test(.GET, configPath) { response in
            #expect(response.status == .ok)
            expectContent(RemoteConfig.Response.self, response) { config in
                #expect(config.settings["app_settings"] != nil)
            }
        }
    }

    @Test("Public config endpoint is accessible without authentication", .tags(.p0Critical, .config, .security, .integration))
    func getConfigDoesNotRequireAuth() async throws {
        await testWorld.resetAll()

        // Should succeed without any auth header
        try await app.test(.GET, configPath) { response in
            #expect(response.status == .ok)
        }
    }
}
