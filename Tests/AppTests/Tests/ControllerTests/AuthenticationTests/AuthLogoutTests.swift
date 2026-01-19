@testable import App
import VaporTesting
import Testing
import Crypto

@Suite(.serialized)
struct AuthLogoutTests {
    let app: Application
    let testWorld: IsolatedTestWorld
    let logoutPath = "api/v1/auth/logout"
    let user: UserAccountModel
    
    init() async throws {
        testWorld = try await IsolatedTestWorld()
        app = testWorld.app
        self.user = try UserAccountModel.mock(app: app)
    }
    
    @Test("User can logout successfully", .tags(.p0Critical, .auth, .integration))
    func logoutHappyPath() async throws {
        await testWorld.resetAll() // Clean state before test
        try await app.repositories.users.create(user)
        
        // Create a refresh token for the user so logout has something to delete
        let refreshToken = try RefreshTokenModel(value: SHA256.hash("test_token"), userID: user.requireID())
        try await app.repositories.refreshTokens.create(refreshToken)
        
        try await app.test(.POST, logoutPath, user: user) { res in
            #expect(res.status == .ok)
            
            let count = try await app.repositories.refreshTokens.count()
            #expect(count == 0)
        }
    }
    
    @Test("Logout requires authentication", .tags(.p0Critical, .auth, .integration))
    func logoutNotLoggedIn() async throws {
        await testWorld.resetAll() // Clean state before test
        try await app.test(.POST, logoutPath) { response in
            #expect(response.status == .unauthorized)
        }
    }
}
