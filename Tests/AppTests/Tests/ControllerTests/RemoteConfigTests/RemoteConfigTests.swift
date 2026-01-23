@testable import App
import Fluent
import VaporTesting
import Testing

@Suite(.serialized)
struct RemoteConfigTests {
    let app: Application
    let testWorld: IsolatedTestWorld
    let configPath = "api/v1/config"

    init() async throws {
        testWorld = try await IsolatedTestWorld()
        app = testWorld.app
    }

    // MARK: - GET /api/v1/config Tests

    @Test("GET config returns empty response when no configs exist", .tags(.p1Core, .integration))
    func getConfigEmpty() async throws {
        await testWorld.resetAll()

        try await app.test(.GET, configPath) { response in
            #expect(response.status == .ok)
            expectContent(RemoteConfig.Get.Response.self, response) { config in
                #expect(config.featureFlags.isEmpty)
                #expect(config.settings.isEmpty)
            }
        }
    }

    @Test("GET config returns correct structure with feature flags and settings", .tags(.p0Critical, .integration))
    func getConfigReturnsCorrectStructure() async throws {
        await testWorld.resetAll()

        // Create test configs
        let featureFlag = RemoteConfigModel(
            key: "enablePaywall",
            value: "true",
            valueType: .boolean,
            category: .featureFlag
        )
        let setting = RemoteConfigModel(
            key: "maxRetries",
            value: "3",
            valueType: .integer,
            category: .setting
        )

        try await testWorld.remoteConfigs.create(featureFlag)
        try await testWorld.remoteConfigs.create(setting)

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

    @Test("GET config is accessible without authentication (public endpoint)", .tags(.p0Critical, .security, .integration))
    func getConfigIsPublic() async throws {
        await testWorld.resetAll()

        try await app.test(.GET, configPath) { response in
            #expect(response.status == .ok)
        }
    }

    @Test("GET config supports string value type", .tags(.p1Core, .integration))
    func getConfigSupportsStringType() async throws {
        await testWorld.resetAll()

        let stringSetting = RemoteConfigModel(
            key: "apiEndpoint",
            value: "https://api.example.com",
            valueType: .string,
            category: .setting
        )
        try await testWorld.remoteConfigs.create(stringSetting)

        try await app.test(.GET, configPath) { response in
            #expect(response.status == .ok)
            expectContent(RemoteConfig.Get.Response.self, response) { config in
                #expect(config.settings["apiEndpoint"] == .string("https://api.example.com"))
            }
        }
    }

    // MARK: - POST /api/v1/config Tests

    @Test("POST config requires authentication", .tags(.p0Critical, .security, .integration))
    func createConfigRequiresAuth() async throws {
        await testWorld.resetAll()

        try await app.test(.POST, configPath, beforeRequest: { req in
            try req.content.encode(RemoteConfig.Create.Request(
                key: "testKey",
                value: "testValue",
                valueType: .string,
                category: .setting
            ))
        }) { response in
            #expect(response.status == .unauthorized)
        }
    }

    @Test("POST config rejects non-admin users", .tags(.p0Critical, .security, .integration))
    func createConfigRejectsNonAdmin() async throws {
        await testWorld.resetAll()
        let nonAdmin = try UserAccountModel.mock(app: app, isAdmin: false)
        try await testWorld.users.create(nonAdmin)

        try await app.test(
            .POST,
            configPath,
            user: nonAdmin,
            content: RemoteConfig.Create.Request(
                key: "testKey",
                value: "testValue",
                valueType: .string,
                category: .setting
            ),
            afterResponse: { response in
                #expect(response.status == .unauthorized)
            }
        )
    }

    @Test("POST config succeeds for admin user", .tags(.p0Critical, .integration))
    func createConfigSucceedsForAdmin() async throws {
        await testWorld.resetAll()
        let admin = try UserAccountModel.mock(app: app, isAdmin: true)
        try await testWorld.users.create(admin)

        try await app.test(
            .POST,
            configPath,
            user: admin,
            content: RemoteConfig.Create.Request(
                key: "newFeature",
                value: "true",
                valueType: .boolean,
                category: .featureFlag
            ),
            afterResponse: { response in
                #expect(response.status == .ok)
                expectContent(RemoteConfig.Item.Response.self, response) { item in
                    #expect(item.key == "newFeature")
                    #expect(item.value == "true")
                    #expect(item.valueType == .boolean)
                    #expect(item.category == .featureFlag)
                }
            }
        )
    }

    @Test("POST config rejects duplicate key", .tags(.p1Core, .integration))
    func createConfigRejectsDuplicateKey() async throws {
        await testWorld.resetAll()
        let admin = try UserAccountModel.mock(app: app, isAdmin: true)
        try await testWorld.users.create(admin)

        // Create initial config
        let existing = RemoteConfigModel(
            key: "existingKey",
            value: "value",
            valueType: .string,
            category: .setting
        )
        try await testWorld.remoteConfigs.create(existing)

        try await app.test(
            .POST,
            configPath,
            user: admin,
            content: RemoteConfig.Create.Request(
                key: "existingKey",
                value: "newValue",
                valueType: .string,
                category: .setting
            ),
            afterResponse: { response in
                #expect(response.status == .badRequest)
            }
        )
    }

    // MARK: - PATCH /api/v1/config/:key Tests

    @Test("PATCH config requires authentication", .tags(.p0Critical, .security, .integration))
    func updateConfigRequiresAuth() async throws {
        await testWorld.resetAll()

        try await app.test(.PATCH, "\(configPath)/testKey", beforeRequest: { req in
            try req.content.encode(RemoteConfig.Update.Request(
                value: "newValue",
                valueType: nil,
                category: nil
            ))
        }) { response in
            #expect(response.status == .unauthorized)
        }
    }

    @Test("PATCH config rejects non-admin users", .tags(.p0Critical, .security, .integration))
    func updateConfigRejectsNonAdmin() async throws {
        await testWorld.resetAll()
        let nonAdmin = try UserAccountModel.mock(app: app, isAdmin: false)
        try await testWorld.users.create(nonAdmin)

        let existing = RemoteConfigModel(
            key: "testKey",
            value: "oldValue",
            valueType: .string,
            category: .setting
        )
        try await testWorld.remoteConfigs.create(existing)

        try await app.test(
            .PATCH,
            "\(configPath)/testKey",
            user: nonAdmin,
            content: RemoteConfig.Update.Request(
                value: "newValue",
                valueType: nil,
                category: nil
            ),
            afterResponse: { response in
                #expect(response.status == .unauthorized)
            }
        )
    }

    @Test("PATCH config succeeds for admin user", .tags(.p0Critical, .integration))
    func updateConfigSucceedsForAdmin() async throws {
        await testWorld.resetAll()
        let admin = try UserAccountModel.mock(app: app, isAdmin: true)
        try await testWorld.users.create(admin)

        let existing = RemoteConfigModel(
            key: "updateKey",
            value: "oldValue",
            valueType: .string,
            category: .setting
        )
        try await testWorld.remoteConfigs.create(existing)

        try await app.test(
            .PATCH,
            "\(configPath)/updateKey",
            user: admin,
            content: RemoteConfig.Update.Request(
                value: "newValue",
                valueType: nil,
                category: nil
            ),
            afterResponse: { response in
                #expect(response.status == .ok)
                expectContent(RemoteConfig.Item.Response.self, response) { item in
                    #expect(item.key == "updateKey")
                    #expect(item.value == "newValue")
                }
            }
        )
    }

    @Test("PATCH config returns 404 for non-existent key", .tags(.p1Core, .integration))
    func updateConfigReturns404ForMissingKey() async throws {
        await testWorld.resetAll()
        let admin = try UserAccountModel.mock(app: app, isAdmin: true)
        try await testWorld.users.create(admin)

        try await app.test(
            .PATCH,
            "\(configPath)/nonexistent",
            user: admin,
            content: RemoteConfig.Update.Request(
                value: "newValue",
                valueType: nil,
                category: nil
            ),
            afterResponse: { response in
                #expect(response.status == .notFound)
            }
        )
    }

    // MARK: - DELETE /api/v1/config/:key Tests

    @Test("DELETE config requires authentication", .tags(.p0Critical, .security, .integration))
    func deleteConfigRequiresAuth() async throws {
        await testWorld.resetAll()

        try await app.test(.DELETE, "\(configPath)/testKey") { response in
            #expect(response.status == .unauthorized)
        }
    }

    @Test("DELETE config rejects non-admin users", .tags(.p0Critical, .security, .integration))
    func deleteConfigRejectsNonAdmin() async throws {
        await testWorld.resetAll()
        let nonAdmin = try UserAccountModel.mock(app: app, isAdmin: false)
        try await testWorld.users.create(nonAdmin)

        let existing = RemoteConfigModel(
            key: "deleteKey",
            value: "value",
            valueType: .string,
            category: .setting
        )
        try await testWorld.remoteConfigs.create(existing)

        try await app.test(.DELETE, "\(configPath)/deleteKey", user: nonAdmin) { response in
            #expect(response.status == .unauthorized)
        }
    }

    @Test("DELETE config succeeds for admin user", .tags(.p0Critical, .integration))
    func deleteConfigSucceedsForAdmin() async throws {
        await testWorld.resetAll()
        let admin = try UserAccountModel.mock(app: app, isAdmin: true)
        try await testWorld.users.create(admin)

        let existing = RemoteConfigModel(
            key: "toDelete",
            value: "value",
            valueType: .string,
            category: .setting
        )
        try await testWorld.remoteConfigs.create(existing)

        try await app.test(.DELETE, "\(configPath)/toDelete", user: admin) { response in
            #expect(response.status == .noContent)
        }

        // Verify config is soft-deleted (not returned in GET)
        try await app.test(.GET, configPath) { response in
            expectContent(RemoteConfig.Get.Response.self, response) { config in
                #expect(config.settings["toDelete"] == nil)
            }
        }
    }

    @Test("DELETE config returns 404 for non-existent key", .tags(.p1Core, .integration))
    func deleteConfigReturns404ForMissingKey() async throws {
        await testWorld.resetAll()
        let admin = try UserAccountModel.mock(app: app, isAdmin: true)
        try await testWorld.users.create(admin)

        try await app.test(.DELETE, "\(configPath)/nonexistent", user: admin) { response in
            #expect(response.status == .notFound)
        }
    }

    // MARK: - Cache Tests

    @Test("GET config caches response after first call", .tags(.p2Extended, .caching, .integration))
    func getConfigCachesResponse() async throws {
        await testWorld.resetAll()

        // Create a config
        let config = RemoteConfigModel(
            key: "cachedKey",
            value: "cachedValue",
            valueType: .string,
            category: .setting
        )
        try await testWorld.remoteConfigs.create(config)

        // First call - cache miss
        try await app.test(.GET, configPath) { response in
            #expect(response.status == .ok)
            expectContent(RemoteConfig.Get.Response.self, response) { config in
                #expect(config.settings["cachedKey"] == .string("cachedValue"))
            }
        }

        // Verify cache was populated by checking it directly
        let cacheKey = RemoteConfigCacheService.cacheKey
        let cached = try await app.cacheService.get(cacheKey, as: RemoteConfig.Get.Response.self)
        #expect(cached != nil)
    }

    @Test("POST config invalidates cache", .tags(.p2Extended, .caching, .integration))
    func createConfigInvalidatesCache() async throws {
        await testWorld.resetAll()
        let admin = try UserAccountModel.mock(app: app, isAdmin: true)
        try await testWorld.users.create(admin)

        // Pre-populate cache by making a GET request
        try await app.test(.GET, configPath) { _ in }

        // Create new config
        try await app.test(
            .POST,
            configPath,
            user: admin,
            content: RemoteConfig.Create.Request(
                key: "newKey",
                value: "newValue",
                valueType: .string,
                category: .setting
            ),
            afterResponse: { response in
                #expect(response.status == .ok)
            }
        )

        // Verify cache was invalidated
        let cacheKey = RemoteConfigCacheService.cacheKey
        let cached = try await app.cacheService.get(cacheKey, as: RemoteConfig.Get.Response.self)
        #expect(cached == nil)
    }
}
