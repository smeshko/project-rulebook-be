@testable import App
import Fluent
import XCTVapor
import Crypto

extension Auth.SignUp.Request: Content {}

final class AuthSignupTests: XCTestCase {
    var app: Application!
    var testWorld: TestWorld!
    let registerPath = "api/auth/sign-up"
    
    override func setUpWithError() throws {
        app = Application(.testing)
        try configure(app)
        self.testWorld = try TestWorld(app: app)
    }
    
    override func tearDown() {
        app.shutdown()
    }
    
    func testRegisterHappyPath() async throws {
        app.services.randomGenerator.use(.rigged(value: "token"))
        
        let data = Auth.SignUp.Request(
            email: "test@test.com",
            password: "password123",
            firstName: "Test",
            lastName: "User"
        )
        
        try await app.test(.POST, registerPath, beforeRequest: { req in
            try req.content.encode(data)
        }, afterResponse: { res in
            XCTAssertEqual(res.status, .ok)
            try XCTAssertContent(Auth.SignUp.Response.self, res) { signup in
                XCTAssertEqual(signup.user.email, "test@test.com")
                XCTAssertEqual(signup.user.firstName, "Test")
                XCTAssertEqual(signup.user.lastName, "User")
                XCTAssertEqual(signup.user.isAdmin, false)
                XCTAssertEqual(signup.user.isEmailVerified, false)
                
                // Verify user was created in database
                let model = try await app.repositories.users.find(id: signup.user.id)
                XCTAssertNotNil(model)
                XCTAssertTrue(try BCryptDigest().verify("password123", created: model!.password!))
                
                // Verify email token was created
                let emailToken = try await app.repositories.emailTokens.find(token: SHA256.hash("token"))
                XCTAssertEqual(emailToken?.$user.id, signup.user.id)
                XCTAssertNotNil(emailToken)
                
                // Verify tokens are not empty
                XCTAssertFalse(signup.token.refreshToken.isEmpty)
                XCTAssertFalse(signup.token.accessToken.isEmpty)
            }
        })
    }
    
    func testRegisterFailsWithExistingEmail() async throws {
        try await app.autoMigrate()
        defer { try! app.autoRevert().wait() }

        app.repositories.use(.database)
        
        let user = UserAccountModel(
            email: "test@test.com",
            password: "123"
        )

        try await user.create(on: app.db)

        let registerRequest = Auth.SignUp.Request(
            email: "test@test.com",
            password: "password123",
            firstName: "Test",
            lastName: "User"
        )
        
        try await app.test(.POST, registerPath, beforeRequest: { req in
            try req.content.encode(registerRequest)
        }, afterResponse: { res in
            XCTAssertResponseError(res, AuthenticationError.emailAlreadyExists)
            let users = try await UserAccountModel.query(on: app.db).all()
            XCTAssertEqual(users.count, 1)
        })
    }
    
    func testRegisterValidations() async throws {
        app.services.randomGenerator.use(.rigged(value: "token"))

        let data = Auth.SignUp.Request(
            email: "TEStest.com",  // Invalid email
            password: "pass",       // Too short password
            firstName: "Test",
            lastName: "User"
        )

        try await app.test(.POST, registerPath, beforeRequest: { req in
            try req.content.encode(data)
        }, afterResponse: { res in
            XCTAssertEqual(res.status, .badRequest)
            XCTAssertContent(ErrorResponse.self, res) { error in
                XCTAssertEqual(error.reason, "email is not a valid email address, password is less than minimum of 8 character(s)")
            }
        })
    }
    
    func testRegisterLowercaseEmail() async throws {
        app.services.randomGenerator.use(.rigged(value: "token"))

        let data = Auth.SignUp.Request(
            email: "TEST@test.com",
            password: "password123",
            firstName: "Test",
            lastName: "User"
        )

        try await app.test(.POST, registerPath, beforeRequest: { req in
            try req.content.encode(data)
        }, afterResponse: { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertContent(Auth.SignUp.Response.self, res) { signup in
                XCTAssertEqual(signup.user.email, "test@test.com")
            }
        })
    }
    
    func testRegisterWithOptionalFields() async throws {
        app.services.randomGenerator.use(.rigged(value: "token"))

        // Test with no first/last name
        let data = Auth.SignUp.Request(
            email: "test@test.com",
            password: "password123",
            firstName: nil,
            lastName: nil
        )

        try await app.test(.POST, registerPath, beforeRequest: { req in
            try req.content.encode(data)
        }, afterResponse: { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertContent(Auth.SignUp.Response.self, res) { signup in
                XCTAssertEqual(signup.user.email, "test@test.com")
                XCTAssertNil(signup.user.firstName)
                XCTAssertNil(signup.user.lastName)
            }
        })
    }
    
    func testRegisterWithEmptyOptionalFields() async throws {
        app.services.randomGenerator.use(.rigged(value: "token"))

        // Test with empty strings (should be converted to nil)
        let data = Auth.SignUp.Request(
            email: "test@test.com",
            password: "password123",
            firstName: "",
            lastName: "  " // whitespace should be treated as empty
        )

        try await app.test(.POST, registerPath, beforeRequest: { req in
            try req.content.encode(data)
        }, afterResponse: { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertContent(Auth.SignUp.Response.self, res) { signup in
                XCTAssertEqual(signup.user.email, "test@test.com")
                XCTAssertNil(signup.user.firstName) // Empty string should become nil
                XCTAssertNil(signup.user.lastName)  // Whitespace should become nil
            }
        })
    }
}