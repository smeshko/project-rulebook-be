@testable import App
import Fluent
import VaporTesting
import Crypto
import Testing

extension Auth.SignUp.Request: Content {}

@Suite(.serialized)
struct AuthSignupTests {
    let app: Application
    let testWorld: IsolatedTestWorld
    let registerPath = "api/auth/sign-up"
    
    init() async throws {
        testWorld = try await IsolatedTestWorld()
        app = testWorld.app
    }
    
    @Test("User registration succeeds with valid data") 
    func registerHappyPath() async throws {
        await testWorld.resetAll() // Clean state before test
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
            #expect(res.status == .ok)
            expectContent(Auth.SignUp.Response.self, res) { signup in
                #expect(signup.user.email == "test@test.com")
                #expect(signup.user.firstName == "Test")
                #expect(signup.user.lastName == "User")
                #expect(signup.user.isAdmin == false)
                #expect(signup.user.isEmailVerified == false)
                
                // Verify tokens are not empty
                #expect(!signup.token.refreshToken.isEmpty)
                #expect(!signup.token.accessToken.isEmpty)
            }
            
            // Extract signup response to perform async database checks
            let content = try res.content.decode(Auth.SignUp.Response.self)
            
            // Verify user was created in database
            let model = try await app.repositories.users.find(id: content.user.id)
            #expect(model != nil, "User should exist in database")
            guard let foundModel = model else {
                Issue.record("User not found in database")
                return
            }
            guard let password = foundModel.password else {
                Issue.record("User password is nil")
                return
            }
            // In test environment, passwords are stored as plaintext (configured in TestWorld)
            #expect(password == "password123", "Password should be stored as plaintext in test environment")
            
            // TODO: Restore email token verification when email verification is re-enabled
            // let emailToken = try await app.repositories.emailTokens.find(forUserID: content.user.id)
            // XCTAssertNotNil(emailToken)
            // XCTAssertEqual(emailToken?.$user.id, content.user.id)
        })
    }
    
    @Test("Registration fails when email already exists")
    func registerFailsWithExistingEmail() async throws {
        await testWorld.resetAll() // Clean state before test
        // Create a user first using the test repository
        let existingUser = UserAccountModel(
            email: "test@test.com",
            password: "123"
        )
        try await app.repositories.users.create(existingUser)

        // Try to register with the same email
        let registerRequest = Auth.SignUp.Request(
            email: "test@test.com",
            password: "password123",
            firstName: "Test",
            lastName: "User"
        )
        
        try await app.test(.POST, registerPath, beforeRequest: { req in
            try req.content.encode(registerRequest)
        }, afterResponse: { res async throws in
            expectResponseError(res, AuthenticationError.emailAlreadyExists)
            // Verify only one user exists in the test repository
            let users = try await app.repositories.users.all()
            #expect(users.count == 1)
        })
    }
    
    @Test("Registration validates email and password requirements")
    func registerValidations() async throws {
        await testWorld.resetAll() // Clean state before test
        // TestWorld already configures random generator with "test_random_value"

        let data = Auth.SignUp.Request(
            email: "TEStest.com",  // Invalid email
            password: "pass",       // Too short password
            firstName: "Test",
            lastName: "User"
        )

        try await app.test(.POST, registerPath, beforeRequest: { req in
            try req.content.encode(data)
        }, afterResponse: { res in
            #expect(res.status == .badRequest)
            expectContent(ErrorResponse.self, res) { error in
                #expect(error.reason == "email is not a valid email address, password is less than minimum of 8 character(s)")
            }
        })
    }
    
    @Test("Registration converts email to lowercase")
    func registerLowercaseEmail() async throws {
        await testWorld.resetAll() // Clean state before test
        // TestWorld already configures random generator with "test_random_value"

        let data = Auth.SignUp.Request(
            email: "TEST@test.com",
            password: "password123",
            firstName: "Test",
            lastName: "User"
        )

        try await app.test(.POST, registerPath, beforeRequest: { req in
            try req.content.encode(data)
        }, afterResponse: { res in
            #expect(res.status == .ok)
            expectContent(Auth.SignUp.Response.self, res) { signup in
                #expect(signup.user.email == "test@test.com")
            }
        })
    }
    
    @Test("Registration works with optional fields omitted")
    func registerWithOptionalFields() async throws {
        await testWorld.resetAll() // Clean state before test
        // TestWorld already configures random generator with "test_random_value"

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
            #expect(res.status == .ok)
            expectContent(Auth.SignUp.Response.self, res) { signup in
                #expect(signup.user.email == "test@test.com")
                #expect(signup.user.firstName == nil)
                #expect(signup.user.lastName == nil)
            }
        })
    }
    
    @Test("Registration treats empty strings as nil for optional fields")
    func registerWithEmptyOptionalFields() async throws {
        await testWorld.resetAll() // Clean state before test
        // TestWorld already configures random generator with "test_random_value"

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
            #expect(res.status == .ok)
            expectContent(Auth.SignUp.Response.self, res) { signup in
                #expect(signup.user.email == "test@test.com")
                #expect(signup.user.firstName == nil) // Empty string should become nil
                #expect(signup.user.lastName == nil)  // Whitespace should become nil
            }
        })
    }
}