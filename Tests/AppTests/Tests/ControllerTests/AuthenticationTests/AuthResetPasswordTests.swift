@testable import App
import Fluent
import VaporTesting
import Crypto
import Testing

extension Auth.PasswordReset.Request: Content {}
extension PasswordResetInput: Content {}

@Suite(.serialized)
struct AuthResetPasswordTests {
    let app: Application
    let testWorld: IsolatedTestWorld
    let path = "api/v1/auth/reset-password"
    
    init() async throws {
        testWorld = try await IsolatedTestWorld()
        app = testWorld.app
    }
    
    @Test("Password reset creates token for valid user")
    func resetPassword() async throws {
        await testWorld.resetAll() // Clean state before test
        let user = UserAccountModel(email: "test-\(UUID().uuidString.lowercased())@test.com", password: "123")
        try await app.repositories.users.create(user)
        
        let resetPasswordRequest = Auth.PasswordReset.Request(email: user.email)
        
        try await app.test(.POST, path, beforeRequest: { req in
            try req.content.encode(resetPasswordRequest)
        }, afterResponse: { res in
            #expect(res.status == .ok)
            let count = try await app.repositories.passwordTokens.count()
            #expect(count == 1)
        })
    }
    
    @Test("Password reset fails with non-existing email")
    func resetPasswordFailsWithNonExistingEmail() async throws {
        await testWorld.resetAll() // Clean state before test
        let resetPasswordRequest = Auth.PasswordReset.Request(email: "none@test.com")
        
        try await app.test(.POST, path, content: resetPasswordRequest, afterResponse: { res in
            expectResponseError(res, UserError.userNotFound)
        })
    }

    @Test("Account can be recovered with valid token")
    func recoverAccount() async throws {
        await testWorld.resetAll() // Clean state before test
        let user = UserAccountModel(email: "test-\(UUID().uuidString.lowercased())@test.com", password: "oldpassword")
        try await app.repositories.users.create(user)
        let plainToken = "passwordtoken"
        let hashedToken = SHA256.hash(plainToken)
        let tokenModel = try PasswordTokenModel(userID: user.requireID(), value: hashedToken)
        tokenModel.$user.value = user
        
        try await app.repositories.passwordTokens.create(tokenModel)
        
        let recoverRequest = PasswordResetInput(password: "newpassword", confirmPassword: "newpassword")
        
        try await app.test(.POST, "reset-password?token=\(plainToken)", content: recoverRequest, afterResponse: { res in
            #expect(res.status == .ok)
            let foundUser = try await app.repositories.users.find(id: user.requireID())
            guard let foundUser else {
                Issue.record("User not found after password reset")
                return
            }
            // In test environment with plaintext hasher, password should be stored as plaintext
            #expect(foundUser.password == "newpassword")
            let count = try await app.repositories.passwordTokens.count()
            #expect(count == 0)
        })
    }

    @Test("Account recovery fails with expired token")
    func recoverAccountWithExpiredTokenFails() async throws {
        await testWorld.resetAll() // Clean state before test
        let plainToken = "passwordtoken"
        let hashedToken = SHA256.hash(plainToken)
        let token = PasswordTokenModel(userID: UUID(), value: hashedToken, expiresAt: Date().addingTimeInterval(-60))
        try await app.repositories.passwordTokens.create(token)
        
        try await app.test(.GET, "reset-password", beforeRequest: { req in
            try req.query.encode(["token": plainToken])
        }, afterResponse: { res in
            guard let html = String(data: Data(buffer: res.body), encoding: .utf8) else {
                Issue.record("Failed to decode response body as UTF-8 string")
                return
            }
            #expect(html.contains("Token expired"))
            // Verify token still exists since it was expired (not deleted)
            let remainingToken = try await app.repositories.passwordTokens.find(token: plainToken)
            #expect(remainingToken != nil)
        })
    }
    
    @Test("Account recovery fails with invalid token")
    func recoverAccountWithInvalidTokenFails() async throws {
        await testWorld.resetAll() // Clean state before test
        try await app.test(.GET, "reset-password?token=blah", afterResponse: { res in
            guard let html = String(data: Data(buffer: res.body), encoding: .utf8) else {
                Issue.record("Failed to decode response body as UTF-8 string")
                return
            }
            #expect(html.contains("Token not found"))
        })
    }
}
