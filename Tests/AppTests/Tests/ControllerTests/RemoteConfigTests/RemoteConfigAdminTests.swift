@testable import App
import Fluent
import VaporTesting
import Testing

@Suite(.serialized)
struct RemoteConfigAdminTests {
    let app: Application
    let testWorld: IsolatedTestWorld
    let adminConfigPath = "api/v1/admin/config"

    init() async throws {
        testWorld = try await IsolatedTestWorld()
        app = testWorld.app
    }

    // MARK: - List Tests

    @Test("Admin can list all config entries", .tags(.p1Core, .integration))
    func adminCanListConfigEntries() async throws {
        await testWorld.resetAll()

        let admin = try UserAccountModel.mock(app: app, isAdmin: true)
        try await app.repositories.users.create(admin)

        // Create some config entries
        let entry1 = RemoteConfigEntryModel(key: "feature1", value: "true", valueType: .boolean)
        let entry2 = RemoteConfigEntryModel(key: "maxItems", value: "100", valueType: .integer)
        try await app.repositories.remoteConfig.create(entry1)
        try await app.repositories.remoteConfig.create(entry2)

        try await app.test(.GET, adminConfigPath, user: admin, afterResponse: { res in
            #expect(res.status == .ok)
            expectContent(RemoteConfig.List.Response.self, res) { list in
                #expect(list.total == 2)
                #expect(list.items.count == 2)
            }
        })
    }

    @Test("Non-admin cannot list config entries", .tags(.p0Critical, .integration))
    func nonAdminCannotListConfigEntries() async throws {
        await testWorld.resetAll()

        let user = try UserAccountModel.mock(app: app, isAdmin: false)
        try await app.repositories.users.create(user)

        try await app.test(.GET, adminConfigPath, user: user, afterResponse: { res in
            #expect(res.status == .unauthorized)
        })
    }

    @Test("Unauthenticated user cannot list config entries", .tags(.p0Critical, .integration))
    func unauthenticatedCannotListConfigEntries() async throws {
        await testWorld.resetAll()

        try await app.test(.GET, adminConfigPath, afterResponse: { res in
            #expect(res.status == .unauthorized)
        })
    }

    // MARK: - Create Tests

    @Test("Admin can create boolean config entry", .tags(.p1Core, .integration))
    func adminCanCreateBooleanConfig() async throws {
        await testWorld.resetAll()

        let admin = try UserAccountModel.mock(app: app, isAdmin: true)
        try await app.repositories.users.create(admin)

        let createRequest = RemoteConfig.Create.Request(
            key: "enableFeature",
            value: "true",
            valueType: .boolean,
            description: "Enable new feature"
        )

        try await app.test(.POST, adminConfigPath, user: admin, content: createRequest, afterResponse: { res in
            #expect(res.status == .ok)
            expectContent(RemoteConfig.Create.Response.self, res) { created in
                #expect(created.key == "enableFeature")
                #expect(created.value == "true")
                #expect(created.valueType == .boolean)
                #expect(created.description == "Enable new feature")
            }
        })

        // Verify it was persisted
        let count = try await app.repositories.remoteConfig.count()
        #expect(count == 1)
    }

    @Test("Admin can create integer config entry", .tags(.p1Core, .integration))
    func adminCanCreateIntegerConfig() async throws {
        await testWorld.resetAll()

        let admin = try UserAccountModel.mock(app: app, isAdmin: true)
        try await app.repositories.users.create(admin)

        let createRequest = RemoteConfig.Create.Request(
            key: "maxRetries",
            value: "5",
            valueType: .integer,
            description: nil
        )

        try await app.test(.POST, adminConfigPath, user: admin, content: createRequest, afterResponse: { res in
            #expect(res.status == .ok)
            expectContent(RemoteConfig.Create.Response.self, res) { created in
                #expect(created.key == "maxRetries")
                #expect(created.value == "5")
                #expect(created.valueType == .integer)
            }
        })
    }

    @Test("Admin can create JSON config entry", .tags(.p2Extended, .integration))
    func adminCanCreateJsonConfig() async throws {
        await testWorld.resetAll()

        let admin = try UserAccountModel.mock(app: app, isAdmin: true)
        try await app.repositories.users.create(admin)

        let createRequest = RemoteConfig.Create.Request(
            key: "serverSettings",
            value: #"{"host": "localhost", "port": 8080}"#,
            valueType: .json,
            description: nil
        )

        try await app.test(.POST, adminConfigPath, user: admin, content: createRequest, afterResponse: { res in
            #expect(res.status == .ok)
            expectContent(RemoteConfig.Create.Response.self, res) { created in
                #expect(created.key == "serverSettings")
                #expect(created.valueType == .json)
            }
        })
    }

    @Test("Create fails with duplicate key", .tags(.p1Core, .integration))
    func createFailsWithDuplicateKey() async throws {
        await testWorld.resetAll()

        let admin = try UserAccountModel.mock(app: app, isAdmin: true)
        try await app.repositories.users.create(admin)

        // Create initial entry
        let entry = RemoteConfigEntryModel(key: "existingKey", value: "value1", valueType: .string)
        try await app.repositories.remoteConfig.create(entry)

        // Try to create with same key
        let createRequest = RemoteConfig.Create.Request(
            key: "existingKey",
            value: "value2",
            valueType: .string,
            description: nil
        )

        try await app.test(.POST, adminConfigPath, user: admin, content: createRequest, afterResponse: { res in
            #expect(res.status == .conflict)
        })
    }

