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

    @Test("Public config endpoint returns empty response when no config exists", .tags(.p1Core, .integration))
    func getConfigReturnsEmptyWhenNoConfig() async throws {
        await testWorld.resetAll()

        try await app.test(.GET, configPath, afterResponse: { res in
            #expect(res.status == .ok)
            expectContent(RemoteConfig.Response.self, res) { config in
                #expect(config.featureFlags.isEmpty)
                #expect(config.settings.isEmpty)
                #expect(config.version == "1.0.0")
            }
        })
    }

    @Test("Public config endpoint returns feature flags correctly", .tags(.p1Core, .integration))
    func getConfigReturnsFeatureFlags() async throws {
        await testWorld.resetAll()

        // Create boolean config entries (feature flags)
        let enableScanner = RemoteConfigEntryModel(
            key: "enableNewScanner",
            value: "true",
            valueType: .boolean
        )
        let showPromotion = RemoteConfigEntryModel(
            key: "showPromotion",
            value: "false",
            valueType: .boolean
        )

        try await app.repositories.remoteConfig.create(enableScanner)
        try await app.repositories.remoteConfig.create(showPromotion)

        try await app.test(.GET, configPath, afterResponse: { res in
            #expect(res.status == .ok)
            expectContent(RemoteConfig.Response.self, res) { config in
                #expect(config.featureFlags["enableNewScanner"] == true)
                #expect(config.featureFlags["showPromotion"] == false)
            }
        })
    }

    @Test("Public config endpoint returns settings correctly", .tags(.p1Core, .integration))
    func getConfigReturnsSettings() async throws {
        await testWorld.resetAll()

        // Create various typed settings
        let maxRetries = RemoteConfigEntryModel(
            key: "maxRetries",
            value: "3",
            valueType: .integer
        )
        let cacheTimeout = RemoteConfigEntryModel(
            key: "cacheTimeoutSeconds",
            value: "300",
            valueType: .integer
        )
        let apiEndpoint = RemoteConfigEntryModel(
            key: "apiEndpoint",
            value: "https://api.example.com",
            valueType: .string
        )

        try await app.repositories.remoteConfig.create(maxRetries)
        try await app.repositories.remoteConfig.create(cacheTimeout)
        try await app.repositories.remoteConfig.create(apiEndpoint)

        try await app.test(.GET, configPath, afterResponse: { res in
            #expect(res.status == .ok)
            expectContent(RemoteConfig.Response.self, res) { config in
                #expect(config.settings["maxRetries"]?.value as? Int == 3)
                #expect(config.settings["cacheTimeoutSeconds"]?.value as? Int == 300)
                #expect(config.settings["apiEndpoint"]?.value as? String == "https://api.example.com")
            }
        })
    }

    @Test("Public config endpoint returns version from config", .tags(.p2Extended, .integration))
    func getConfigReturnsVersion() async throws {
        await testWorld.resetAll()

        let versionEntry = RemoteConfigEntryModel(
            key: "version",
            value: "2.5.0",
            valueType: .string
        )
        try await app.repositories.remoteConfig.create(versionEntry)

        try await app.test(.GET, configPath, afterResponse: { res in
            #expect(res.status == .ok)
            expectContent(RemoteConfig.Response.self, res) { config in
                #expect(config.version == "2.5.0")
            }
        })
    }

    @Test("Public config endpoint handles JSON settings", .tags(.p2Extended, .integration))
    func getConfigHandlesJsonSettings() async throws {
        await testWorld.resetAll()

        let jsonEntry = RemoteConfigEntryModel(
            key: "serverConfig",
            value: #"{"host": "localhost", "port": 8080}"#,
            valueType: .json
        )
        try await app.repositories.remoteConfig.create(jsonEntry)

        try await app.test(.GET, configPath, afterResponse: { res in
            #expect(res.status == .ok)
            expectContent(RemoteConfig.Response.self, res) { config in
                guard let serverConfig = config.settings["serverConfig"]?.value as? [String: Any] else {
                    Issue.record("Expected serverConfig to be a dictionary")
                    return
                }
                #expect(serverConfig["host"] as? String == "localhost")
                #expect(serverConfig["port"] as? Int == 8080)
            }
        })
    }

    @Test("Public config endpoint does not require authentication", .tags(.p1Core, .integration))
    func getConfigDoesNotRequireAuth() async throws {
        await testWorld.resetAll()

        // No Authorization header provided
        try await app.test(.GET, configPath, afterResponse: { res in
            #expect(res.status == .ok)
        })
    }
}
