@testable import App
import Fluent
import VaporTesting
import Crypto
import Testing

@Suite(.serialized)
struct AuthSigninTests {
    let app: Application
    let testWorld: IsolatedTestWorld
    let loginPath = "api/v1/auth/sign-in"
    
    init() async throws {
        testWorld = try await IsolatedTestWorld()
        app = testWorld.app
    }
    
    @Test("User can login with valid credentials", .tags(.p0Critical, .auth, .integration))
    func loginHappyPath() async throws {
        await testWorld.resetAll() // Clean state before test
        let user = try UserAccountModel.mock(app: app)
        
        try await app.repositories.users.create(user)
        let loginRequest = Auth.Login.Request(email: user.email, password: "password")
        
        try await app.test(.POST, loginPath, content: loginRequest, afterResponse: { res in
            #expect(res.status == .ok)
            expectContent(Auth.Login.Response.self, res) { login in
                #expect(login.user.email == user.email)
                #expect(login.user.firstName == "John")
                #expect(login.user.lastName == "Doe")
                #expect(!login.token.refreshToken.isEmpty)
                #expect(!login.token.accessToken.isEmpty)
            }
        })
    }
    
    @Test("Login fails with non-existing user", .tags(.p0Critical, .auth, .integration))
    func loginWithNonExistingUserFails() async throws {
        await testWorld.resetAll() // Clean state before test
        let loginRequest = Auth.Login.Request(email: "none@login.com", password: "123")
        
        try await app.test(.POST, loginPath, content: loginRequest, afterResponse: { res in
            expectResponseError(res, AuthenticationError.invalidEmailOrPassword)
        })
    }
    
    @Test("Login fails with incorrect password", .tags(.p0Critical, .auth, .integration))
    func loginWithIncorrectPasswordFails() async throws {
        await testWorld.resetAll() // Clean state before test
        let user = try UserAccountModel.mock(app: app)

        try await app.repositories.users.create(user)
        
        let loginRequest = Auth.Login.Request(email: user.email, password: "wrongpassword")
        
        try await app.test(.POST, loginPath, content: loginRequest, afterResponse: { res in
            expectResponseError(res, AuthenticationError.invalidEmailOrPassword)
        })
    }
    
    @Test("Login requires email verification", .tags(.p0Critical, .auth, .integration))
    func loginRequiresEmailVerification() async throws {
        await testWorld.resetAll() // Clean state before test
        let user = try UserAccountModel.mock(app: app, isEmailVerified: false)

        try await app.repositories.users.create(user)
        
        let loginRequest = Auth.Login.Request(email: user.email, password: "password")
        
        try await app.test(.POST, loginPath, content: loginRequest, afterResponse: { res in
            expectResponseError(res, AuthenticationError.emailIsNotVerified)
        })
    }
    
    @Test("Login removes old refresh tokens", .tags(.p1Core, .auth, .integration))
    func loginDeletesOldRefreshTokens() async throws {
        await testWorld.resetAll() // Clean state before test
        let user = try UserAccountModel.mock(app: app)

        try await app.repositories.users.create(user)
        
        let loginRequest = Auth.Login.Request(email: user.email, password: "password")
        let token = "test_random_value"  // Use hardcoded value since we're using rigged generator
        
        let refreshToken = try RefreshTokenModel(value: SHA256.hash(token), userID: user.requireID())
        try await app.repositories.refreshTokens.create(refreshToken)
        
        try await app.test(.POST, loginPath, content: loginRequest, afterResponse: { res in
            #expect(res.status == .ok)
            let tokenCount = try await app.repositories.refreshTokens.count()
            #expect(tokenCount == 1)
        })
    }
}