    @Test("Create fails with invalid boolean value", .tags(.p2Extended, .integration))
    func createFailsWithInvalidBooleanValue() async throws {
        await testWorld.resetAll()

        let admin = try UserAccountModel.mock(app: app, isAdmin: true)
        try await app.repositories.users.create(admin)

        let createRequest = RemoteConfig.Create.Request(
            key: "badBoolean",
            value: "yes", // Invalid - should be "true" or "false"
            valueType: .boolean,
            description: nil
        )

        try await app.test(.POST, adminConfigPath, user: admin, content: createRequest, afterResponse: { res in
            #expect(res.status == .badRequest)
        })
    }

    @Test("Create fails with invalid integer value", .tags(.p2Extended, .integration))
    func createFailsWithInvalidIntegerValue() async throws {
        await testWorld.resetAll()

        let admin = try UserAccountModel.mock(app: app, isAdmin: true)
        try await app.repositories.users.create(admin)

        let createRequest = RemoteConfig.Create.Request(
            key: "badInteger",
            value: "not-a-number",
            valueType: .integer,
            description: nil
        )

        try await app.test(.POST, adminConfigPath, user: admin, content: createRequest, afterResponse: { res in
            #expect(res.status == .badRequest)
        })
    }

    @Test("Create fails with invalid JSON value", .tags(.p2Extended, .integration))
    func createFailsWithInvalidJsonValue() async throws {
        await testWorld.resetAll()

        let admin = try UserAccountModel.mock(app: app, isAdmin: true)
        try await app.repositories.users.create(admin)

        let createRequest = RemoteConfig.Create.Request(
            key: "badJson",
            value: "not-valid-json{",
            valueType: .json,
            description: nil
        )

        try await app.test(.POST, adminConfigPath, user: admin, content: createRequest, afterResponse: { res in
            #expect(res.status == .badRequest)
        })
    }

    // MARK: - Update Tests

    @Test("Admin can update config entry", .tags(.p1Core, .integration))
    func adminCanUpdateConfigEntry() async throws {
        await testWorld.resetAll()

        let admin = try UserAccountModel.mock(app: app, isAdmin: true)
        try await app.repositories.users.create(admin)

        let entry = RemoteConfigEntryModel(key: "updateMe", value: "oldValue", valueType: .string)
        try await app.repositories.remoteConfig.create(entry)

        let updateRequest = RemoteConfig.Update.Request(
            value: "newValue",
            valueType: nil,
            description: "Updated description"
        )

        try await app.test(.PATCH, "\(adminConfigPath)/\(entry.id!)", user: admin, content: updateRequest, afterResponse: { res in
            #expect(res.status == .ok)
            expectContent(RemoteConfig.Update.Response.self, res) { updated in
                #expect(updated.value == "newValue")
                #expect(updated.description == "Updated description")
            }
        })
    }

    @Test("Update fails for non-existent entry", .tags(.p2Extended, .integration))
    func updateFailsForNonExistentEntry() async throws {
        await testWorld.resetAll()

        let admin = try UserAccountModel.mock(app: app, isAdmin: true)
        try await app.repositories.users.create(admin)

        let updateRequest = RemoteConfig.Update.Request(
            value: "value",
            valueType: nil,
            description: nil
        )

        let nonExistentId = UUID()
        try await app.test(.PATCH, "\(adminConfigPath)/\(nonExistentId)", user: admin, content: updateRequest, afterResponse: { res in
            #expect(res.status == .notFound)
        })
    }

    // MARK: - Delete Tests

    @Test("Admin can delete config entry", .tags(.p1Core, .integration))
    func adminCanDeleteConfigEntry() async throws {
        await testWorld.resetAll()

        let admin = try UserAccountModel.mock(app: app, isAdmin: true)
        try await app.repositories.users.create(admin)

        let entry = RemoteConfigEntryModel(key: "deleteMe", value: "value", valueType: .string)
        try await app.repositories.remoteConfig.create(entry)

        try await app.test(.DELETE, "\(adminConfigPath)/\(entry.id!)", user: admin, afterResponse: { res in
            #expect(res.status == .ok)
            expectContent(RemoteConfig.Delete.Response.self, res) { deleted in
                #expect(deleted.message.contains("deleted"))
            }
        })

        // Verify it was deleted
        let count = try await app.repositories.remoteConfig.count()
        #expect(count == 0)
    }

    @Test("Delete fails for non-existent entry", .tags(.p2Extended, .integration))
    func deleteFailsForNonExistentEntry() async throws {
        await testWorld.resetAll()

        let admin = try UserAccountModel.mock(app: app, isAdmin: true)
        try await app.repositories.users.create(admin)

        let nonExistentId = UUID()
        try await app.test(.DELETE, "\(adminConfigPath)/\(nonExistentId)", user: admin, afterResponse: { res in
            #expect(res.status == .notFound)
        })
    }

    @Test("Non-admin cannot delete config entry", .tags(.p0Critical, .integration))
    func nonAdminCannotDeleteConfigEntry() async throws {
        await testWorld.resetAll()

        let user = try UserAccountModel.mock(app: app, isAdmin: false)
        try await app.repositories.users.create(user)

        let entry = RemoteConfigEntryModel(key: "protectedEntry", value: "value", valueType: .string)
        try await app.repositories.remoteConfig.create(entry)

        try await app.test(.DELETE, "\(adminConfigPath)/\(entry.id!)", user: user, afterResponse: { res in
            #expect(res.status == .unauthorized)
        })

        // Verify it was NOT deleted
        let count = try await app.repositories.remoteConfig.count()
        #expect(count == 1)
    }
}
