@testable import App
import Fluent
import VaporTesting
import Testing

@Suite(.serialized)
struct UserDeleteTests {
    let app: Application
    let user: UserAccountModel
    let testWorld: IsolatedTestWorld
    let deletePath = "api/v1/user/delete"
    
    init() async throws {
        testWorld = try await IsolatedTestWorld()
        app = testWorld.app
        user = try UserAccountModel.mock(app: app)
    }
    
    @Test("User delete removes user successfully", .tags(.p0Critical, .users, .integration))
    func deleteHappyPath() async throws {
        await testWorld.resetAll() // Clean state before test
        try await app.repositories.users.create(user)
        try await app.test(.DELETE, deletePath, user: user) { response in
            let users = try await app.repositories.users.all()
            #expect(response.status == .ok)
            #expect(users.count == 0)
        }
    }
    
    @Test("User delete fails when not authenticated", .tags(.p0Critical, .users, .security, .integration))
    func deleteUnauthenticatedRequestShouldFail() async throws {
        await testWorld.resetAll() // Clean state before test
        try await app.test(.DELETE, deletePath) { response in
            #expect(response.status == .unauthorized)
        }
    }
}
