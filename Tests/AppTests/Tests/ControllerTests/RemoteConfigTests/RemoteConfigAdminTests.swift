@testable import App
import Fluent
import VaporTesting
import Testing

@Suite(.serialized)
struct RemoteConfigAdminTests {
    let app: Application
    let testWorld: IsolatedTestWorld
    let configPath = "api/v1/config"

    init() async throws {
        testWorld = try await IsolatedTestWorld()
        app = testWorld.app
    }

    // MARK: - Create Config Tests

    @Test("Admin can create config entry", .tags(.p0Critical, .integration))
    func adminCreateConfig() async throws {
        await testWorld.resetAll()

        let user = try UserAccountModel.mock(app: app, isAdmin: true)
        try await app.repositories.users.create(user)

        let createRequest = RemoteConfig.Create.Request(
            key: "featureFlags.newFeature",
            value: "true",
            valueType: "boolean"
        )

        try await app.test(.POST, configPath, user: user, content: createRequest, afterResponse: { res in
            #expect(res.status == .ok)
            expectContent(RemoteConfig.Create.Response.self, res) { response in
                #expect(response.key == "featureFlags.newFeature")
                #expect(response.value == "true")
                #expect(response.valueType == "boolean")
            }
        })

        // Verify entry was persisted
        let count = try await app.repositories.remoteConfig.count()
        #expect(count == 1)
    }

    @Test("Admin can create integer config entry", .tags(.p1Core, .integration))
    func adminCreateIntegerConfig() async throws {
        await testWorld.resetAll()

        let user = try UserAccountModel.mock(app: app, isAdmin: true)
        try await app.repositories.users.create(user)

        let createRequest = RemoteConfig.Create.Request(
            key: "settings.maxItems",
            value: "100",
            valueType: "integer"
        )

        try await app.test(.POST, configPath, user: user, content: createRequest, afterResponse: { res in
            #expect(res.status == .ok)
            expectContent(RemoteConfig.Create.Response.self, res) { response in
                #expect(response.value == "100")
                #expect(response.valueType == "integer")
            }
        })
    }

    @Test("Create fails with duplicate key", .tags(.p1Core, .integration))
    func createFailsWithDuplicateKey() async throws {
        await testWorld.resetAll()

        let existing = RemoteConfigModel.create(key: "featureFlags.existing", boolValue: true)
        try await app.repositories.remoteConfig.create(existing)

        let user = try UserAccountModel.mock(app: app, isAdmin: true)
        try await app.repositories.users.create(user)

        let createRequest = RemoteConfig.Create.Request(
            key: "featureFlags.existing",
            value: "false",
            valueType: "boolean"
        )

        try await app.test(.POST, configPath, user: user, content: createRequest, afterResponse: { res in
            #expect(res.status == .conflict)
        })
    }

    // MARK: - Update Config Tests

    @Test("Admin can update config entry", .tags(.p0Critical, .integration))
    func adminUpdateConfig() async throws {
        await testWorld.resetAll()

        let config = RemoteConfigModel.create(key: "featureFlags.updateMe", boolValue: false)
        try await app.repositories.remoteConfig.create(config)

        let user = try UserAccountModel.mock(app: app, isAdmin: true)
        try await app.repositories.users.create(user)

        let updateRequest = RemoteConfig.Update.Request(
            value: "true",
            valueType: nil
        )

        try await app.test(.PATCH, "\(configPath)/featureFlags.updateMe", user: user, content: updateRequest, afterResponse: { res in
            #expect(res.status == .ok)
            expectContent(RemoteConfig.Update.Response.self, res) { response in
                #expect(response.key == "featureFlags.updateMe")
                #expect(response.value == "true")
            }
        })
    }

    @Test("Update fails for non-existent key", .tags(.p1Core, .integration))
    func updateFailsForNonExistentKey() async throws {
        await testWorld.resetAll()

        let user = try UserAccountModel.mock(app: app, isAdmin: true)
        try await app.repositories.users.create(user)

        let updateRequest = RemoteConfig.Update.Request(
            value: "true",
            valueType: nil
        )

        try await app.test(.PATCH, "\(configPath)/nonexistent.key", user: user, content: updateRequest, afterResponse: { res in
            #expect(res.status == .notFound)
        })
    }

    // MARK: - Delete Config Tests

