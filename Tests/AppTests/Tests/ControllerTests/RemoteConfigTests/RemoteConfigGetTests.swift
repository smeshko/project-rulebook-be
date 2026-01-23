@testable import App
import Fluent
import VaporTesting
import Testing

@Suite(.serialized)
struct RemoteConfigGetTests {
    let app: Application
    let testWorld: IsolatedTestWorld
    let configPath = "api/v1/config"

    init() async throws {
        testWorld = try await IsolatedTestWorld()
        app = testWorld.app
    }

    @Test("Get config returns empty response when no configs exist", .tags(.p1Core, .remoteConfig, .integration))
    func getConfigEmptyResponse() async throws {
        await testWorld.resetAll()

        try await app.test(.GET, configPath) { response in
            #expect(response.status == .ok)
            expectContent(RemoteConfig.Get.Response.self, response) { config in
                #expect(config.featureFlags.isEmpty)
                #expect(config.settings.isEmpty)
            }
        }
    }

    @Test("Get config returns feature flags and settings", .tags(.p0Critical, .remoteConfig, .integration))
    func getConfigHappyPath() async throws {
        await testWorld.resetAll()

        // Create test configs
        let featureFlagConfig = RemoteConfigModel(
            key: "enablePaywall",
            value: "true",
            valueType: .boolean,
            category: .featureFlag
        )
        let settingConfig = RemoteConfigModel(
            key: "maxRetries",
            value: "3",
            valueType: .integer,
            category: .setting
        )

        try await testWorld.remoteConfigs.create(featureFlagConfig)
        try await testWorld.remoteConfigs.create(settingConfig)

        try await app.test(.GET, configPath) { response in
            #expect(response.status == .ok)
            expectContent(RemoteConfig.Get.Response.self, response) { config in
                #expect(config.featureFlags.count == 1)
                #expect(config.settings.count == 1)
                #expect(config.featureFlags["enablePaywall"] == .bool(true))
                #expect(config.settings["maxRetries"] == .int(3))
            }
        }
    }

    @Test("Get config does not require authentication", .tags(.p0Critical, .remoteConfig, .security, .integration))
    func getConfigNoAuthRequired() async throws {
        await testWorld.resetAll()

        // Request without any authentication headers should succeed
        try await app.test(.GET, configPath) { response in
            #expect(response.status == .ok)
        }
    }

    @Test("Get config returns string values correctly", .tags(.p1Core, .remoteConfig, .integration))
    func getConfigStringValues() async throws {
        await testWorld.resetAll()

        let stringConfig = RemoteConfigModel(
            key: "apiEndpoint",
            value: "https://api.example.com",
            valueType: .string,
            category: .setting
        )

        try await testWorld.remoteConfigs.create(stringConfig)

        try await app.test(.GET, configPath) { response in
            #expect(response.status == .ok)
            expectContent(RemoteConfig.Get.Response.self, response) { config in
                #expect(config.settings["apiEndpoint"] == .string("https://api.example.com"))
            }
        }
    }

    @Test("Get config parses boolean false correctly", .tags(.p1Core, .remoteConfig, .integration))
    func getConfigBooleanFalse() async throws {
        await testWorld.resetAll()

        let falseConfig = RemoteConfigModel(
            key: "maintenanceMode",
            value: "false",
            valueType: .boolean,
            category: .featureFlag
        )

        try await testWorld.remoteConfigs.create(falseConfig)

        try await app.test(.GET, configPath) { response in
            #expect(response.status == .ok)
            expectContent(RemoteConfig.Get.Response.self, response) { config in
                #expect(config.featureFlags["maintenanceMode"] == .bool(false))
            }
        }
    }
}
