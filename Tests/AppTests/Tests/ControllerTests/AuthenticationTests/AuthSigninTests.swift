@testable import App
import Fluent
import XCTVapor
import Crypto

final class AuthSigninTests: XCTestCase {
    var app: Application!
    var testWorld: TestWorld!
    let loginPath = "api/auth/sign-in"
    
    override func setUpWithError() throws {
        app = try TestWorld.makeTestAppSync()
        testWorld = try TestWorld(app: app)
    }
    
    override func tearDown() {
        app.shutdown()
    }
    
    func testLoginHappyPath() async throws {
        app.passwords.use(.plaintext)
        
        let user = try UserAccountModel.mock(app: app)
        
        try await app.repositories.users.create(user)
        let loginRequest = Auth.Login.Request(email: "test@test.com", password: "password")
        
        try await app.test(.POST, loginPath, content: loginRequest, afterResponse: { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertContent(Auth.Login.Response.self, res) { login in
                XCTAssertEqual(login.user.email, "test@test.com")
                XCTAssertEqual(login.user.firstName, "John")
                XCTAssertEqual(login.user.lastName, "Doe")
                XCTAssertFalse(login.token.refreshToken.isEmpty)
                XCTAssertFalse(login.token.accessToken.isEmpty)
            }
        })
    }
    
    func testLoginWithNonExistingUserFails() async throws {
        let loginRequest = Auth.Login.Request(email: "none@login.com", password: "123")
        
        try await app.test(.POST, loginPath, content: loginRequest, afterResponse: { res in
            XCTAssertResponseError(res, AuthenticationError.invalidEmailOrPassword)
        })
    }
    
    func testLoginWithIncorrectPasswordFails() async throws {
        app.passwords.use(.plaintext)

        let user = try UserAccountModel.mock(app: app)

        try await app.repositories.users.create(user)
        
        let loginRequest = Auth.Login.Request(email: "test@test.com", password: "wrongpassword")
        
        try await app.test(.POST, loginPath, content: loginRequest, afterResponse: { res in
            XCTAssertResponseError(res, AuthenticationError.invalidEmailOrPassword)
        })
    }
    
    func testLoginRequiresEmailVerification() async throws {
        app.passwords.use(.plaintext)
        
        let user = try UserAccountModel.mock(app: app, isEmailVerified: false)

        try await app.repositories.users.create(user)
        
        let loginRequest = Auth.Login.Request(email: "test@test.com", password: "password")
        
        try await app.test(.POST, loginPath, content: loginRequest, afterResponse: { res in
            XCTAssertResponseError(res, AuthenticationError.emailIsNotVerified)
        })
    }
    
    func testLoginDeletesOldRefreshTokens() async throws {
        app.passwords.use(.plaintext)
        
        let user = try UserAccountModel.mock(app: app)

        try await app.repositories.users.create(user)
        
        let loginRequest = Auth.Login.Request(email: "test@test.com", password: "password")
        let token = "test_random_value"  // Use hardcoded value since we're using rigged generator
        
        let refreshToken = try RefreshTokenModel(value: SHA256.hash(token), userID: user.requireID())
        try await app.repositories.refreshTokens.create(refreshToken)
        
        try await app.test(.POST, loginPath, content: loginRequest, afterResponse: { res in
            XCTAssertEqual(res.status, .ok)
            let tokenCount = try await app.repositories.refreshTokens.count()
            XCTAssertEqual(tokenCount, 1)
        })
    }
}
