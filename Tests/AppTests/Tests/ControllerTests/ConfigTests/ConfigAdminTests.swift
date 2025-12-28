@testable import App
import Testing
import VaporTesting

@Suite(.serialized)
struct ConfigAdminTests {
    let testWorld: IsolatedTestWorld

    init() async throws {
        testWorld = try await IsolatedTestWorld()
    }

    // MARK: - Authentication Tests

    @Test("PUT /api/v1/admin/config returns 401 without authentication")
    func testAdminEndpointRequiresAuth() async throws {
        try await testWorld.app.test(.PUT, "api/v1/admin/config") { req in
            req.headers.contentType = .json
            try req.content.encode(Config.Update.Request(items: []))
        } afterResponse: { response in
            #expect(response.status == .unauthorized)
        }
    }

    @Test("PUT /api/v1/admin/config returns 403 for non-admin user")
    func testAdminEndpointRequiresAdmin() async throws {
        // Create a regular (non-admin) user
        let user = try UserAccountModel.mock(app: testWorld.app)
        user.isAdmin = false
        try await testWorld.users.create(user)

        try await testWorld.app.test(.PUT, "api/v1/admin/config", user: user, content: Config.Update.Request(items: []), afterResponse: { response in
            #expect(response.status == .forbidden)
        })
    }

    @Test("PUT /api/v1/admin/config returns 200 for admin user")
    func testAdminEndpointSucceedsForAdmin() async throws {
        // Create an admin user
        let adminUser = try UserAccountModel.mock(app: testWorld.app)
        adminUser.isAdmin = true
        try await testWorld.users.create(adminUser)

        try await testWorld.app.test(.PUT, "api/v1/admin/config", user: adminUser, content: Config.Update.Request(items: []), afterResponse: { response in
            #expect(response.status == .ok)
        })
    }

    // MARK: - Update Tests

    @Test("PUT /api/v1/admin/config creates new config values")
    func testAdminCanCreateConfig() async throws {
        // Create an admin user
        let adminUser = try UserAccountModel.mock(app: testWorld.app)
        adminUser.isAdmin = true
        try await testWorld.users.create(adminUser)

        let updateRequest = Config.Update.Request(items: [
            .init(key: "featureFlags.newFeature", value: "true", valueType: .boolean),
            .init(key: "settings.timeout", value: "30", valueType: .integer)
        ])

        try await testWorld.app.test(.PUT, "api/v1/admin/config", user: adminUser, content: updateRequest, afterResponse: { response in
            #expect(response.status == .ok)

            let config = try response.content.decode(Config.Response.self)
            #expect(config.featureFlags["newFeature"] == true)
            #expect(config.settings["timeout"] == .int(30))
        })
    }

    @Test("PUT /api/v1/admin/config updates existing config values")
    func testAdminCanUpdateExistingConfig() async throws {
        // Setup: Create existing config
        let existingConfig = ConfigValueModel(
            key: "settings.maxRetries",
            value: "3",
            valueType: "integer"
        )
        try await testWorld.configs.create(existingConfig)

        // Create an admin user
        let adminUser = try UserAccountModel.mock(app: testWorld.app)
        adminUser.isAdmin = true
        try await testWorld.users.create(adminUser)

        let updateRequest = Config.Update.Request(items: [
            .init(key: "settings.maxRetries", value: "5", valueType: .integer)
        ])

        try await testWorld.app.test(.PUT, "api/v1/admin/config", user: adminUser, content: updateRequest, afterResponse: { response in
            #expect(response.status == .ok)

            let config = try response.content.decode(Config.Response.self)
            #expect(config.settings["maxRetries"] == .int(5))
        })
    }

    @Test("PUT /api/v1/admin/config supports all value types")
    func testAdminCanUpdateAllValueTypes() async throws {
        // Create an admin user
        let adminUser = try UserAccountModel.mock(app: testWorld.app)
        adminUser.isAdmin = true
        try await testWorld.users.create(adminUser)

        let updateRequest = Config.Update.Request(items: [
            .init(key: "featureFlags.enabled", value: "true", valueType: .boolean),
            .init(key: "settings.count", value: "42", valueType: .integer),
            .init(key: "settings.name", value: "test", valueType: .string),
            .init(key: "settings.data", value: "{\"key\":\"value\"}", valueType: .json)
        ])

        try await testWorld.app.test(.PUT, "api/v1/admin/config", user: adminUser, content: updateRequest, afterResponse: { response in
            #expect(response.status == .ok)

            let config = try response.content.decode(Config.Response.self)
            #expect(config.featureFlags["enabled"] == true)
            #expect(config.settings["count"] == .int(42))
            #expect(config.settings["name"] == .string("test"))

            if case .object(let obj) = config.settings["data"] {
                #expect(obj["key"] == .string("value"))
            } else {
                Issue.record("Expected JSON object for data")
            }
        })
    }

    // MARK: - Cache Invalidation Tests

    @Test("PUT /api/v1/admin/config invalidates cache")
    func testAdminUpdateInvalidatesCache() async throws {
        // Setup: Create initial config and populate cache via GET
        let initialConfig = ConfigValueModel(
            key: "settings.value",
            value: "initial",
            valueType: "string"
        )
        try await testWorld.configs.create(initialConfig)

        // First GET to populate cache
        try await testWorld.app.test(.GET, "api/v1/config") { response in
            #expect(response.status == .ok)
            let config = try response.content.decode(Config.Response.self)
            #expect(config.settings["value"] == .string("initial"))
        }

        // Create an admin user
        let adminUser = try UserAccountModel.mock(app: testWorld.app)
        adminUser.isAdmin = true
        try await testWorld.users.create(adminUser)

        // Update config
        let updateRequest = Config.Update.Request(items: [
            .init(key: "settings.value", value: "updated", valueType: .string)
        ])

        try await testWorld.app.test(.PUT, "api/v1/admin/config", user: adminUser, content: updateRequest, afterResponse: { response in
            #expect(response.status == .ok)
        })

        // GET should return updated value (cache invalidated)
        try await testWorld.app.test(.GET, "api/v1/config") { response in
            #expect(response.status == .ok)
            let config = try response.content.decode(Config.Response.self)
            #expect(config.settings["value"] == .string("updated"))
        }
    }
}
