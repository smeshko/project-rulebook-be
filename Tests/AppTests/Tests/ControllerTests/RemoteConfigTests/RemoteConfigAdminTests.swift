@testable import App
import Fluent
import VaporTesting
import Testing

@Suite(.serialized)
struct RemoteConfigAdminTests {
    let app: Application
    let testWorld: IsolatedTestWorld
    let basePath = "api/v1/config"

    init() async throws {
        testWorld = try await IsolatedTestWorld()
        app = testWorld.app
    }

    // MARK: - POST (Create) Tests

    @Test("POST creates config when admin authenticated", .tags(.p0Critical, .remoteConfig, .integration))
    func createConfigAsAdmin() async throws {
        await testWorld.resetAll()

        let admin = try UserAccountModel.mock(app: app, email: "admin@test.com", isAdmin: true)
        try await app.repositories.users.create(admin)

        let request = RemoteConfig.Create.Request(
            key: "newFeature",
            value: "true",
            valueType: "boolean",
            category: "feature_flags"
        )

        try await app.test(.POST, basePath, user: admin, content: request, afterResponse: { response in
            #expect(response.status == .ok)
            expectContent(RemoteConfig.Create.Response.self, response) { config in
                #expect(config.key == "newFeature")
                #expect(config.value == "true")
                #expect(config.valueType == "boolean")
                #expect(config.category == "feature_flags")
            }
        })

        // Verify config was persisted
        let savedConfig = try await app.repositories.remoteConfigs.find(key: "newFeature")
        #expect(savedConfig != nil)
        #expect(savedConfig?.value == "true")
    }

    @Test("POST returns 401 when not authenticated", .tags(.p0Critical, .remoteConfig, .security, .integration))
    func createConfigNotAuthenticated() async throws {
        await testWorld.resetAll()

        let request = RemoteConfig.Create.Request(
            key: "newFeature",
            value: "true",
            valueType: "boolean",
            category: "feature_flags"
        )

        try await app.test(.POST, basePath, content: request, afterResponse: { res in
            #expect(res.status == .unauthorized)
        })
    }

    @Test("POST returns 401 when non-admin user", .tags(.p0Critical, .remoteConfig, .security, .integration))
    func createConfigNotAdmin() async throws {
        await testWorld.resetAll()

        let regularUser = try UserAccountModel.mock(app: app, email: "user@test.com", isAdmin: false)
        try await app.repositories.users.create(regularUser)

        let request = RemoteConfig.Create.Request(
            key: "newFeature",
            value: "true",
            valueType: "boolean",
            category: "feature_flags"
        )

        try await app.test(.POST, basePath, user: regularUser, content: request, afterResponse: { response in
            #expect(response.status == .unauthorized)
        })
    }

    @Test("POST returns 409 conflict for duplicate key", .tags(.p1Core, .remoteConfig, .integration))
    func createConfigDuplicateKey() async throws {
        await testWorld.resetAll()

        let admin = try UserAccountModel.mock(app: app, email: "admin@test.com", isAdmin: true)
        try await app.repositories.users.create(admin)

        // Create existing config
        let existing = RemoteConfigModel(key: "existingKey", value: "true", valueType: .boolean, category: .featureFlags)
        try await app.repositories.remoteConfigs.create(existing)

        let request = RemoteConfig.Create.Request(
            key: "existingKey",
            value: "false",
            valueType: "boolean",
            category: "feature_flags"
        )

        try await app.test(.POST, basePath, user: admin, content: request, afterResponse: { response in
            #expect(response.status == .conflict)
        })
    }

    // MARK: - PATCH (Update) Tests

