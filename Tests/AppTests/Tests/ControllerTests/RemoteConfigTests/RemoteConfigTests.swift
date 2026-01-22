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

    // MARK: - Public GET Endpoint Tests

    @Test("GET /api/v1/config returns empty config when no entries exist", .tags(.p1Core, .config, .integration))
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

    @Test("GET /api/v1/config returns feature flags and settings", .tags(.p0Critical, .config, .integration))
    func getConfigWithEntries() async throws {
        await testWorld.resetAll()

        // Create test config entries
        let featureFlag = RemoteConfigModel(key: "enablePaywall", value: "true", valueType: "boolean")
        let setting = RemoteConfigModel(key: "maxRetries", value: "3", valueType: "integer")

        try await testWorld.remoteConfigs.create(featureFlag)
        try await testWorld.remoteConfigs.create(setting)

        try await app.test(.GET, configPath) { response in
            #expect(response.status == .ok)
            expectContent(RemoteConfig.Get.Response.self, response) { config in
                #expect(config.featureFlags.count == 1)
                #expect(config.settings.count == 1)

                // Verify feature flag
                let enablePaywall = config.featureFlags["enablePaywall"]
                #expect(enablePaywall != nil)
                #expect(enablePaywall?.value as? Bool == true)

                // Verify setting
                let maxRetries = config.settings["maxRetries"]
                #expect(maxRetries != nil)
                #expect(maxRetries?.value as? Int == 3)
            }
        }
    }

    @Test("GET /api/v1/config does not require authentication", .tags(.p0Critical, .config, .security, .integration))
    func getConfigNoAuthRequired() async throws {
        await testWorld.resetAll()

        // Request without any authentication
        try await app.test(.GET, configPath) { response in
            #expect(response.status == .ok)
        }
    }

    // MARK: - Admin POST Endpoint Tests

    @Test("POST /api/v1/config creates config for admin user", .tags(.p0Critical, .config, .integration))
    func createConfigAsAdmin() async throws {
        await testWorld.resetAll()

        let admin = try await testWorld.dataFactory.createAdminUser()
        try await app.repositories.users.create(admin)

        let createRequest = RemoteConfig.Create.Request(
            key: "newFeature",
            value: "true",
            valueType: "boolean",
            category: "feature_flags"
        )

        try await app.test(.POST, configPath, user: admin, beforeRequest: { req in
            try req.content.encode(createRequest)
        }) { response in
            #expect(response.status == .ok)
            expectContent(RemoteConfig.Create.Response.self, response) { createResponse in
                #expect(createResponse.message == "Configuration created successfully")
                #expect(createResponse.config.key == "newFeature")
                #expect(createResponse.config.value == "true")
                #expect(createResponse.config.valueType == "boolean")
            }
        }
    }

    @Test("POST /api/v1/config fails for unauthenticated request", .tags(.p0Critical, .config, .security, .integration))
    func createConfigUnauthenticated() async throws {
        await testWorld.resetAll()

        let createRequest = RemoteConfig.Create.Request(
            key: "newFeature",
            value: "true",
            valueType: "boolean",
            category: "feature_flags"
        )

        try await app.test(.POST, configPath, beforeRequest: { req in
            try req.content.encode(createRequest)
        }) { response in
            #expect(response.status == .unauthorized)
        }
    }

    @Test("POST /api/v1/config fails for non-admin user", .tags(.p0Critical, .config, .security, .integration))
    func createConfigAsNonAdmin() async throws {
        await testWorld.resetAll()

        let nonAdmin = try UserAccountModel.mock(app: app)
        try await app.repositories.users.create(nonAdmin)

        let createRequest = RemoteConfig.Create.Request(
            key: "newFeature",
            value: "true",
            valueType: "boolean",
            category: "feature_flags"
        )

        try await app.test(.POST, configPath, user: nonAdmin, beforeRequest: { req in
            try req.content.encode(createRequest)
        }) { response in
            #expect(response.status == .unauthorized)
        }
    }

    @Test("POST /api/v1/config returns conflict for duplicate key", .tags(.p1Core, .config, .integration))
    func createConfigDuplicateKey() async throws {
        await testWorld.resetAll()

        let admin = try await testWorld.dataFactory.createAdminUser()
        try await app.repositories.users.create(admin)

        // Create existing config
        let existing = RemoteConfigModel(key: "existingKey", value: "value", valueType: "string")
        try await testWorld.remoteConfigs.create(existing)

        let createRequest = RemoteConfig.Create.Request(
            key: "existingKey",
            value: "newValue",
            valueType: "string",
            category: "settings"
        )

        try await app.test(.POST, configPath, user: admin, beforeRequest: { req in
            try req.content.encode(createRequest)
        }) { response in
            #expect(response.status == .conflict)
        }
    }

    // MARK: - Admin PATCH Endpoint Tests

    @Test("PATCH /api/v1/config/:key updates config for admin user", .tags(.p0Critical, .config, .integration))
    func updateConfigAsAdmin() async throws {
        await testWorld.resetAll()

        let admin = try await testWorld.dataFactory.createAdminUser()
        try await app.repositories.users.create(admin)

        // Create config to update
        let existing = RemoteConfigModel(key: "updateMe", value: "oldValue", valueType: "string")
        try await testWorld.remoteConfigs.create(existing)

        let updateRequest = RemoteConfig.Update.Request(
            value: "newValue",
            valueType: nil
        )

        try await app.test(.PATCH, "\(configPath)/updateMe", user: admin, beforeRequest: { req in
            try req.content.encode(updateRequest)
        }) { response in
            #expect(response.status == .ok)
            expectContent(RemoteConfig.Update.Response.self, response) { updateResponse in
                #expect(updateResponse.message == "Configuration updated successfully")
                #expect(updateResponse.config.value == "newValue")
            }
        }
    }

    @Test("PATCH /api/v1/config/:key fails for unauthenticated request", .tags(.p0Critical, .config, .security, .integration))
    func updateConfigUnauthenticated() async throws {
        await testWorld.resetAll()

        let existing = RemoteConfigModel(key: "updateMe", value: "oldValue", valueType: "string")
        try await testWorld.remoteConfigs.create(existing)

        let updateRequest = RemoteConfig.Update.Request(
            value: "newValue",
            valueType: nil
        )

        try await app.test(.PATCH, "\(configPath)/updateMe", beforeRequest: { req in
            try req.content.encode(updateRequest)
        }) { response in
            #expect(response.status == .unauthorized)
        }
    }

    @Test("PATCH /api/v1/config/:key fails for non-admin user", .tags(.p0Critical, .config, .security, .integration))
    func updateConfigAsNonAdmin() async throws {
        await testWorld.resetAll()

        let nonAdmin = try UserAccountModel.mock(app: app)
        try await app.repositories.users.create(nonAdmin)

        let existing = RemoteConfigModel(key: "updateMe", value: "oldValue", valueType: "string")
        try await testWorld.remoteConfigs.create(existing)

        let updateRequest = RemoteConfig.Update.Request(
            value: "newValue",
            valueType: nil
        )

        try await app.test(.PATCH, "\(configPath)/updateMe", user: nonAdmin, beforeRequest: { req in
            try req.content.encode(updateRequest)
        }) { response in
            #expect(response.status == .unauthorized)
        }
    }

    @Test("PATCH /api/v1/config/:key returns not found for non-existent key", .tags(.p1Core, .config, .integration))
    func updateConfigNotFound() async throws {
        await testWorld.resetAll()

        let admin = try await testWorld.dataFactory.createAdminUser()
        try await app.repositories.users.create(admin)

        let updateRequest = RemoteConfig.Update.Request(
            value: "newValue",
            valueType: nil
        )

        try await app.test(.PATCH, "\(configPath)/nonExistentKey", user: admin, beforeRequest: { req in
            try req.content.encode(updateRequest)
        }) { response in
            #expect(response.status == .notFound)
        }
    }

    // MARK: - Admin DELETE Endpoint Tests

    @Test("DELETE /api/v1/config/:key deletes config for admin user", .tags(.p0Critical, .config, .integration))
    func deleteConfigAsAdmin() async throws {
        await testWorld.resetAll()

        let admin = try await testWorld.dataFactory.createAdminUser()
        try await app.repositories.users.create(admin)

        // Create config to delete
        let existing = RemoteConfigModel(key: "deleteMe", value: "value", valueType: "string")
        try await testWorld.remoteConfigs.create(existing)

        try await app.test(.DELETE, "\(configPath)/deleteMe", user: admin) { response in
            #expect(response.status == .ok)
            expectContent(RemoteConfig.Delete.Response.self, response) { deleteResponse in
                #expect(deleteResponse.message == "Configuration deleted successfully")
                #expect(deleteResponse.deleted == true)
            }
        }

        // Verify deleted
        let stillExists = try await testWorld.remoteConfigs.find(key: "deleteMe")
        #expect(stillExists == nil)
    }

    @Test("DELETE /api/v1/config/:key fails for unauthenticated request", .tags(.p0Critical, .config, .security, .integration))
    func deleteConfigUnauthenticated() async throws {
        await testWorld.resetAll()

        let existing = RemoteConfigModel(key: "deleteMe", value: "value", valueType: "string")
        try await testWorld.remoteConfigs.create(existing)

        try await app.test(.DELETE, "\(configPath)/deleteMe") { response in
            #expect(response.status == .unauthorized)
        }
    }

    @Test("DELETE /api/v1/config/:key fails for non-admin user", .tags(.p0Critical, .config, .security, .integration))
    func deleteConfigAsNonAdmin() async throws {
        await testWorld.resetAll()

        let nonAdmin = try UserAccountModel.mock(app: app)
        try await app.repositories.users.create(nonAdmin)

        let existing = RemoteConfigModel(key: "deleteMe", value: "value", valueType: "string")
        try await testWorld.remoteConfigs.create(existing)

        try await app.test(.DELETE, "\(configPath)/deleteMe", user: nonAdmin) { response in
            #expect(response.status == .unauthorized)
        }
    }

    @Test("DELETE /api/v1/config/:key returns not found for non-existent key", .tags(.p1Core, .config, .integration))
    func deleteConfigNotFound() async throws {
        await testWorld.resetAll()

        let admin = try await testWorld.dataFactory.createAdminUser()
        try await app.repositories.users.create(admin)

        try await app.test(.DELETE, "\(configPath)/nonExistentKey", user: admin) { response in
            #expect(response.status == .notFound)
        }
    }

    // MARK: - Value Type Validation Tests

    @Test("POST /api/v1/config validates boolean value type", .tags(.p1Core, .config, .integration))
    func createConfigInvalidBooleanValue() async throws {
        await testWorld.resetAll()

        let admin = try await testWorld.dataFactory.createAdminUser()
        try await app.repositories.users.create(admin)

        let createRequest = RemoteConfig.Create.Request(
            key: "invalidBoolean",
            value: "notABoolean",
            valueType: "boolean",
            category: "feature_flags"
        )

        try await app.test(.POST, configPath, user: admin, beforeRequest: { req in
            try req.content.encode(createRequest)
        }) { response in
            #expect(response.status == .badRequest)
        }
    }

    @Test("POST /api/v1/config validates integer value type", .tags(.p1Core, .config, .integration))
    func createConfigInvalidIntegerValue() async throws {
        await testWorld.resetAll()

        let admin = try await testWorld.dataFactory.createAdminUser()
        try await app.repositories.users.create(admin)

        let createRequest = RemoteConfig.Create.Request(
            key: "invalidInteger",
            value: "notAnInteger",
            valueType: "integer",
            category: "settings"
        )

        try await app.test(.POST, configPath, user: admin, beforeRequest: { req in
            try req.content.encode(createRequest)
        }) { response in
            #expect(response.status == .badRequest)
        }
    }

    // MARK: - Admin List Endpoint Tests

    @Test("GET /api/v1/config/list returns all configs for admin", .tags(.p1Core, .config, .integration))
    func listConfigsAsAdmin() async throws {
        await testWorld.resetAll()

        let admin = try await testWorld.dataFactory.createAdminUser()
        try await app.repositories.users.create(admin)

        // Create test configs
        let config1 = RemoteConfigModel(key: "key1", value: "value1", valueType: "string")
        let config2 = RemoteConfigModel(key: "key2", value: "true", valueType: "boolean")
        try await testWorld.remoteConfigs.create(config1)
        try await testWorld.remoteConfigs.create(config2)

        try await app.test(.GET, "\(configPath)/list", user: admin) { response in
            #expect(response.status == .ok)
            expectContent(RemoteConfig.List.Response.self, response) { listResponse in
                #expect(listResponse.count == 2)
                #expect(listResponse.configs.count == 2)
            }
        }
    }

    @Test("GET /api/v1/config/list fails for unauthenticated request", .tags(.p0Critical, .config, .security, .integration))
    func listConfigsUnauthenticated() async throws {
        await testWorld.resetAll()

        try await app.test(.GET, "\(configPath)/list") { response in
            #expect(response.status == .unauthorized)
        }
    }

    // MARK: - Cache Behavior Tests

    @Test("GET /api/v1/config serves cached response on subsequent requests", .tags(.p1Core, .config, .caching, .integration))
    func getConfigCacheHit() async throws {
        await testWorld.resetAll()

        // Create test config entry
        let config = RemoteConfigModel(key: "cachedKey", value: "cachedValue", valueType: "string")
        try await testWorld.remoteConfigs.create(config)

        // First request - cache miss, fetches from database
        try await app.test(.GET, configPath) { response in
            #expect(response.status == .ok)
            expectContent(RemoteConfig.Get.Response.self, response) { config in
                #expect(config.settings["cachedKey"] != nil)
            }
        }

        // Second request - should serve from cache
        try await app.test(.GET, configPath) { response in
            #expect(response.status == .ok)
            expectContent(RemoteConfig.Get.Response.self, response) { config in
                #expect(config.settings["cachedKey"] != nil)
            }
        }
    }

    @Test("POST /api/v1/config invalidates cache", .tags(.p1Core, .config, .caching, .integration))
    func createConfigInvalidatesCache() async throws {
        await testWorld.resetAll()

        let admin = try await testWorld.dataFactory.createAdminUser()
        try await app.repositories.users.create(admin)

        // Create initial config and trigger cache population
        let initial = RemoteConfigModel(key: "initialKey", value: "initialValue", valueType: "string")
        try await testWorld.remoteConfigs.create(initial)

        // First GET to populate cache
        try await app.test(.GET, configPath) { response in
            #expect(response.status == .ok)
        }

        // Create new config via API (should invalidate cache)
        let createRequest = RemoteConfig.Create.Request(
            key: "newKey",
            value: "newValue",
            valueType: "string",
            category: "settings"
        )

        try await app.test(.POST, configPath, user: admin, beforeRequest: { req in
            try req.content.encode(createRequest)
        }) { response in
            #expect(response.status == .ok)
        }

        // GET should now return updated config (cache was invalidated)
        try await app.test(.GET, configPath) { response in
            #expect(response.status == .ok)
            expectContent(RemoteConfig.Get.Response.self, response) { config in
                #expect(config.settings["newKey"] != nil)
            }
        }
    }

    @Test("PATCH /api/v1/config/:key invalidates cache", .tags(.p1Core, .config, .caching, .integration))
    func updateConfigInvalidatesCache() async throws {
        await testWorld.resetAll()

        let admin = try await testWorld.dataFactory.createAdminUser()
        try await app.repositories.users.create(admin)

        // Create config entry
        let config = RemoteConfigModel(key: "updateCacheKey", value: "oldValue", valueType: "string")
        try await testWorld.remoteConfigs.create(config)

        // First GET to populate cache
        try await app.test(.GET, configPath) { response in
            #expect(response.status == .ok)
            expectContent(RemoteConfig.Get.Response.self, response) { config in
                let value = config.settings["updateCacheKey"]
                #expect(value?.value as? String == "oldValue")
            }
        }

        // Update config via API (should invalidate cache)
        let updateRequest = RemoteConfig.Update.Request(
            value: "newValue",
            valueType: nil
        )

        try await app.test(.PATCH, "\(configPath)/updateCacheKey", user: admin, beforeRequest: { req in
            try req.content.encode(updateRequest)
        }) { response in
            #expect(response.status == .ok)
        }

        // GET should return updated value (cache was invalidated)
        try await app.test(.GET, configPath) { response in
            #expect(response.status == .ok)
            expectContent(RemoteConfig.Get.Response.self, response) { config in
                let value = config.settings["updateCacheKey"]
                #expect(value?.value as? String == "newValue")
            }
        }
    }

    @Test("DELETE /api/v1/config/:key invalidates cache", .tags(.p1Core, .config, .caching, .integration))
    func deleteConfigInvalidatesCache() async throws {
        await testWorld.resetAll()

        let admin = try await testWorld.dataFactory.createAdminUser()
        try await app.repositories.users.create(admin)

        // Create config entries
        let config1 = RemoteConfigModel(key: "keepKey", value: "keepValue", valueType: "string")
        let config2 = RemoteConfigModel(key: "deleteKey", value: "deleteValue", valueType: "string")
        try await testWorld.remoteConfigs.create(config1)
        try await testWorld.remoteConfigs.create(config2)

        // First GET to populate cache
        try await app.test(.GET, configPath) { response in
            #expect(response.status == .ok)
            expectContent(RemoteConfig.Get.Response.self, response) { config in
                #expect(config.settings["deleteKey"] != nil)
            }
        }

        // Delete config via API (should invalidate cache)
        try await app.test(.DELETE, "\(configPath)/deleteKey", user: admin) { response in
            #expect(response.status == .ok)
        }

        // GET should no longer return deleted config (cache was invalidated)
        try await app.test(.GET, configPath) { response in
            #expect(response.status == .ok)
            expectContent(RemoteConfig.Get.Response.self, response) { config in
                #expect(config.settings["deleteKey"] == nil)
                #expect(config.settings["keepKey"] != nil)
            }
        }
    }
}
