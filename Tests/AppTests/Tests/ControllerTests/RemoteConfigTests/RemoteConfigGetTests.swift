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

    @Test("GET config returns config without authentication", .tags(.p0Critical, .remoteConfig, .integration))
    func getConfigWithoutAuth() async throws {
        await testWorld.resetAll()

        // Seed some config data
        let enablePaywall = RemoteConfigModel(
            key: "enablePaywall",
            value: "true",
            valueType: .boolean,
            category: .featureFlags
        )
        let maxRetries = RemoteConfigModel(
            key: "maxRetries",
            value: "3",
            valueType: .integer,
            category: .settings
        )
        try await app.repositories.remoteConfigs.create(enablePaywall)
        try await app.repositories.remoteConfigs.create(maxRetries)

        try await app.test(.GET, path) { response in
            #expect(response.status == .ok)
            expectContent(RemoteConfig.Get.Response.self, response) { config in
                #expect(config.featureFlags.count == 1)
                #expect(config.settings.count == 1)

                // Verify feature flags
                if case .boolean(let value) = config.featureFlags["enablePaywall"] {
                    #expect(value == true)
                } else {
                    Issue.record("enablePaywall should be a boolean value")
                }

                // Verify settings
                if case .integer(let value) = config.settings["maxRetries"] {
                    #expect(value == 3)
                } else {
                    Issue.record("maxRetries should be an integer value")
                }
            }
        }
    }

    @Test("GET config returns correct structure with featureFlags and settings", .tags(.p1Core, .remoteConfig, .integration))
    func getConfigStructure() async throws {
        await testWorld.resetAll()

        // Create multiple configs in each category
        let flag1 = RemoteConfigModel(key: "feature1", value: "true", valueType: .boolean, category: .featureFlags)
        let flag2 = RemoteConfigModel(key: "feature2", value: "false", valueType: .boolean, category: .featureFlags)
        let setting1 = RemoteConfigModel(key: "timeout", value: "30", valueType: .integer, category: .settings)
        let setting2 = RemoteConfigModel(key: "apiUrl", value: "https://api.example.com", valueType: .string, category: .settings)

        try await app.repositories.remoteConfigs.create(flag1)
        try await app.repositories.remoteConfigs.create(flag2)
        try await app.repositories.remoteConfigs.create(setting1)
        try await app.repositories.remoteConfigs.create(setting2)

        try await app.test(.GET, path) { response in
            #expect(response.status == .ok)
            expectContent(RemoteConfig.Get.Response.self, response) { config in
                #expect(config.featureFlags.count == 2)
                #expect(config.settings.count == 2)

                // Verify boolean parsing
                if case .boolean(let value) = config.featureFlags["feature1"] {
                    #expect(value == true)
                }
                if case .boolean(let value) = config.featureFlags["feature2"] {
                    #expect(value == false)
                }

                // Verify integer parsing
                if case .integer(let value) = config.settings["timeout"] {
                    #expect(value == 30)
                }

                // Verify string parsing
                if case .string(let value) = config.settings["apiUrl"] {
                    #expect(value == "https://api.example.com")
                }
            }
        }
    }

    @Test("GET config returns empty when no configs exist", .tags(.p1Core, .remoteConfig, .integration))
    func getConfigEmpty() async throws {
        await testWorld.resetAll()

        try await app.test(.GET, path) { response in
            #expect(response.status == .ok)
            expectContent(RemoteConfig.Get.Response.self, response) { config in
                #expect(config.featureFlags.isEmpty)
                #expect(config.settings.isEmpty)
            }
        }
    }
}
