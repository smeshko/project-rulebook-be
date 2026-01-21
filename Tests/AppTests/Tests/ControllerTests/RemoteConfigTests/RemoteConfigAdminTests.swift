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

    // MARK: - Authorization Tests

    @Test("Admin list endpoint requires authentication", .tags(.p0Critical, .config, .security, .integration))
    func listRequiresAuth() async throws {
        await testWorld.resetAll()

        try await app.test(.GET, adminConfigPath) { response in
            #expect(response.status == .unauthorized)
        }
    }

    @Test("Admin list endpoint requires admin role", .tags(.p0Critical, .config, .security, .integration))
    func listRequiresAdminRole() async throws {
        await testWorld.resetAll()
        let nonAdmin = try UserAccountModel.mock(app: app, isAdmin: false)
        try await app.repositories.users.create(nonAdmin)

        try await app.test(.GET, adminConfigPath, user: nonAdmin) { response in
            #expect(response.status == .unauthorized)
        }
    }

    // MARK: - List Tests

    @Test("Admin can list all config entries", .tags(.p1Core, .config, .integration))
    func listConfigEntries() async throws {
        await testWorld.resetAll()
        let admin = try await testWorld.dataFactory.createAdminUser()
        try await app.repositories.users.create(admin)

        let entry1 = RemoteConfigEntryModel(
            key: "feature_one",
            value: "true",
            valueType: .boolean
        )
        let entry2 = RemoteConfigEntryModel(
            key: "max_items",
            value: "100",
            valueType: .integer
        )
        await testWorld.remoteConfig.add(entry1)
        await testWorld.remoteConfig.add(entry2)

        try await app.test(.GET, adminConfigPath, user: admin) { response in
            #expect(response.status == .ok)
            expectContent(RemoteConfig.List.Response.self, response) { listResponse in
                #expect(listResponse.entries.count == 2)
                #expect(listResponse.total == 2)
            }
        }
    }

    // MARK: - Create Tests

    @Test("Admin can create boolean config entry", .tags(.p1Core, .config, .integration))
    func createBooleanEntry() async throws {
        await testWorld.resetAll()
        let admin = try await testWorld.dataFactory.createAdminUser()
        try await app.repositories.users.create(admin)

        let createRequest = RemoteConfig.Create.Request(
            key: "new_feature",
            value: "true",
            valueType: .boolean,
            description: "A new feature flag"
        )

        try await app.test(.POST, adminConfigPath, user: admin, content: createRequest, afterResponse: { response in
            #expect(response.status == .ok)
            expectContent(RemoteConfig.Create.Response.self, response) { createResponse in
                #expect(createResponse.key == "new_feature")
                #expect(createResponse.value == "true")
                #expect(createResponse.valueType == .boolean)
                #expect(createResponse.description == "A new feature flag")
            }
        })
    }

    @Test("Admin can create integer config entry", .tags(.p1Core, .config, .integration))
    func createIntegerEntry() async throws {
        await testWorld.resetAll()
        let admin = try await testWorld.dataFactory.createAdminUser()
        try await app.repositories.users.create(admin)

        let createRequest = RemoteConfig.Create.Request(
            key: "max_connections",
            value: "50",
            valueType: .integer,
            description: nil
        )

        try await app.test(.POST, adminConfigPath, user: admin, content: createRequest, afterResponse: { response in
            #expect(response.status == .ok)
            expectContent(RemoteConfig.Create.Response.self, response) { createResponse in
                #expect(createResponse.key == "max_connections")
                #expect(createResponse.value == "50")
                #expect(createResponse.valueType == .integer)
            }
        })
    }

    @Test("Admin can create JSON config entry", .tags(.p1Core, .config, .integration))
    func createJSONEntry() async throws {
        await testWorld.resetAll()
        let admin = try await testWorld.dataFactory.createAdminUser()
        try await app.repositories.users.create(admin)

        let createRequest = RemoteConfig.Create.Request(
            key: "app_config",
            value: "{\"theme\":\"dark\"}",
            valueType: .json,
            description: nil
        )

        try await app.test(.POST, adminConfigPath, user: admin, content: createRequest, afterResponse: { response in
            #expect(response.status == .ok)
            expectContent(RemoteConfig.Create.Response.self, response) { createResponse in
                #expect(createResponse.key == "app_config")
                #expect(createResponse.valueType == .json)
            }
        })
    }

    @Test("Create fails with duplicate key", .tags(.p1Core, .config, .integration))
    func createFailsWithDuplicateKey() async throws {
        await testWorld.resetAll()
        let admin = try await testWorld.dataFactory.createAdminUser()
        try await app.repositories.users.create(admin)

        let existing = RemoteConfigEntryModel(
            key: "existing_key",
            value: "true",
            valueType: .boolean
        )
        await testWorld.remoteConfig.add(existing)

        let createRequest = RemoteConfig.Create.Request(
            key: "existing_key",
            value: "false",
            valueType: .boolean,
            description: nil
        )

        try await app.test(.POST, adminConfigPath, user: admin, content: createRequest, afterResponse: { response in
            #expect(response.status == .conflict)
        })
    }

    @Test("Create validates boolean value type", .tags(.p1Core, .config, .integration))
    func createValidatesBooleanValue() async throws {
        await testWorld.resetAll()
        let admin = try await testWorld.dataFactory.createAdminUser()
        try await app.repositories.users.create(admin)

        let createRequest = RemoteConfig.Create.Request(
            key: "bad_bool",
            value: "not_a_boolean",
            valueType: .boolean,
            description: nil
        )

        try await app.test(.POST, adminConfigPath, user: admin, content: createRequest, afterResponse: { response in
            #expect(response.status == .badRequest)
        })
    }

    @Test("Create validates integer value type", .tags(.p1Core, .config, .integration))
    func createValidatesIntegerValue() async throws {
        await testWorld.resetAll()
        let admin = try await testWorld.dataFactory.createAdminUser()
        try await app.repositories.users.create(admin)

        let createRequest = RemoteConfig.Create.Request(
            key: "bad_int",
            value: "not_an_integer",
            valueType: .integer,
            description: nil
        )

        try await app.test(.POST, adminConfigPath, user: admin, content: createRequest, afterResponse: { response in
            #expect(response.status == .badRequest)
        })
    }

    @Test("Create validates JSON value type", .tags(.p1Core, .config, .integration))
    func createValidatesJSONValue() async throws {
        await testWorld.resetAll()
        let admin = try await testWorld.dataFactory.createAdminUser()
        try await app.repositories.users.create(admin)

        let createRequest = RemoteConfig.Create.Request(
            key: "bad_json",
            value: "not valid json {",
            valueType: .json,
            description: nil
        )

        try await app.test(.POST, adminConfigPath, user: admin, content: createRequest, afterResponse: { response in
            #expect(response.status == .badRequest)
        })
    }

    // MARK: - Update Tests

    @Test("Admin can update config entry value", .tags(.p1Core, .config, .integration))
    func updateEntryValue() async throws {
        await testWorld.resetAll()
        let admin = try await testWorld.dataFactory.createAdminUser()
        try await app.repositories.users.create(admin)

        let entry = RemoteConfigEntryModel(
            id: UUID(),
            key: "update_me",
            value: "old_value",
            valueType: .string
        )
        await testWorld.remoteConfig.add(entry)

        let updateRequest = RemoteConfig.Update.Request(
            value: "new_value",
            valueType: nil,
            description: nil
        )

        try await app.test(.PATCH, "\(adminConfigPath)/\(entry.id!)", user: admin, content: updateRequest, afterResponse: { response in
            #expect(response.status == .ok)
            expectContent(RemoteConfig.Update.Response.self, response) { updateResponse in
                #expect(updateResponse.value == "new_value")
            }
        })
    }

    @Test("Admin can update config entry description", .tags(.p2Extended, .config, .integration))
    func updateEntryDescription() async throws {
        await testWorld.resetAll()
        let admin = try await testWorld.dataFactory.createAdminUser()
        try await app.repositories.users.create(admin)

        let entry = RemoteConfigEntryModel(
            id: UUID(),
            key: "desc_entry",
            value: "true",
            valueType: .boolean,
            description: "Old description"
        )
        await testWorld.remoteConfig.add(entry)

        let updateRequest = RemoteConfig.Update.Request(
            value: nil,
            valueType: nil,
            description: "New description"
        )

        try await app.test(.PATCH, "\(adminConfigPath)/\(entry.id!)", user: admin, content: updateRequest, afterResponse: { response in
            #expect(response.status == .ok)
            expectContent(RemoteConfig.Update.Response.self, response) { updateResponse in
                #expect(updateResponse.description == "New description")
            }
        })
    }

    @Test("Update fails for non-existent entry", .tags(.p1Core, .config, .integration))
    func updateFailsForNonExistent() async throws {
        await testWorld.resetAll()
        let admin = try await testWorld.dataFactory.createAdminUser()
        try await app.repositories.users.create(admin)

        let updateRequest = RemoteConfig.Update.Request(
            value: "new_value",
            valueType: nil,
            description: nil
        )

        try await app.test(.PATCH, "\(adminConfigPath)/\(UUID())", user: admin, content: updateRequest, afterResponse: { response in
            #expect(response.status == .notFound)
        })
    }

    // MARK: - Delete Tests

    @Test("Admin can delete config entry", .tags(.p1Core, .config, .integration))
    func deleteEntry() async throws {
        await testWorld.resetAll()
        let admin = try await testWorld.dataFactory.createAdminUser()
        try await app.repositories.users.create(admin)

        let entry = RemoteConfigEntryModel(
            id: UUID(),
            key: "delete_me",
            value: "true",
            valueType: .boolean
        )
        await testWorld.remoteConfig.add(entry)

        try await app.test(.DELETE, "\(adminConfigPath)/\(entry.id!)", user: admin) { response in
            #expect(response.status == .ok)
            expectContent(RemoteConfig.Delete.Response.self, response) { deleteResponse in
                #expect(deleteResponse.message.contains("deleted"))
            }
        }

        // Verify deletion
        let count = try await testWorld.remoteConfig.count()
        #expect(count == 0)
    }

    @Test("Delete fails for non-existent entry", .tags(.p1Core, .config, .integration))
    func deleteFailsForNonExistent() async throws {
        await testWorld.resetAll()
        let admin = try await testWorld.dataFactory.createAdminUser()
        try await app.repositories.users.create(admin)

        try await app.test(.DELETE, "\(adminConfigPath)/\(UUID())", user: admin) { response in
            #expect(response.status == .notFound)
        }
    }

    // MARK: - Get Single Entry Tests

    @Test("Admin can get single config entry", .tags(.p1Core, .config, .integration))
    func getSingleEntry() async throws {
        await testWorld.resetAll()
        let admin = try await testWorld.dataFactory.createAdminUser()
        try await app.repositories.users.create(admin)

        let entry = RemoteConfigEntryModel(
            id: UUID(),
            key: "get_me",
            value: "42",
            valueType: .integer,
            description: "Test entry"
        )
        await testWorld.remoteConfig.add(entry)

        try await app.test(.GET, "\(adminConfigPath)/\(entry.id!)", user: admin) { response in
            #expect(response.status == .ok)
            expectContent(RemoteConfig.Detail.Response.self, response) { detail in
                #expect(detail.key == "get_me")
                #expect(detail.value == "42")
                #expect(detail.valueType == .integer)
                #expect(detail.description == "Test entry")
            }
        }
    }

    @Test("Get single entry fails for non-existent", .tags(.p1Core, .config, .integration))
    func getSingleFailsForNonExistent() async throws {
        await testWorld.resetAll()
        let admin = try await testWorld.dataFactory.createAdminUser()
        try await app.repositories.users.create(admin)

        try await app.test(.GET, "\(adminConfigPath)/\(UUID())", user: admin) { response in
            #expect(response.status == .notFound)
        }
    }
}
