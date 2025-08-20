@testable import App
import Fluent
import XCTVapor
import Crypto
import Testing

@Suite(.serialized)
struct UserGetCurrentUserTests {
    let app: Application
    let testWorld: TestWorld
    let path = "api/user/me"
    
    init() async throws {
        testWorld = try await TestWorld()
        app = testWorld.app
    }
    
    @Test("Get current user returns user details")
    func currentUserHappyPath() async throws {
        let user = try UserAccountModel.mock(app: app)
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
    func currentUserNotLoggedIn() throws {
        try app.test(.GET, path) { response in
            #expect(response.status == .unauthorized)
        }
    }
}