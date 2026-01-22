@testable import App
import Fluent
import VaporTesting
import Testing

@Suite(.serialized)
struct RemoteConfigPublicTests {
    let app: Application
    let testWorld: IsolatedTestWorld
    let publicConfigPath = "api/v1/config"

    init() async throws {
        testWorld = try await IsolatedTestWorld()
        app = testWorld.app
    }

    @Test("Public config endpoint returns empty config when no entries exist", .tags(.p1Core, .integration))
    func getPublicConfigEmpty() async throws {
        await testWorld.resetAll()

        try await app.test(.GET, publicConfigPath, afterResponse: { res async throws in
            #expect(res.status == .ok)
            expectContent(RemoteConfig.Public.Response.self, res) { response in
                #expect(response.featureFlags.isEmpty)
                #expect(response.settings.isEmpty)
                #expect(response.version != nil)
            }
        })
    }

    @Test("Public config endpoint returns feature flags and settings", .tags(.p0Critical, .integration))
    func getPublicConfigWithEntries() async throws {
        await testWorld.resetAll()

        // Create test config entries
        let boolEntry = RemoteConfigEntryModel(
            key: "enable_new_feature",
            value: "true",
            valueType: "boolean",
            description: "Enables the new feature"
        )
        let intEntry = RemoteConfigEntryModel(
            key: "max_items",
            value: "100",
            valueType: "integer",
            description: "Maximum items allowed"
        )
        let stringEntry = RemoteConfigEntryModel(
            key: "welcome_message",
            value: "Hello World",
            valueType: "string",
            description: "Welcome message"
        )

        try await testWorld.remoteConfig.create(boolEntry)
        try await testWorld.remoteConfig.create(intEntry)
        try await testWorld.remoteConfig.create(stringEntry)

        try await app.test(.GET, publicConfigPath, afterResponse: { res async throws in
            #expect(res.status == .ok)
            expectContent(RemoteConfig.Public.Response.self, res) { response in
                // Boolean entries should be in featureFlags
                #expect(response.featureFlags["enable_new_feature"] == true)

                // Non-boolean entries should be in settings
                #expect(response.settings["max_items"] != nil)
                #expect(response.settings["welcome_message"] != nil)

                // Feature flags should not contain non-booleans
                #expect(response.featureFlags["max_items"] == nil)
                #expect(response.featureFlags["welcome_message"] == nil)
            }
        })
    }

    @Test("Public config endpoint separates booleans into featureFlags", .tags(.p1Core, .integration))
    func getPublicConfigFeatureFlagsSeparation() async throws {
        await testWorld.resetAll()

        // Create multiple boolean entries
        let entry1 = RemoteConfigEntryModel(key: "feature_a", value: "true", valueType: "boolean")
        let entry2 = RemoteConfigEntryModel(key: "feature_b", value: "false", valueType: "boolean")
        let entry3 = RemoteConfigEntryModel(key: "feature_c", value: "1", valueType: "boolean")
        let entry4 = RemoteConfigEntryModel(key: "feature_d", value: "0", valueType: "boolean")

        try await testWorld.remoteConfig.create(entry1)
        try await testWorld.remoteConfig.create(entry2)
        try await testWorld.remoteConfig.create(entry3)
        try await testWorld.remoteConfig.create(entry4)

        try await app.test(.GET, publicConfigPath, afterResponse: { res async throws in
            #expect(res.status == .ok)
            expectContent(RemoteConfig.Public.Response.self, res) { response in
                #expect(response.featureFlags["feature_a"] == true)
                #expect(response.featureFlags["feature_b"] == false)
                #expect(response.featureFlags["feature_c"] == true)  // "1" = true
                #expect(response.featureFlags["feature_d"] == false) // "0" = false
                #expect(response.settings.isEmpty)
            }
        })
    }

    @Test("Public config endpoint does not require authentication", .tags(.p0Critical, .integration))
    func getPublicConfigNoAuthRequired() async throws {
        await testWorld.resetAll()

        // Request without any authorization header should succeed
        try await app.test(.GET, publicConfigPath, afterResponse: { res async throws in
            #expect(res.status == .ok)
        })
    }

    @Test("Public config endpoint handles JSON value type", .tags(.p2Extended, .integration))
    func getPublicConfigJsonValues() async throws {
        await testWorld.resetAll()

        let jsonEntry = RemoteConfigEntryModel(
            key: "app_config",
            value: "{\"theme\":\"dark\",\"version\":2}",
            valueType: "json"
        )
        try await testWorld.remoteConfig.create(jsonEntry)

        try await app.test(.GET, publicConfigPath, afterResponse: { res async throws in
            #expect(res.status == .ok)
            expectContent(RemoteConfig.Public.Response.self, res) { response in
                #expect(response.settings["app_config"] != nil)
            }
        })
    }
}
