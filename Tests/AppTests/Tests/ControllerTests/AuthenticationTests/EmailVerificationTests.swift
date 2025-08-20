
@testable import App
import Fluent
import XCTVapor
import Crypto
import Testing

@Suite(.serialized)
struct EmailVerificationTests {
    let app: Application
    let testWorld: TestWorld
    let verifyURL = "verify-email"
    
    init() async throws {
        testWorld = try await TestWorld()
        app = testWorld.app
    }
    
    @Test("Email verification succeeds with valid token")
    func verifyingEmailHappyPath() async throws {
        let user = UserAccountModel(email: "test@test.com", password: "123")
        try await app.repositories.users.create(user)
        let expectedHash = SHA256.hash("token123")
        
        let emailToken = EmailTokenModel(userID: try user.requireID(), value: expectedHash)
        emailToken.$user.value = user
        try await app.repositories.emailTokens.create(emailToken)
        
        try await app.test(.GET, verifyURL, beforeRequest: { req in
            try req.query.encode(["token": expectedHash])
        }, afterResponse: { res in
            #expect(res.status == .ok)
            let foundUser = try await app.repositories.users.find(id: user.id!)
            guard let foundUser = foundUser else {
                Issue.record("User not found after email verification")
                return
            }
            #expect(foundUser.isEmailVerified == true)
            let token = try await app.repositories.emailTokens.find(forUserID: user.requireID())
            #expect(token == nil)
        })
    }
    
    @Test("Email verification fails with invalid token")
    func verifyingEmailWithInvalidTokenFails() throws {
        try app.test(.GET, verifyURL, beforeRequest: { req in
            try req.query.encode(["token": "blabla"])
        }, afterResponse: { res in
            guard let html = String(data: Data(buffer: res.body), encoding: .utf8) else {
                Issue.record("Failed to decode response body as UTF-8 string")
                return
            }
            #expect(html.contains("Token not found"))
        })
    }
    
    @Test("Email verification fails with expired token")
    func verifyingEmailWithExpiredTokenFails() async throws {
        let user = UserAccountModel(email: "test@test.com", password: "123")
        try await app.repositories.users.create(user)
        let expectedHash = SHA256.hash("token123")
        let emailToken = EmailTokenModel(userID: try user.requireID(), value: expectedHash, expiresAt: Date().addingTimeInterval(-15 * 60 - 1) ) // -15 minutes - 1 second
        emailToken.$user.value = user

        try await app.repositories.emailTokens.create(emailToken)
        
        try await app.test(.GET, verifyURL, beforeRequest: { req in
            try req.query.encode(["token": expectedHash])
        }, afterResponse: { res in
            guard let html = String(data: Data(buffer: res.body), encoding: .utf8) else {
                Issue.record("Failed to decode response body as UTF-8 string")
                return
            }
            #expect(html.contains("Token expired"))
            // Verify token was deleted after the expired check
            let remainingToken = try await app.repositories.emailTokens.find(forUserID: user.requireID())
            #expect(remainingToken == nil)
        })
    }
}
