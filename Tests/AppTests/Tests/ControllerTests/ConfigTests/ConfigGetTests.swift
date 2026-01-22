@testable import App
import Fluent
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

    @Test("GET /api/v1/config returns grouped config structure", .tags(.p0Critical, .integration))
    func getConfigReturnsGroupedStructure() async throws {
        await testWorld.resetAll()

        // Create test config entries
        let featureFlag = ConfigEntryModel(
            key: "enablePaywall",
            value: "true",
            valueType: .boolean,
            category: .featureFlag
        )
        let setting = ConfigEntryModel(
            key: "maxRetries",
            value: "3",
            valueType: .integer,
            category: .setting
        )

        try await testWorld.configs.create(featureFlag)
        try await testWorld.configs.create(setting)

        try await app.test(.GET, configPath, afterResponse: { res in
            #expect(res.status == .ok)
            expectContent(Config.Get.Response.self, res) { response in
                #expect(response.featureFlags.count == 1)
                #expect(response.settings.count == 1)
                #expect(response.featureFlags["enablePaywall"] == .boolean(true))
                #expect(response.settings["maxRetries"] == .integer(3))
            }
        })
    }

    @Test("GET /api/v1/config returns empty structure when no configs", .tags(.p1Core, .integration))
    func getConfigReturnsEmptyWhenNoConfigs() async throws {
        await testWorld.resetAll()

        try await app.test(.GET, configPath, afterResponse: { res in
            #expect(res.status == .ok)
            expectContent(Config.Get.Response.self, res) { response in
                #expect(response.featureFlags.isEmpty)
                #expect(response.settings.isEmpty)
            }
        })
    }

    @Test("GET /api/v1/config supports different value types", .tags(.p1Core, .integration))
    func getConfigSupportsDifferentValueTypes() async throws {
        await testWorld.resetAll()

        // Create configs with different value types
        let boolConfig = ConfigEntryModel(
            key: "boolFlag",
            value: "false",
            valueType: .boolean,
            category: .featureFlag
        )
        let intConfig = ConfigEntryModel(
            key: "intSetting",
            value: "42",
            valueType: .integer,
            category: .setting
        )
        let stringConfig = ConfigEntryModel(
            key: "stringSetting",
            value: "hello world",
            valueType: .string,
            category: .setting
        )

        try await testWorld.configs.create(boolConfig)
        try await testWorld.configs.create(intConfig)
        try await testWorld.configs.create(stringConfig)

        try await app.test(.GET, configPath, afterResponse: { res in
            #expect(res.status == .ok)
            expectContent(Config.Get.Response.self, res) { response in
                #expect(response.featureFlags["boolFlag"] == .boolean(false))
                #expect(response.settings["intSetting"] == .integer(42))
                #expect(response.settings["stringSetting"] == .string("hello world"))
            }
        })
    }

    @Test("GET /api/v1/config does not require authentication", .tags(.p0Critical, .integration))
    func getConfigDoesNotRequireAuthentication() async throws {
        await testWorld.resetAll()

        // No auth header provided - should still work
        try await app.test(.GET, configPath, afterResponse: { res in
            #expect(res.status == .ok)
        })
    }

    @Test("GET /api/v1/config uses cache on second request", .tags(.p1Core, .caching, .integration))
    func getConfigUsesCache() async throws {
        await testWorld.resetAll()

        let config = ConfigEntryModel(
            key: "cacheTest",
            value: "initial",
            valueType: .string,
            category: .setting
        )
        try await testWorld.configs.create(config)

        // First request - cache miss, loads from DB
        try await app.test(.GET, configPath, afterResponse: { res in
            #expect(res.status == .ok)
            expectContent(Config.Get.Response.self, res) { response in
                #expect(response.settings["cacheTest"] == .string("initial"))
            }
        })

        // Modify the repository directly (simulating DB change without cache invalidation)
        config.value = "modified"
        try await testWorld.configs.update(config)

        // Second request - should return cached value (not the modified one)
        // because cache is still valid
        try await app.test(.GET, configPath, afterResponse: { res in
            #expect(res.status == .ok)
            expectContent(Config.Get.Response.self, res) { response in
                // Should still return "initial" from cache
                #expect(response.settings["cacheTest"] == .string("initial"))
            }
        })
    }
}
