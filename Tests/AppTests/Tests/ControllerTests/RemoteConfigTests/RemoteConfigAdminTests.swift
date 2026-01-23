@testable import App
import Fluent
import VaporTesting
import Testing

@Suite(.serialized)
struct RemoteConfigAdminTests {
    let app: Application
    let testWorld: IsolatedTestWorld
    let adminPath = "api/v1/config/admin"

    init() async throws {
        testWorld = try await IsolatedTestWorld()
        app = testWorld.app
    }

    // MARK: - Create Config Tests

    @Test("Admin can create a new config entry", .tags(.p0Critical, .remoteConfig, .integration))
    func createConfigHappyPath() async throws {
        await testWorld.resetAll()
        let admin = try await testWorld.dataFactory.createAdminUser()
        try await app.repositories.users.create(admin)

        let createRequest = RemoteConfig.Create.Request(
            key: "newFeature",
            value: "true",
            valueType: .boolean,
            category: .featureFlag
        )

        try await app.test(.POST, adminPath, user: admin, content: createRequest, afterResponse: { response in
            #expect(response.status == .ok)
            expectContent(RemoteConfig.Create.Response.self, response) { created in
                #expect(created.key == "newFeature")
                #expect(created.value == "true")
                #expect(created.valueType == .boolean)
                #expect(created.category == .featureFlag)
            }
        })
    }

    @Test("Create config fails for non-admin user", .tags(.p0Critical, .remoteConfig, .security, .integration))
    func createConfigNonAdminFails() async throws {
        await testWorld.resetAll()
        let nonAdmin = try UserAccountModel.mock(app: app)
        try await app.repositories.users.create(nonAdmin)

        let createRequest = RemoteConfig.Create.Request(
            key: "newFeature",
            value: "true",
            valueType: .boolean,
            category: .featureFlag
        )

        try await app.test(.POST, adminPath, user: nonAdmin, content: createRequest, afterResponse: { response in
            #expect(response.status == .unauthorized)
        })
    }

    @Test("Create config fails for unauthenticated request", .tags(.p0Critical, .remoteConfig, .security, .integration))
    func createConfigUnauthenticatedFails() async throws {
        await testWorld.resetAll()

        let createRequest = RemoteConfig.Create.Request(
            key: "newFeature",
            value: "true",
            valueType: .boolean,
            category: .featureFlag
        )

        try await app.test(.POST, adminPath, content: createRequest, afterResponse: { response in
            #expect(response.status == .unauthorized)
        })
    }

    @Test("Create config fails with duplicate key", .tags(.p1Core, .remoteConfig, .integration))
    func createConfigDuplicateKeyFails() async throws {
        await testWorld.resetAll()
        let admin = try await testWorld.dataFactory.createAdminUser()
        try await app.repositories.users.create(admin)

        // Create existing config
        let existingConfig = RemoteConfigModel(
            key: "existingKey",
            value: "true",
            valueType: .boolean,
            category: .featureFlag
        )
        try await testWorld.remoteConfigs.create(existingConfig)

        let createRequest = RemoteConfig.Create.Request(
            key: "existingKey",
            value: "false",
            valueType: .boolean,
            category: .featureFlag
        )

        try await app.test(.POST, adminPath, user: admin, content: createRequest, afterResponse: { response in
            #expect(response.status == .conflict)
        })
    }

    @Test("Create config validates boolean value", .tags(.p1Core, .remoteConfig, .integration))
    func createConfigValidatesBooleanValue() async throws {
        await testWorld.resetAll()
        let admin = try await testWorld.dataFactory.createAdminUser()
        try await app.repositories.users.create(admin)

        let createRequest = RemoteConfig.Create.Request(
            key: "invalidBoolean",
            value: "notABoolean",
            valueType: .boolean,
            category: .featureFlag
        )

        try await app.test(.POST, adminPath, user: admin, content: createRequest, afterResponse: { response in
            #expect(response.status == .badRequest)
        })
    }

    @Test("Create config validates integer value", .tags(.p1Core, .remoteConfig, .integration))
    func createConfigValidatesIntegerValue() async throws {
        await testWorld.resetAll()
        let admin = try await testWorld.dataFactory.createAdminUser()
        try await app.repositories.users.create(admin)

        let createRequest = RemoteConfig.Create.Request(
            key: "invalidInteger",
            value: "notAnInteger",
            valueType: .integer,
            category: .setting
        )

        try await app.test(.POST, adminPath, user: admin, content: createRequest, afterResponse: { response in
            #expect(response.status == .badRequest)
        })
    }

    // MARK: - Update Config Tests

