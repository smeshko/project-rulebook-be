@testable import App
import Fluent
import VaporTesting
import Testing

@Suite(.serialized)
struct RemoteConfigAdminTests {
    let app: Application
    let testWorld: IsolatedTestWorld
    let path = "api/v1/admin/config"

    init() async throws {
        testWorld = try await IsolatedTestWorld()
        app = testWorld.app
    }

    @Test("PATCH /api/v1/admin/config requires authentication")
    func testRequiresAuth() async throws {
        await testWorld.resetAll()

        let request = RemoteConfig.UpdateRequest(
            key: "testKey",
            value: "testValue",
            type: .string
        )

        try await app.test(.PATCH, path) { req in
            try req.content.encode(request)
        } afterResponse: { response in
            #expect(response.status == .unauthorized)
        }
    }

    @Test("PATCH /api/v1/admin/config requires admin role")
    func testRequiresAdminRole() async throws {
        await testWorld.resetAll()

        // Create regular user (not admin)
        let user = try UserAccountModel.mock(app: app, email: "user@test.com", isAdmin: false)
        try await app.repositories.users.create(user)

        let request = RemoteConfig.UpdateRequest(
            key: "testKey",
            value: "testValue",
            type: .string
        )

        try await app.test(.PATCH, path, user: user) { req in
            try req.content.encode(request)
        } afterResponse: { response in
            #expect(response.status == .forbidden)
        }
    }

    @Test("PATCH /api/v1/admin/config creates new config")
    func testCreateNewConfig() async throws {
        await testWorld.resetAll()

        // Create admin user
        let admin = try UserAccountModel.mock(app: app, email: "admin@test.com", isAdmin: true)
        try await app.repositories.users.create(admin)

        let request = RemoteConfig.UpdateRequest(
            key: "newFeature",
            value: "true",
            type: .boolean
        )

        try await app.test(.PATCH, path, user: admin) { req in
            try req.content.encode(request)
        } afterResponse: { response in
            #expect(response.status == .ok)

            let updateResponse = try response.content.decode(RemoteConfig.UpdateResponse.self)
            #expect(updateResponse.success == true)
            #expect(updateResponse.key == "newFeature")
        }

        // Verify config was created in database
        let saved = try await RemoteConfigModel.query(on: app.db)
            .filter(\.$key == "newFeature")
            .first()

        #expect(saved != nil)
        #expect(saved?.value == "true")
        #expect(saved?.valueType == .boolean)
    }

    @Test("PATCH /api/v1/admin/config updates existing config")
    func testUpdateExistingConfig() async throws {
        await testWorld.resetAll()

        // Create admin user
        let admin = try UserAccountModel.mock(app: app, email: "admin@test.com", isAdmin: true)
        try await app.repositories.users.create(admin)

        // Seed existing config
        let existing = RemoteConfigModel(
            key: "existingKey",
            value: "oldValue",
            valueType: .string
        )
        try await existing.create(on: app.db)

        let request = RemoteConfig.UpdateRequest(
            key: "existingKey",
            value: "newValue",
            type: .string
        )

        try await app.test(.PATCH, path, user: admin) { req in
            try req.content.encode(request)
        } afterResponse: { response in
            #expect(response.status == .ok)
        }

        // Verify config was updated
        let updated = try await RemoteConfigModel.query(on: app.db)
            .filter(\.$key == "existingKey")
            .first()

        #expect(updated?.value == "newValue")
    }

    @Test("PATCH /api/v1/admin/config invalidates cache")
    func testCacheInvalidation() async throws {
        await testWorld.resetAll()

        // Create admin user
        let admin = try UserAccountModel.mock(app: app, email: "admin@test.com", isAdmin: true)
        try await app.repositories.users.create(admin)

        // Seed test data and populate cache
        let config = RemoteConfigModel(key: "test", value: "old", valueType: .string)
        try await config.create(on: app.db)

        // Populate cache by calling GET endpoint
        try await app.test(.GET, "api/v1/config") { _ in }

        // Verify cache exists
        var cached = try await app.services.cache.get(
            "remote_config:latest",
            as: RemoteConfig.GetResponse.self
        )
        #expect(cached != nil)

        // Update config via admin endpoint
        let request = RemoteConfig.UpdateRequest(
            key: "test",
            value: "new",
            type: .string
        )

        try await app.test(.PATCH, path, user: admin) { req in
            try req.content.encode(request)
        } afterResponse: { _ in }

        // Verify cache was invalidated
        cached = try await app.services.cache.get(
            "remote_config:latest",
            as: RemoteConfig.GetResponse.self
        )
        #expect(cached == nil)
    }

    @Test("PATCH /api/v1/admin/config supports all value types")
    func testAllValueTypes() async throws {
        await testWorld.resetAll()

        // Create admin user
        let admin = try UserAccountModel.mock(app: app, email: "admin@test.com", isAdmin: true)
        try await app.repositories.users.create(admin)

        let testCases = [
            (key: "bool", value: "false", type: ConfigValueType.boolean),
            (key: "int", value: "100", type: ConfigValueType.integer),
            (key: "str", value: "hello", type: ConfigValueType.string),
            (key: "obj", value: "{\"key\":\"value\"}", type: ConfigValueType.json),
        ]

        for testCase in testCases {
            let request = RemoteConfig.UpdateRequest(
                key: testCase.key,
                value: testCase.value,
                type: testCase.type
            )

            try await app.test(.PATCH, path, user: admin) { req in
                try req.content.encode(request)
            } afterResponse: { response in
                #expect(response.status == .ok)
            }

            // Verify in database
            let saved = try await RemoteConfigModel.query(on: app.db)
                .filter(\.$key == testCase.key)
                .first()

            #expect(saved?.value == testCase.value)
            #expect(saved?.valueType == testCase.type)
        }
    }
}