    @Test("PATCH updates config when admin authenticated", .tags(.p0Critical, .remoteConfig, .integration))
    func updateConfigAsAdmin() async throws {
        await testWorld.resetAll()

        let admin = try UserAccountModel.mock(app: app, email: "admin@test.com", isAdmin: true)
        try await app.repositories.users.create(admin)

        // Create config to update
        let config = RemoteConfigModel(key: "updateMe", value: "true", valueType: .boolean, category: .featureFlags)
        try await app.repositories.remoteConfigs.create(config)

        let request = RemoteConfig.Update.Request(value: "false")

        try await app.test(.PATCH, "\(basePath)/updateMe", user: admin, content: request, afterResponse: { response in
            #expect(response.status == .ok)
            expectContent(RemoteConfig.Update.Response.self, response) { updated in
                #expect(updated.key == "updateMe")
                #expect(updated.value == "false")
            }
        })

        // Verify update persisted
        let savedConfig = try await app.repositories.remoteConfigs.find(key: "updateMe")
        #expect(savedConfig?.value == "false")
    }

    @Test("PATCH returns 401 when not authenticated", .tags(.p0Critical, .remoteConfig, .security, .integration))
    func updateConfigNotAuthenticated() async throws {
        await testWorld.resetAll()

        let config = RemoteConfigModel(key: "updateMe", value: "true", valueType: .boolean, category: .featureFlags)
        try await app.repositories.remoteConfigs.create(config)

        let request = RemoteConfig.Update.Request(value: "false")

        try await app.test(.PATCH, "\(basePath)/updateMe", content: request, afterResponse: { res in
            #expect(res.status == .unauthorized)
        })
    }

    @Test("PATCH returns 404 for non-existent key", .tags(.p1Core, .remoteConfig, .integration))
    func updateConfigNotFound() async throws {
        await testWorld.resetAll()

        let admin = try UserAccountModel.mock(app: app, email: "admin@test.com", isAdmin: true)
        try await app.repositories.users.create(admin)

        let request = RemoteConfig.Update.Request(value: "false")

        try await app.test(.PATCH, "\(basePath)/nonExistentKey", user: admin, content: request, afterResponse: { response in
            #expect(response.status == .notFound)
        })
    }

    // MARK: - DELETE Tests

    @Test("DELETE removes config when admin authenticated", .tags(.p0Critical, .remoteConfig, .integration))
    func deleteConfigAsAdmin() async throws {
        await testWorld.resetAll()

        let admin = try UserAccountModel.mock(app: app, email: "admin@test.com", isAdmin: true)
        try await app.repositories.users.create(admin)

        // Create config to delete
        let config = RemoteConfigModel(key: "deleteMe", value: "true", valueType: .boolean, category: .featureFlags)
        try await app.repositories.remoteConfigs.create(config)

        try await app.test(.DELETE, "\(basePath)/deleteMe", user: admin, afterResponse: { response in
            #expect(response.status == .ok)
            expectContent(RemoteConfig.Delete.Response.self, response) { deleted in
                #expect(deleted.key == "deleteMe")
                #expect(deleted.deleted == true)
            }
        })

        // Verify deletion
        let deletedConfig = try await app.repositories.remoteConfigs.find(key: "deleteMe")
        #expect(deletedConfig == nil)
    }

    @Test("DELETE returns 401 when not authenticated", .tags(.p0Critical, .remoteConfig, .security, .integration))
    func deleteConfigNotAuthenticated() async throws {
        await testWorld.resetAll()

        let config = RemoteConfigModel(key: "deleteMe", value: "true", valueType: .boolean, category: .featureFlags)
        try await app.repositories.remoteConfigs.create(config)

        try await app.test(.DELETE, "\(basePath)/deleteMe", afterResponse: { response in
            #expect(response.status == .unauthorized)
        })

        // Verify config still exists
        let existingConfig = try await app.repositories.remoteConfigs.find(key: "deleteMe")
        #expect(existingConfig != nil)
    }

    @Test("DELETE returns 404 for non-existent key", .tags(.p1Core, .remoteConfig, .integration))
    func deleteConfigNotFound() async throws {
        await testWorld.resetAll()

        let admin = try UserAccountModel.mock(app: app, email: "admin@test.com", isAdmin: true)
        try await app.repositories.users.create(admin)

        try await app.test(.DELETE, "\(basePath)/nonExistentKey", user: admin, afterResponse: { response in
            #expect(response.status == .notFound)
        })
    }
}