    @Test("Admin can delete config entry", .tags(.p0Critical, .integration))
    func adminDeleteConfig() async throws {
        await testWorld.resetAll()

        let config = RemoteConfigModel.create(key: "featureFlags.deleteMe", boolValue: true)
        try await app.repositories.remoteConfig.create(config)

        let user = try UserAccountModel.mock(app: app, isAdmin: true)
        try await app.repositories.users.create(user)

        try await app.test(.DELETE, "\(configPath)/featureFlags.deleteMe", user: user, afterResponse: { res in
            #expect(res.status == .ok)
            expectContent(RemoteConfig.Delete.Response.self, res) { response in
                #expect(response.key == "featureFlags.deleteMe")
            }
        })

        // Verify entry was deleted
        let count = try await app.repositories.remoteConfig.count()
        #expect(count == 0)
    }

    @Test("Delete fails for non-existent key", .tags(.p1Core, .integration))
    func deleteFailsForNonExistentKey() async throws {
        await testWorld.resetAll()

        let user = try UserAccountModel.mock(app: app, isAdmin: true)
        try await app.repositories.users.create(user)

        try await app.test(.DELETE, "\(configPath)/nonexistent.key", user: user, afterResponse: { res in
            #expect(res.status == .notFound)
        })
    }

    // MARK: - Authentication Tests

    @Test("Non-authenticated user gets 401 on admin endpoints", .tags(.p0Critical, .integration))
    func nonAuthenticatedUserGetsForbidden() async throws {
        await testWorld.resetAll()

        let createRequest = RemoteConfig.Create.Request(
            key: "featureFlags.test",
            value: "true",
            valueType: "boolean"
        )

        // POST without auth
        try await app.test(.POST, configPath, content: createRequest, afterResponse: { res in
            #expect(res.status == .unauthorized)
        })

        // PATCH without auth
        try await app.test(.PATCH, "\(configPath)/somekey", content: RemoteConfig.Update.Request(value: "test", valueType: nil), afterResponse: { res in
            #expect(res.status == .unauthorized)
        })

        // DELETE without auth
        try await app.test(.DELETE, "\(configPath)/somekey", afterResponse: { res in
            #expect(res.status == .unauthorized)
        })

        // Admin list without auth
        try await app.test(.GET, "\(configPath)/admin", afterResponse: { res in
            #expect(res.status == .unauthorized)
        })
    }

    @Test("Authenticated non-admin user gets 401 on admin endpoints", .tags(.p0Critical, .integration))
    func nonAdminUserGetsForbidden() async throws {
        await testWorld.resetAll()

        // Create regular (non-admin) user
        let user = try UserAccountModel.mock(app: app, isAdmin: false)
        try await app.repositories.users.create(user)

        let createRequest = RemoteConfig.Create.Request(
            key: "featureFlags.test",
            value: "true",
            valueType: "boolean"
        )

        // POST as non-admin
        try await app.test(.POST, configPath, user: user, content: createRequest, afterResponse: { res in
            #expect(res.status == .unauthorized)
        })

        // PATCH as non-admin
        try await app.test(.PATCH, "\(configPath)/somekey", user: user, content: RemoteConfig.Update.Request(value: "test", valueType: nil), afterResponse: { res in
            #expect(res.status == .unauthorized)
        })

        // DELETE as non-admin
        try await app.test(.DELETE, "\(configPath)/somekey", user: user, afterResponse: { res in
            #expect(res.status == .unauthorized)
        })
    }

    // MARK: - Cache Invalidation Tests

    @Test("Cache invalidation on write operations", .tags(.p1Core, .integration))
    func cacheInvalidationOnWrite() async throws {
        await testWorld.resetAll()

        let config = RemoteConfigModel.create(key: "featureFlags.cacheInvalidate", boolValue: true)
        try await app.repositories.remoteConfig.create(config)

        // First GET to populate cache
        try await app.test(.GET, configPath, afterResponse: { res in
            #expect(res.status == .ok)
        })

        // Verify cache exists
        let cacheKey = "remote_config_all"
        var cached = try await app.cacheService.exists(cacheKey)
        #expect(cached == true)

        // Create admin user and update config
        let user = try UserAccountModel.mock(app: app, isAdmin: true)
        try await app.repositories.users.create(user)

        // Update should invalidate cache
        try await app.test(.PATCH, "\(configPath)/featureFlags.cacheInvalidate", user: user, content: RemoteConfig.Update.Request(value: "false", valueType: nil), afterResponse: { res in
            #expect(res.status == .ok)
        })

        // Verify cache was invalidated
        cached = try await app.cacheService.exists(cacheKey)
        #expect(cached == false)
    }

