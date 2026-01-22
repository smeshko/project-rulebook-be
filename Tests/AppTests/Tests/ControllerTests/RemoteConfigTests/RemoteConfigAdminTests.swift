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

    // MARK: - Authentication Tests

    @Test("Admin config endpoints require authentication", .tags(.p0Critical, .auth, .integration))
    func adminEndpointsRequireAuth() async throws {
        await testWorld.resetAll()

        // GET without auth
        try await app.test(.GET, adminConfigPath, afterResponse: { res async throws in
            #expect(res.status == .unauthorized)
        })

        // POST without auth
        let createRequest = RemoteConfig.Create.Request(
            key: "test_key",
            value: "test_value",
            valueType: "string",
            description: nil
        )
        try await app.test(.POST, adminConfigPath, beforeRequest: { req in
            try req.content.encode(createRequest)
        }, afterResponse: { res async throws in
            #expect(res.status == .unauthorized)
        })
    }

    @Test("Admin config endpoints require admin role", .tags(.p0Critical, .auth, .integration))
    func adminEndpointsRequireAdminRole() async throws {
        await testWorld.resetAll()

        // Create a non-admin user
        let nonAdminUser = try await testWorld.dataFactory.createUser(email: "regular@test.com")

        try await app.test(.GET, adminConfigPath, user: nonAdminUser, afterResponse: { res async throws in
            #expect(res.status == .forbidden)
        })
    }

    // MARK: - List Entries Tests

    @Test("List entries returns all config entries for admin", .tags(.p1Core, .integration))
    func listEntriesSuccess() async throws {
        await testWorld.resetAll()

        // Create an admin user
        let adminUser = try await testWorld.dataFactory.createAdminUser()

        // Create test entries
        let entry1 = RemoteConfigEntryModel(key: "key1", value: "value1", valueType: "string")
        let entry2 = RemoteConfigEntryModel(key: "key2", value: "true", valueType: "boolean")
        try await testWorld.remoteConfig.create(entry1)
        try await testWorld.remoteConfig.create(entry2)

        try await app.test(.GET, adminConfigPath, user: adminUser, afterResponse: { res async throws in
            #expect(res.status == .ok)
            expectContent(RemoteConfig.List.Response.self, res) { response in
                #expect(response.count == 2)
                #expect(response.entries.count == 2)
            }
        })
    }

    // MARK: - Create Entry Tests

    @Test("Create entry succeeds with valid data", .tags(.p0Critical, .integration))
    func createEntrySuccess() async throws {
        await testWorld.resetAll()

        let adminUser = try await testWorld.dataFactory.createAdminUser()

        let createRequest = RemoteConfig.Create.Request(
            key: "new_feature",
            value: "true",
            valueType: "boolean",
            description: "A new feature flag"
        )

        try await app.test(.POST, adminConfigPath, user: adminUser, content: createRequest, afterResponse: { res async throws in
            #expect(res.status == .ok)
            expectContent(RemoteConfig.Create.Response.self, res) { response in
                #expect(response.key == "new_feature")
                #expect(response.value == "true")
                #expect(response.valueType == "boolean")
                #expect(response.description == "A new feature flag")
                #expect(response.message == "Config entry created successfully")
            }
        })
    }

    @Test("Create entry fails with duplicate key", .tags(.p1Core, .integration))
    func createEntryDuplicateKey() async throws {
        await testWorld.resetAll()

        let adminUser = try await testWorld.dataFactory.createAdminUser()

        // Create initial entry
        let existingEntry = RemoteConfigEntryModel(key: "existing_key", value: "value", valueType: "string")
        try await testWorld.remoteConfig.create(existingEntry)

        // Try to create with same key
        let createRequest = RemoteConfig.Create.Request(
            key: "existing_key",
            value: "different_value",
            valueType: "string",
            description: nil
        )

        try await app.test(.POST, adminConfigPath, user: adminUser, content: createRequest, afterResponse: { res async throws in
            #expect(res.status == .conflict)
        })
    }

    @Test("Create entry validates boolean value type", .tags(.p1Core, .integration))
    func createEntryValidatesBooleanType() async throws {
        await testWorld.resetAll()

        let adminUser = try await testWorld.dataFactory.createAdminUser()

        // Invalid boolean value
        let createRequest = RemoteConfig.Create.Request(
            key: "bool_key",
            value: "invalid_bool",
            valueType: "boolean",
            description: nil
        )

        try await app.test(.POST, adminConfigPath, user: adminUser, content: createRequest, afterResponse: { res async throws in
            #expect(res.status == .badRequest)
        })
    }

    @Test("Create entry validates integer value type", .tags(.p1Core, .integration))
    func createEntryValidatesIntegerType() async throws {
        await testWorld.resetAll()

        let adminUser = try await testWorld.dataFactory.createAdminUser()

        // Invalid integer value
        let createRequest = RemoteConfig.Create.Request(
            key: "int_key",
            value: "not_an_integer",
            valueType: "integer",
            description: nil
        )

        try await app.test(.POST, adminConfigPath, user: adminUser, content: createRequest, afterResponse: { res async throws in
            #expect(res.status == .badRequest)
        })
    }

    @Test("Create entry validates JSON value type", .tags(.p1Core, .integration))
    func createEntryValidatesJsonType() async throws {
        await testWorld.resetAll()

        let adminUser = try await testWorld.dataFactory.createAdminUser()

        // Invalid JSON value
        let createRequest = RemoteConfig.Create.Request(
            key: "json_key",
            value: "not valid json {",
            valueType: "json",
            description: nil
        )

        try await app.test(.POST, adminConfigPath, user: adminUser, content: createRequest, afterResponse: { res async throws in
            #expect(res.status == .badRequest)
        })
    }

    // MARK: - Update Entry Tests

    @Test("Update entry succeeds with valid data", .tags(.p1Core, .integration))
    func updateEntrySuccess() async throws {
        await testWorld.resetAll()

        let adminUser = try await testWorld.dataFactory.createAdminUser()

        // Create entry to update
        let entry = RemoteConfigEntryModel(key: "update_me", value: "old_value", valueType: "string")
        try await testWorld.remoteConfig.create(entry)

        let updateRequest = RemoteConfig.Update.Request(
            value: "new_value",
            valueType: nil,
            description: "Updated description"
        )

        try await app.test(.PATCH, "\(adminConfigPath)/update_me", user: adminUser, content: updateRequest, afterResponse: { res async throws in
            #expect(res.status == .ok)
            expectContent(RemoteConfig.Update.Response.self, res) { response in
                #expect(response.key == "update_me")
                #expect(response.value == "new_value")
                #expect(response.description == "Updated description")
                #expect(response.message == "Config entry updated successfully")
            }
        })
    }

    @Test("Update entry returns 404 for non-existent key", .tags(.p1Core, .integration))
    func updateEntryNotFound() async throws {
        await testWorld.resetAll()

        let adminUser = try await testWorld.dataFactory.createAdminUser()

        let updateRequest = RemoteConfig.Update.Request(
            value: "new_value",
            valueType: nil,
            description: nil
        )

        try await app.test(.PATCH, "\(adminConfigPath)/non_existent_key", user: adminUser, content: updateRequest, afterResponse: { res async throws in
            #expect(res.status == .notFound)
        })
    }

    // MARK: - Delete Entry Tests

    @Test("Delete entry succeeds", .tags(.p1Core, .integration))
    func deleteEntrySuccess() async throws {
        await testWorld.resetAll()

        let adminUser = try await testWorld.dataFactory.createAdminUser()

        // Create entry to delete
        let entry = RemoteConfigEntryModel(key: "delete_me", value: "value", valueType: "string")
        try await testWorld.remoteConfig.create(entry)

        try await app.test(.DELETE, "\(adminConfigPath)/delete_me", user: adminUser, afterResponse: { res async throws in
            #expect(res.status == .ok)
            expectContent(RemoteConfig.Delete.Response.self, res) { response in
                #expect(response.key == "delete_me")
                #expect(response.message == "Config entry deleted successfully")
            }
        })

        // Verify entry was deleted
        let deletedEntry = try await testWorld.remoteConfig.find(key: "delete_me")
        #expect(deletedEntry == nil)
    }

    @Test("Delete entry returns 404 for non-existent key", .tags(.p1Core, .integration))
    func deleteEntryNotFound() async throws {
        await testWorld.resetAll()

        let adminUser = try await testWorld.dataFactory.createAdminUser()

        try await app.test(.DELETE, "\(adminConfigPath)/non_existent_key", user: adminUser, afterResponse: { res async throws in
            #expect(res.status == .notFound)
        })
    }
}
