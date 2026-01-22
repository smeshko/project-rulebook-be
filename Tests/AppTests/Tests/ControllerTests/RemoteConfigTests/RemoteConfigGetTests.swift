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

    @Test("Public endpoint returns config without authentication", .tags(.p0Critical, .integration))
    func getConfigPublicEndpoint() async throws {
        await testWorld.resetAll()

        // Create some config entries
        let enablePaywall = RemoteConfigModel.create(key: "featureFlags.enablePaywall", boolValue: true)
        let maxRetries = RemoteConfigModel.create(key: "settings.maxRetries", intValue: 3)

        try await app.repositories.remoteConfig.create(enablePaywall)
        try await app.repositories.remoteConfig.create(maxRetries)

        // No authentication header - should still work
        try await app.test(.GET, configPath, afterResponse: { res in
            #expect(res.status == .ok)
            expectContent(RemoteConfig.Get.Response.self, res) { config in
                #expect(config.featureFlags["enablePaywall"] == true)
                #expect(config.settings["maxRetries"] == .int(3))
            }
        })
    }

    @Test("Config response structure matches expected format", .tags(.p0Critical, .integration))
    func configResponseStructure() async throws {
        await testWorld.resetAll()

        // Create varied config entries
        let featureFlag = RemoteConfigModel.create(key: "featureFlags.darkMode", boolValue: false)
        let intSetting = RemoteConfigModel.create(key: "settings.timeout", intValue: 30)
        let stringSetting = RemoteConfigModel.create(key: "settings.apiUrl", stringValue: "https://api.example.com")

        try await app.repositories.remoteConfig.create(featureFlag)
        try await app.repositories.remoteConfig.create(intSetting)
        try await app.repositories.remoteConfig.create(stringSetting)

        try await app.test(.GET, configPath, afterResponse: { res in
            #expect(res.status == .ok)
            expectContent(RemoteConfig.Get.Response.self, res) { config in
                // Feature flags should be grouped correctly
                #expect(config.featureFlags["darkMode"] == false)

                // Settings should be grouped correctly with proper types
                #expect(config.settings["timeout"] == .int(30))
                #expect(config.settings["apiUrl"] == .string("https://api.example.com"))
            }
        })
    }

    @Test("Returns empty config when no entries exist", .tags(.p1Core, .integration))
    func emptyConfigResponse() async throws {
        await testWorld.resetAll()

        try await app.test(.GET, configPath, afterResponse: { res in
            #expect(res.status == .ok)
            expectContent(RemoteConfig.Get.Response.self, res) { config in
                #expect(config.featureFlags.isEmpty)
                #expect(config.settings.isEmpty)
            }
        })
    }

    @Test("Config values are cached in Redis", .tags(.p1Core, .integration))
    func configCaching() async throws {
        await testWorld.resetAll()

        let config = RemoteConfigModel.create(key: "featureFlags.cacheTest", boolValue: true)
        try await app.repositories.remoteConfig.create(config)

        // First request - should be cache miss
        try await app.test(.GET, configPath, afterResponse: { res in
            #expect(res.status == .ok)
        })

        // Verify cache was populated
        let cacheKey = "remote_config_all"
        let cached = try await app.cacheService.exists(cacheKey)
        #expect(cached == true)

        // Second request should use cache (we verify by checking cache still exists)
        try await app.test(.GET, configPath, afterResponse: { res in
            #expect(res.status == .ok)
        })
    }
}
