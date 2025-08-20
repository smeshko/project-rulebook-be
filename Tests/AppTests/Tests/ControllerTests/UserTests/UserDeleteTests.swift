@testable import App
import Fluent
import XCTVapor
import Testing

struct UserDeleteTests {
    let app: Application
    let user: UserAccountModel
    let testWorld: TestWorld
    let deletePath = "api/user/delete"
    
    init() async throws {
        app = try await withApp { app in return app }
        testWorld = try TestWorld(app: app)
        user = try UserAccountModel.mock(app: app)
    }
    
    @Test("User delete removes user successfully")
    func deleteHappyPath() async throws {
        try await app.repositories.users.create(user)
        try await app.test(.DELETE, deletePath, user: user) { response in
            let users = try await app.repositories.users.all()
            #expect(response.status == .ok)
            #expect(users.count == 0)
        }
    }
    
    @Test("User delete fails when not authenticated")
    func deleteUnauthenticatedRequestShouldFail() throws {
        try app.test(.DELETE, deletePath) { response in
            #expect(response.status == .unauthorized)
        }
    }
}
