@testable import App
import Fluent
import VaporTesting
import Crypto
import Testing

@Suite(.serialized)
struct UserGetCurrentUserTests {
    let app: Application
    let testWorld: IsolatedTestWorld
    let path = "api/v1/user/me"
    
    init() async throws {
        testWorld = try await IsolatedTestWorld()
        app = testWorld.app
    }
    
    @Test("Get current user returns user details")
    func currentUserHappyPath() async throws {
        await testWorld.resetAll() // Clean state before test
        let user = try UserAccountModel.mock(app: app, email: "test@test.com")
        try await app.repositories.users.create(user)
        
        try await app.test(.GET, path, user: user) { res in
            #expect(res.status == .ok)
            expectContent(User.Detail.Response.self, res) { userContent in
                #expect(userContent.email == "test@test.com")
                #expect(userContent.isAdmin == false)
                #expect(userContent.firstName == user.firstName)
                #expect(userContent.lastName == user.lastName)
                #expect(userContent.id == user.id)
            }
        }
    }
    
    @Test("Get current user fails when not logged in")
    func currentUserNotLoggedIn() async throws {
        await testWorld.resetAll() // Clean state before test
        try await app.test(.GET, path) { response in
            #expect(response.status == .unauthorized)
        }
    }
}