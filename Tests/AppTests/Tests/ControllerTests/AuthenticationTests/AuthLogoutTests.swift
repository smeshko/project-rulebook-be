@testable import App
import VaporTesting
import Testing

@Suite(.serialized)
struct AuthLogoutTests {
    let app: Application
    let testWorld: TestWorld
    let logoutPath = "api/auth/logout"
    let user: UserAccountModel
    
    init() async throws {
        testWorld = try await TestWorld()
        app = testWorld.app
        self.user = try UserAccountModel.mock(app: app)
    }
    
    @Test("User can logout successfully")
    func logoutHappyPath() async throws {
        try await app.repositories.users.create(user)
        
        try await app.test(.POST, logoutPath, user: user) { res in
            #expect(res.status == .ok)
            
            let count = try await app.repositories.refreshTokens.count()
            #expect(count == 0)
        }
    }
    
    @Test("Logout requires authentication")
    func logoutNotLoggedIn() async throws {
        try await app.test(.POST, logoutPath) { response in
            #expect(response.status == .unauthorized)
        }
    }
}