    @Test("Admin can update an existing config entry", .tags(.p0Critical, .remoteConfig, .integration))
    func updateConfigHappyPath() async throws {
        await testWorld.resetAll()
        let admin = try await testWorld.dataFactory.createAdminUser()
        try await app.repositories.users.create(admin)

        let existingConfig = RemoteConfigModel(
            key: "updateMe",
            value: "true",
            valueType: .boolean,
            category: .featureFlag
        )
        try await testWorld.remoteConfigs.create(existingConfig)
        let configId = existingConfig.id!

        let updateRequest = RemoteConfig.Update.Request(value: "false")

        try await app.test(.PATCH, "\(adminPath)/\(configId)", user: admin, content: updateRequest, afterResponse: { response in
            #expect(response.status == .ok)
            expectContent(RemoteConfig.Update.Response.self, response) { updated in
                #expect(updated.key == "updateMe")
                #expect(updated.value == "false")
            }
        })
    }

    @Test("Update config fails for non-admin user", .tags(.p0Critical, .remoteConfig, .security, .integration))
    func updateConfigNonAdminFails() async throws {
        await testWorld.resetAll()
        let nonAdmin = try UserAccountModel.mock(app: app)
        try await app.repositories.users.create(nonAdmin)

        let existingConfig = RemoteConfigModel(
            key: "updateMe",
            value: "true",
            valueType: .boolean,
            category: .featureFlag
        )
        try await testWorld.remoteConfigs.create(existingConfig)
        let configId = existingConfig.id!

        let updateRequest = RemoteConfig.Update.Request(value: "false")

        try await app.test(.PATCH, "\(adminPath)/\(configId)", user: nonAdmin, content: updateRequest, afterResponse: { response in
            #expect(response.status == .unauthorized)
        })
    }

    @Test("Update config fails for non-existent ID", .tags(.p1Core, .remoteConfig, .integration))
    func updateConfigNotFoundFails() async throws {
        await testWorld.resetAll()
        let admin = try await testWorld.dataFactory.createAdminUser()
        try await app.repositories.users.create(admin)

        let nonExistentId = UUID()
        let updateRequest = RemoteConfig.Update.Request(value: "false")

        try await app.test(.PATCH, "\(adminPath)/\(nonExistentId)", user: admin, content: updateRequest, afterResponse: { response in
            #expect(response.status == .notFound)
        })
    }

    // MARK: - Delete Config Tests

    @Test("Admin can delete a config entry", .tags(.p0Critical, .remoteConfig, .integration))
    func deleteConfigHappyPath() async throws {
        await testWorld.resetAll()
        let admin = try await testWorld.dataFactory.createAdminUser()
        try await app.repositories.users.create(admin)

        let existingConfig = RemoteConfigModel(
            key: "deleteMe",
            value: "true",
            valueType: .boolean,
            category: .featureFlag
        )
        try await testWorld.remoteConfigs.create(existingConfig)
        let configId = existingConfig.id!

        try await app.test(.DELETE, "\(adminPath)/\(configId)", user: admin) { response in
            #expect(response.status == .ok)
            expectContent(RemoteConfig.Delete.Response.self, response) { deleted in
                #expect(deleted.success == true)
            }
        }

        // Verify it's actually deleted
        let found = try await testWorld.remoteConfigs.find(id: configId)
        #expect(found == nil)
    }

    @Test("Delete config fails for non-admin user", .tags(.p0Critical, .remoteConfig, .security, .integration))
    func deleteConfigNonAdminFails() async throws {
        await testWorld.resetAll()
        let nonAdmin = try UserAccountModel.mock(app: app)
        try await app.repositories.users.create(nonAdmin)

        let existingConfig = RemoteConfigModel(
            key: "deleteMe",
            value: "true",
            valueType: .boolean,
            category: .featureFlag
        )
        try await testWorld.remoteConfigs.create(existingConfig)
        let configId = existingConfig.id!

        try await app.test(.DELETE, "\(adminPath)/\(configId)", user: nonAdmin) { response in
            #expect(response.status == .unauthorized)
        }
    }

    @Test("Delete config fails for unauthenticated request", .tags(.p0Critical, .remoteConfig, .security, .integration))
    func deleteConfigUnauthenticatedFails() async throws {
        await testWorld.resetAll()

        let existingConfig = RemoteConfigModel(
            key: "deleteMe",
            value: "true",
            valueType: .boolean,
            category: .featureFlag
        )
        try await testWorld.remoteConfigs.create(existingConfig)
        let configId = existingConfig.id!

        try await app.test(.DELETE, "\(adminPath)/\(configId)") { response in
            #expect(response.status == .unauthorized)
        }
    }

    @Test("Delete config fails for non-existent ID", .tags(.p1Core, .remoteConfig, .integration))
    func deleteConfigNotFoundFails() async throws {
        await testWorld.resetAll()
        let admin = try await testWorld.dataFactory.createAdminUser()
        try await app.repositories.users.create(admin)

        let nonExistentId = UUID()

        try await app.test(.DELETE, "\(adminPath)/\(nonExistentId)", user: admin) { response in
            #expect(response.status == .notFound)
        }
    }
}
