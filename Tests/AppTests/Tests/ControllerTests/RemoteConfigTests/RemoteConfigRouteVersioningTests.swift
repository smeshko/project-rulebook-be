@testable import App
import Fluent
import VaporTesting
import Testing

@Suite(.serialized)
struct RemoteConfigRouteVersioningTests {
    let app: Application
    let testWorld: IsolatedTestWorld

    init() async throws {
        testWorld = try await IsolatedTestWorld()
        app = testWorld.app
    }

    @Test("Versioned GET route accessible with /v1/ prefix")
    func testVersionedGetRoute() async throws {
        await testWorld.resetAll()

        try await app.test(.GET, "api/v1/config") { response in
            #expect(response.status == .ok)
        }
    }

    @Test("Old unversioned GET route returns 404")
    func testOldGetRouteReturns404() async throws {
        await testWorld.resetAll()

        try await app.test(.GET, "api/config") { response in
            #expect(response.status == .notFound)
        }
    }

    @Test("Versioned PATCH admin route accessible with /v1/ prefix")
    func testVersionedAdminRoute() async throws {
        await testWorld.resetAll()

        // Create admin user
        let admin = try UserAccountModel.mock(app: app, email: "admin@test.com", isAdmin: true)
        try await app.repositories.users.create(admin)

        let request = RemoteConfig.UpdateRequest(
            key: "test",
            value: "value",
            type: .string
        )

        try await app.test(.PATCH, "api/v1/admin/config", user: admin) { req in
            try req.content.encode(request)
        } afterResponse: { response in
            #expect(response.status == .ok)
        }
    }

    @Test("Old unversioned PATCH admin route returns 404")
    func testOldAdminRouteReturns404() async throws {
        await testWorld.resetAll()

        // Create admin user
        let admin = try UserAccountModel.mock(app: app, email: "admin@test.com", isAdmin: true)
        try await app.repositories.users.create(admin)

        let request = RemoteConfig.UpdateRequest(
            key: "test",
            value: "value",
            type: .string
        )

        try await app.test(.PATCH, "api/config/admin", user: admin) { req in
            try req.content.encode(request)
        } afterResponse: { response in
            #expect(response.status == .notFound)
        }
    }
}
