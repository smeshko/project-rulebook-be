@testable import App
import Fluent
import XCTVapor
import Crypto
import Testing

extension Auth.TokenRefresh.Request: Content {}

@Suite(.serialized)
struct AuthRefreshAccessTokenTests {
    let app: Application
    let testWorld: TestWorld
    let accessTokenPath = "api/auth/refresh"
    let user: UserAccountModel
    
    init() async throws {
        testWorld = try await TestWorld()
        app = testWorld.app
        self.user = UserAccountModel(email: "test@test.com", password: "123")
    }
    
    @Test("Access token can be refreshed with valid refresh token")
    func refreshAccessToken() async throws {
        // TestWorld already configures random generator with "test_random_value"
        // No need to reconfigure - just use the TestWorld configured value
        
        try await app.repositories.users.create(user)
        
        let refreshToken = try RefreshTokenModel(value: SHA256.hash("firstrefreshtoken"), userID: user.requireID())
        
        try await app.repositories.refreshTokens.create(refreshToken)
        let tokenID = try refreshToken.requireID()
        
        let accessTokenRequest = Auth.TokenRefresh.Request(refreshToken: "firstrefreshtoken")
        
        try await app.test(.POST, accessTokenPath, content: accessTokenRequest, afterResponse: { res in
            #expect(res.status == .ok)
            expectContent(Auth.TokenRefresh.Response.self, res) { response in
                #expect(!response.accessToken.isEmpty)
                #expect(!response.refreshToken.isEmpty)
                #expect(response.refreshToken != "firstrefreshtoken") // Should be different from old token
            }
            let deletedToken = try await app.repositories.refreshTokens.find(id: tokenID)
            #expect(deletedToken == nil)
            
            // Verify a new token was created (we don't need to predict the exact value)
            let content = try res.content.decode(Auth.TokenRefresh.Response.self)
            let newToken = try await app.repositories.refreshTokens.find(token: SHA256.hash(content.refreshToken))
            #expect(newToken != nil)
        })
    }
    
    @Test("Token refresh fails with expired refresh token")
    func refreshAccessTokenFailsWithExpiredRefreshToken() async throws {
        try await app.repositories.users.create(user)
        let token = try RefreshTokenModel(value: SHA256.hash("123"), userID: user.requireID(), expiresAt: Date().addingTimeInterval(-60))
        
        try await app.repositories.refreshTokens.create(token)
        
        let accessTokenRequest = Auth.TokenRefresh.Request(refreshToken: "123")

        try await app.test(.POST, accessTokenPath, content: accessTokenRequest, afterResponse: { res in
            expectResponseError(res, AuthenticationError.refreshTokenHasExpired)
        })
    }
    
    @Test("Token refresh fails when user doesn't exist")
    func refreshAccessTokenFailsWhenUserDoesntExist() async throws {
        // Create a user that will be deleted
        let tempUser = UserAccountModel(email: "temp@test.com", password: "123")
        try await app.repositories.users.create(tempUser)
        
        // Create a refresh token for this user
        let token = try RefreshTokenModel(value: SHA256.hash("123"), userID: tempUser.requireID())
        try await app.repositories.refreshTokens.create(token)
        
        // Delete the user to simulate user not found scenario
        try await app.repositories.users.delete(id: tempUser.requireID())
        
        let accessTokenRequest = Auth.TokenRefresh.Request(refreshToken: "123")

        try await app.test(.POST, accessTokenPath, content: accessTokenRequest, afterResponse: { res in
            // When the user doesn't exist but token does, we get userNotFound
            expectResponseError(res, UserError.userNotFound)
        })
    }

}
