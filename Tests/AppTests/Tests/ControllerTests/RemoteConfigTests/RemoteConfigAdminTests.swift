@testable import App
import VaporTesting
import Testing
import Fluent

@Suite(.serialized)
struct RemoteConfigAdminTests {
    let app: Application
    let testWorld: IsolatedTestWorld

    init() async throws {
        testWorld = try await IsolatedTestWorld()
        app = testWorld.app
    }

    @Test("POST /api/v1/config/admin requires authentication")
    func createConfigRequiresAuth() async throws {
        await testWorld.resetAll()

        let request = RemoteConfig.CreateConfigRequest(
            key: "feature_test",
            valueType: ConfigValueType.boolean,
            value: AnyCodable(true)
        )

        try await app.test(.POST, "api/v1/config/admin", content: request, afterResponse: { response async in
            #expect(response.status == .unauthorized)
        })
    }

    @Test("GET /api/v1/config/admin requires authentication")
    func listConfigRequiresAuth() async throws {
        await testWorld.resetAll()

        try await app.test(.GET, "api/v1/config/admin", afterResponse: { response async in
            #expect(response.status == .unauthorized)
        })
    }

    @Test("DELETE /api/v1/config/admin/:key requires authentication")
    func deleteConfigRequiresAuth() async throws {
        await testWorld.resetAll()

        try await app.test(.DELETE, "api/v1/config/admin/test_key", afterResponse: { response async in
            #expect(response.status == .unauthorized)
        })
    }
}
