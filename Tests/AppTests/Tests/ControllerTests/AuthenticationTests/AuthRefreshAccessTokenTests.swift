@testable import App
import Fluent
import XCTVapor
import Crypto

extension Auth.TokenRefresh.Request: Content {}

final class AuthRefreshAccessTokenTests: XCTestCase {
    var app: Application!
    var testWorld: TestWorld!
    let accessTokenPath = "api/auth/refresh"
    var user: UserAccountModel!
    
    override func setUpWithError() throws {
        app = try TestWorld.makeTestAppSync()
        self.testWorld = try TestWorld(app: app)
        
        user = UserAccountModel(email: "test@test.com", password: "123")
    }
    
    override func tearDown() {
        app.shutdown()
    }
    
    func testRefreshAccessToken() async throws {
        // TestWorld already configures random generator with "test_random_value"
        // No need to reconfigure - just use the TestWorld configured value
        
        try await app.repositories.users.create(user)
        
        let refreshToken = try RefreshTokenModel(value: SHA256.hash("firstrefreshtoken"), userID: user.requireID())
        
        try await app.repositories.refreshTokens.create(refreshToken)
        let tokenID = try refreshToken.requireID()
        
        let accessTokenRequest = Auth.TokenRefresh.Request(refreshToken: "firstrefreshtoken")
        
        try await app.test(.POST, accessTokenPath, content: accessTokenRequest) { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertContent(Auth.TokenRefresh.Response.self, res) { response in
                XCTAssertFalse(response.accessToken.isEmpty)
                XCTAssertFalse(response.refreshToken.isEmpty)
                XCTAssertNotEqual(response.refreshToken, "firstrefreshtoken") // Should be different from old token
            }
            let deletedToken = try await app.repositories.refreshTokens.find(id: tokenID)
            XCTAssertNil(deletedToken)
            
            // Verify a new token was created (we don't need to predict the exact value)
            let content = try res.content.decode(Auth.TokenRefresh.Response.self)
            let newToken = try await app.repositories.refreshTokens.find(token: SHA256.hash(content.refreshToken))
            XCTAssertNotNil(newToken)
        }
    }
    
    func testRefreshAccessTokenFailsWithExpiredRefreshToken() async throws {
        try await app.repositories.users.create(user)
        let token = try RefreshTokenModel(value: SHA256.hash("123"), userID: user.requireID(), expiresAt: Date().addingTimeInterval(-60))
        
        try await app.repositories.refreshTokens.create(token)
        
        let accessTokenRequest = Auth.TokenRefresh.Request(refreshToken: "123")

        try await app.test(.POST, accessTokenPath, content: accessTokenRequest, afterResponse: { res in
            XCTAssertResponseError(res, AuthenticationError.refreshTokenHasExpired)
        })
    }
    
    func testRefreshAccessTokenFailsWhenUserDoesntExist() async throws {
        let token = RefreshTokenModel(value: SHA256.hash("123"), userID: UUID())
        try await app.repositories.refreshTokens.create(token)
        
        let accessTokenRequest = Auth.TokenRefresh.Request(refreshToken: "123")

        try await app.test(.POST, accessTokenPath, content: accessTokenRequest, afterResponse: { res in
            XCTAssertResponseError(res, UserError.userNotFound)
        })
    }

}
