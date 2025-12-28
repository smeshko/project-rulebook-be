@testable import App
import VaporTesting
import Testing

@Suite(.serialized)
struct ConfigAdminEndpointTests {
    let app: Application
    let testWorld: IsolatedTestWorld

    init() async throws {
        testWorld = try await IsolatedTestWorld()
        app = testWorld.app
    }

    // MARK: - Authentication Tests

    @Test("Admin list endpoint requires authentication")
    func adminListRequiresAuth() async throws {
        await testWorld.resetAll()

        try await app.test(.GET, "api/v1/admin/config", afterResponse: { response in
            #expect(response.status == .unauthorized)
        })
    }

    @Test("Admin create endpoint requires authentication")
    func adminCreateRequiresAuth() async throws {
        await testWorld.resetAll()

        let createRequest = Config.Admin.CreateRequest(
            key: "testKey",
            value: "testValue",
            type: "string"
        )

        try await app.test(.POST, "api/v1/admin/config", content: createRequest, afterResponse: { response in
            #expect(response.status == .unauthorized)
        })
    }

    @Test("Admin update endpoint requires authentication")
    func adminUpdateRequiresAuth() async throws {
        await testWorld.resetAll()

        let updateRequest = Config.Admin.UpdateRequest(
            value: "newValue",
            type: nil
        )

        try await app.test(.PUT, "api/v1/admin/config/testKey", content: updateRequest, afterResponse: { response in
            #expect(response.status == .unauthorized)
        })
    }

    @Test("Admin delete endpoint requires authentication")
    func adminDeleteRequiresAuth() async throws {
        await testWorld.resetAll()

        try await app.test(.DELETE, "api/v1/admin/config/testKey", afterResponse: { response in
            #expect(response.status == .unauthorized)
        })
    }

    // MARK: - Authorized Admin Operations

    @Test("Admin list returns all config entries")
    func adminListReturnsAllEntries() async throws {
        await testWorld.resetAll()

        // Create admin user
        let adminUser = try await testWorld.dataFactory.createAdminUser()

        // Seed config data
        try await testWorld.configs.seed()

        try await app.test(.GET, "api/v1/admin/config", user: adminUser) { response in
            #expect(response.status == .ok)
            let listResponse = try response.content.decode(Config.Admin.ListResponse.self)
            #expect(listResponse.entries.count >= 4) // enableNewScanner, showPromotion, maxRetries, cacheTimeoutSeconds
        }
    }

    @Test("Admin create config entry succeeds")
    func adminCreateConfigSucceeds() async throws {
        await testWorld.resetAll()

        // Create admin user
        let adminUser = try await testWorld.dataFactory.createAdminUser()

        let createRequest = Config.Admin.CreateRequest(
            key: "newFeature",
            value: "true",
            type: "boolean"
        )

        try await app.test(.POST, "api/v1/admin/config", user: adminUser, content: createRequest, afterResponse: { response in
            #expect(response.status == .ok)
            let entryResponse = try response.content.decode(Config.Admin.ConfigEntryResponse.self)
            #expect(entryResponse.key == "newFeature")
            #expect(entryResponse.value == "true")
            #expect(entryResponse.type == "boolean")
        })
    }

    @Test("Admin create duplicate key returns conflict")
    func adminCreateDuplicateKeyReturnsConflict() async throws {
        await testWorld.resetAll()

        // Create admin user
        let adminUser = try await testWorld.dataFactory.createAdminUser()

        // Seed config data (includes "enableNewScanner")
        try await testWorld.configs.seed()

        let createRequest = Config.Admin.CreateRequest(
            key: "enableNewScanner", // This already exists
            value: "false",
            type: "boolean"
        )

        try await app.test(.POST, "api/v1/admin/config", user: adminUser, content: createRequest, afterResponse: { response in
            #expect(response.status == .conflict)
        })
    }

    @Test("Admin update config entry succeeds")
    func adminUpdateConfigSucceeds() async throws {
        await testWorld.resetAll()

        // Create admin user
        let adminUser = try await testWorld.dataFactory.createAdminUser()

        // Seed config data
        try await testWorld.configs.seed()

        let updateRequest = Config.Admin.UpdateRequest(
            value: "false", // Change from true to false
            type: nil
        )

        try await app.test(.PUT, "api/v1/admin/config/enableNewScanner", user: adminUser, content: updateRequest, afterResponse: { response in
            #expect(response.status == .ok)
            let entryResponse = try response.content.decode(Config.Admin.ConfigEntryResponse.self)
            #expect(entryResponse.key == "enableNewScanner")
            #expect(entryResponse.value == "false")
        })
    }

    @Test("Admin update non-existent key returns not found")
    func adminUpdateNonExistentKeyReturnsNotFound() async throws {
        await testWorld.resetAll()

        // Create admin user
        let adminUser = try await testWorld.dataFactory.createAdminUser()

        let updateRequest = Config.Admin.UpdateRequest(
            value: "newValue",
            type: nil
        )

        try await app.test(.PUT, "api/v1/admin/config/nonExistentKey", user: adminUser, content: updateRequest, afterResponse: { response in
            #expect(response.status == .notFound)
        })
    }

    @Test("Admin delete config entry succeeds")
    func adminDeleteConfigSucceeds() async throws {
        await testWorld.resetAll()

        // Create admin user
        let adminUser = try await testWorld.dataFactory.createAdminUser()

        // Seed config data
        try await testWorld.configs.seed()

        try await app.test(.DELETE, "api/v1/admin/config/enableNewScanner", user: adminUser) { response in
            #expect(response.status == .ok)
            let deleteResponse = try response.content.decode(Config.Admin.DeleteResponse.self)
            #expect(deleteResponse.message.contains("deleted"))
        }

        // Verify it's actually deleted
        let remaining = try await testWorld.configs.findAll()
        #expect(!remaining.contains { $0.key == "enableNewScanner" })
    }

    @Test("Admin delete non-existent key returns not found")
    func adminDeleteNonExistentKeyReturnsNotFound() async throws {
        await testWorld.resetAll()

        // Create admin user
        let adminUser = try await testWorld.dataFactory.createAdminUser()

        try await app.test(.DELETE, "api/v1/admin/config/nonExistentKey", user: adminUser) { response in
            #expect(response.status == .notFound)
        }
    }

    @Test("Non-admin user cannot access admin endpoints")
    func nonAdminUserCannotAccessAdminEndpoints() async throws {
        await testWorld.resetAll()

        // Create regular (non-admin) user
        let regularUser = try UserAccountModel.mock(app: app, isEmailVerified: true)
        try await app.repositories.users.create(regularUser)

        try await app.test(.GET, "api/v1/admin/config", user: regularUser) { response in
            #expect(response.status == .unauthorized)
        }
    }
}