    // MARK: - List Admin Config Tests

    @Test("Admin can list all config entries with metadata", .tags(.p1Core, .integration))
    func adminListConfig() async throws {
        await testWorld.resetAll()

        let config1 = RemoteConfigModel.create(key: "featureFlags.flag1", boolValue: true)
        let config2 = RemoteConfigModel.create(key: "settings.setting1", intValue: 42)
        try await app.repositories.remoteConfig.create(config1)
        try await app.repositories.remoteConfig.create(config2)

        let user = try UserAccountModel.mock(app: app, isAdmin: true)
        try await app.repositories.users.create(user)

        try await app.test(.GET, "\(configPath)/admin", user: user, afterResponse: { res in
            #expect(res.status == .ok)
            expectContent(RemoteConfig.List.Response.self, res) { response in
                #expect(response.entries.count == 2)
                // Entries should include metadata (id, valueType, timestamps)
                let flag = response.entries.first { $0.key == "featureFlags.flag1" }
                #expect(flag?.valueType == "boolean")
                #expect(flag?.value == "true")
            }
        })
    }

    // MARK: - Value Type Validation Tests

    @Test("Create fails with invalid valueType", .tags(.p1Core, .integration))
    func createFailsWithInvalidValueType() async throws {
        await testWorld.resetAll()

        let user = try UserAccountModel.mock(app: app, isAdmin: true)
        try await app.repositories.users.create(user)

        let payload = try TokenPayload(with: user)
        let accessToken = try app.jwt.signers.sign(payload)

        // Use raw JSON to send invalid valueType that bypasses Codable validation
        try await app.test(.POST, configPath, beforeRequest: { req in
            req.headers.add(name: "Authorization", value: "Bearer \(accessToken)")
            req.headers.contentType = .json
            req.body = ByteBuffer(string: """
                {"key": "test.key", "value": "123", "valueType": "invalid"}
            """)
        }, afterResponse: { res in
            #expect(res.status == .badRequest)
        })
    }

    @Test("Update fails with invalid valueType", .tags(.p1Core, .integration))
    func updateFailsWithInvalidValueType() async throws {
        await testWorld.resetAll()

        let config = RemoteConfigModel.create(key: "settings.testKey", intValue: 42)
        try await app.repositories.remoteConfig.create(config)

        let user = try UserAccountModel.mock(app: app, isAdmin: true)
        try await app.repositories.users.create(user)

        let payload = try TokenPayload(with: user)
        let accessToken = try app.jwt.signers.sign(payload)

        // Use raw JSON to send invalid valueType that bypasses Codable validation
        try await app.test(.PATCH, "\(configPath)/settings.testKey", beforeRequest: { req in
            req.headers.add(name: "Authorization", value: "Bearer \(accessToken)")
            req.headers.contentType = .json
            req.body = ByteBuffer(string: """
                {"value": "100", "valueType": "invalid"}
            """)
        }, afterResponse: { res in
            #expect(res.status == .badRequest)
        })
    }

    @Test("Update without valueType preserves existing type", .tags(.p1Core, .integration))
    func updateWithoutValueTypePreservesExistingType() async throws {
        await testWorld.resetAll()

        let config = RemoteConfigModel.create(key: "settings.preserveType", intValue: 42)
        try await app.repositories.remoteConfig.create(config)

        let user = try UserAccountModel.mock(app: app, isAdmin: true)
        try await app.repositories.users.create(user)

        let updateRequest = RemoteConfig.Update.Request(
            value: "100",
            valueType: nil
        )

        try await app.test(.PATCH, "\(configPath)/settings.preserveType", user: user, content: updateRequest, afterResponse: { res in
            #expect(res.status == .ok)
            expectContent(RemoteConfig.Update.Response.self, res) { response in
                #expect(response.value == "100")
                #expect(response.valueType == "integer") // Type should be preserved
            }
        })
    }
}
