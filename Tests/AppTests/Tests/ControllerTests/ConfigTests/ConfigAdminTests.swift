@testable import App
import VaporTesting
import Testing

@Suite(.serialized)
struct ConfigAdminTests {
    let app: Application
    let testWorld: IsolatedTestWorld
    let adminConfigPath = "api/v1/admin/config"

    init() async throws {
        testWorld = try await IsolatedTestWorld()
        app = testWorld.app
    }

    // MARK: - Authentication Tests

    @Test("PATCH /api/v1/admin/config requires authentication")
    func patchConfigRequiresAuth() async throws {
        await testWorld.resetAll()

        let updateRequest = Config.Update.Request(entries: [
            .init(key: "featureFlags.test", value: ConfigValue(bool: true), valueType: "boolean")
        ])

        try await app.test(.PATCH, adminConfigPath, content: updateRequest, afterResponse: { res in
            #expect(res.status == .unauthorized)
        })
    }

    @Test("PATCH /api/v1/admin/config requires admin role")
    func patchConfigRequiresAdmin() async throws {
        await testWorld.resetAll()

        // Create a regular (non-admin) user
        let user = try UserAccountModel.mock(app: app, isAdmin: false)
        try await testWorld.users.create(user)

        let updateRequest = Config.Update.Request(entries: [
            .init(key: "featureFlags.test", value: ConfigValue(bool: true), valueType: "boolean")
        ])

        try await app.test(
            .PATCH,
            adminConfigPath,
            user: user,
            content: updateRequest,
            afterResponse: { res in
                #expect(res.status == .forbidden)
            }
        )
    }

    @Test("PATCH /api/v1/admin/config succeeds for admin user")
    func patchConfigSucceedsForAdmin() async throws {
        await testWorld.resetAll()

        // Create an admin user
        let admin = try UserAccountModel.mock(app: app, email: "admin@test.com", isAdmin: true)
        try await testWorld.users.create(admin)

        let updateRequest = Config.Update.Request(entries: [
            .init(key: "featureFlags.newFeature", value: ConfigValue(bool: true), valueType: "boolean")
        ])

        try await app.test(
            .PATCH,
            adminConfigPath,
            user: admin,
            content: updateRequest,
            afterResponse: { res in
                #expect(res.status == .ok)
                expectContent(Config.Update.Response.self, res) { response in
                    #expect(response.updated.contains("featureFlags.newFeature"))
                    #expect(response.message.contains("successfully"))
                }
            }
        )
    }

    // MARK: - Update Functionality Tests

    @Test("PATCH creates new config entries")
    func patchCreatesNewEntries() async throws {
        await testWorld.resetAll()

        let admin = try UserAccountModel.mock(app: app, email: "admin@test.com", isAdmin: true)
        try await testWorld.users.create(admin)

        let updateRequest = Config.Update.Request(entries: [
            .init(key: "featureFlags.brand_new", value: ConfigValue(bool: true), valueType: "boolean"),
            .init(key: "settings.timeout", value: ConfigValue(int: 30), valueType: "integer")
        ])

        try await app.test(
            .PATCH,
            adminConfigPath,
            user: admin,
            content: updateRequest,
            afterResponse: { res in
                #expect(res.status == .ok)
            }
        )

        // Verify entries were created
        let createdFlag = try await testWorld.configs.find(key: "featureFlags.brand_new")
        let createdSetting = try await testWorld.configs.find(key: "settings.timeout")

        #expect(createdFlag != nil)
        #expect(createdSetting != nil)
        #expect(createdFlag?.value.boolValue == true)
        #expect(createdSetting?.value.intValue == 30)
    }

    @Test("PATCH updates existing config entries")
    func patchUpdatesExistingEntries() async throws {
        await testWorld.resetAll()

        // Create existing entry
        let existing = ConfigEntryModel(
            key: "featureFlags.existing",
            value: ConfigValue(bool: false),
            valueType: "boolean"
        )
        try await testWorld.configs.create(existing)

        let admin = try UserAccountModel.mock(app: app, email: "admin@test.com", isAdmin: true)
        try await testWorld.users.create(admin)

        // Update the existing entry
        let updateRequest = Config.Update.Request(entries: [
            .init(key: "featureFlags.existing", value: ConfigValue(bool: true), valueType: "boolean")
        ])

        try await app.test(
            .PATCH,
            adminConfigPath,
            user: admin,
            content: updateRequest,
            afterResponse: { res in
                #expect(res.status == .ok)
            }
        )

        // Verify entry was updated
        let updated = try await testWorld.configs.find(key: "featureFlags.existing")
        #expect(updated?.value.boolValue == true)
    }
}
