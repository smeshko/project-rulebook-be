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
        app = try TestWorld.makeTestAppSync()
        self.testWorld = try TestWorld(app: app)
    }
    
    override func tearDown() {
        app.shutdown()
    }
    
    func testRegisterHappyPath() async throws {
        // TestWorld already configures random generator with "test_random_value"
        // No need to reconfigure - just use the TestWorld configured value
        
        let data = Auth.SignUp.Request(
            email: "test@test.com",
            password: "password123",
            firstName: "Test",
            lastName: "User"
        )
        
        try await app.test(.POST, registerPath, beforeRequest: { req in
            try req.content.encode(data)
        }, afterResponse: { res async throws in
            XCTAssertEqual(res.status, .ok)
            XCTAssertContent(Auth.SignUp.Response.self, res) { signup in
                XCTAssertEqual(signup.user.email, "test@test.com")
                XCTAssertEqual(signup.user.firstName, "Test")
                XCTAssertEqual(signup.user.lastName, "User")
                XCTAssertEqual(signup.user.isAdmin, false)
                XCTAssertEqual(signup.user.isEmailVerified, false)
                
                // Verify tokens are not empty
                XCTAssertFalse(signup.token.refreshToken.isEmpty)
                XCTAssertFalse(signup.token.accessToken.isEmpty)
            }
            
            // Extract signup response to perform async database checks
            let content = try res.content.decode(Auth.SignUp.Response.self)
            
            // Verify user was created in database
            let model = try await app.repositories.users.find(id: content.user.id)
            XCTAssertNotNil(model, "User should exist in database")
            guard let foundModel = model else {
                XCTFail("User not found in database")
                return
            }
            guard let password = foundModel.password else {
                XCTFail("User password is nil")
                return
            }
            XCTAssertTrue(try BCryptDigest().verify("password123", created: password))
            
            // TODO: Restore email token verification when email verification is re-enabled
            // let emailToken = try await app.repositories.emailTokens.find(forUserID: content.user.id)
            // XCTAssertNotNil(emailToken)
            // XCTAssertEqual(emailToken?.$user.id, content.user.id)
        })
    }
    
    func testRegisterFailsWithExistingEmail() async throws {
        try await app.autoMigrate()
        
        do {

        // Use database repositories instead of test repositories
        app.repositories.usersService.use { app in DatabaseUserRepository(database: app.db) }
        app.repositories.refreshTokensService.use { app in DatabaseRefreshTokenRepository(database: app.db) }
        app.repositories.emailTokensService.use { app in DatabaseEmailTokenRepository(database: app.db) }
        app.repositories.passwordTokensService.use { app in DatabasePasswordTokenRepository(database: app.db) }
        
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
        }, afterResponse: { res async throws in
            XCTAssertResponseError(res, AuthenticationError.emailAlreadyExists)
            let users = try await UserAccountModel.query(on: app.db).all()
            XCTAssertEqual(users.count, 1)
        })
        } catch {
            try await app.autoRevert()
            throw error
        }
        
        try await app.autoRevert()
    }
    
    func testRegisterValidations() throws {
        // TestWorld already configures random generator with "test_random_value"

        let data = Auth.SignUp.Request(
            email: "TEStest.com",  // Invalid email
            password: "pass",       // Too short password
            firstName: "Test",
            lastName: "User"
        )

        try app.test(.POST, registerPath, beforeRequest: { req in
            try req.content.encode(data)
        }, afterResponse: { res in
            XCTAssertEqual(res.status, .badRequest)
            XCTAssertContent(ErrorResponse.self, res) { error in
                XCTAssertEqual(error.reason, "email is not a valid email address, password is less than minimum of 8 character(s)")
            }
        })
    }
    
    func testRegisterLowercaseEmail() throws {
        // TestWorld already configures random generator with "test_random_value"

        let data = Auth.SignUp.Request(
            email: "TEST@test.com",
            password: "password123",
            firstName: "Test",
            lastName: "User"
        )

        try app.test(.POST, registerPath, beforeRequest: { req in
            try req.content.encode(data)
        }, afterResponse: { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertContent(Auth.SignUp.Response.self, res) { signup in
                XCTAssertEqual(signup.user.email, "test@test.com")
            }
        })
    }
    
    func testRegisterWithOptionalFields() throws {
        // TestWorld already configures random generator with "test_random_value"

        // Test with no first/last name
        let data = Auth.SignUp.Request(
            email: "test@test.com",
            password: "password123",
            firstName: nil,
            lastName: nil
        )

        try app.test(.POST, registerPath, beforeRequest: { req in
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
    
    func testRegisterWithEmptyOptionalFields() throws {
        // TestWorld already configures random generator with "test_random_value"

        // Test with empty strings (should be converted to nil)
        let data = Auth.SignUp.Request(
            email: "test@test.com",
            password: "password123",
            firstName: "",
            lastName: "  " // whitespace should be treated as empty
        )

        try app.test(.POST, registerPath, beforeRequest: { req in
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