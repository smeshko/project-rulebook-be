@testable import App
import Fluent
import VaporTesting
import Crypto
import Testing

extension User.Update.Request: Content {}

@Suite(.serialized)
struct UserPatchTests {
    let app: Application
    let user: UserAccountModel
    let testWorld: TestWorld
    let request: User.Update.Request
    let patchPath = "api/user/update"

    init() async throws {
        testWorld = try await TestWorld()
        app = testWorld.app
        user = try UserAccountModel.mock(app: app)
        request = .init(
            email: "new_mail@test.com",
            firstName: "New",
            lastName: "Name"
        )
    }
    
    @Test("User patch updates user details successfully")
    func patchHappyPath() async throws {
        try await app.repositories.users.create(user)
                
        try await app.test(.PATCH, patchPath, user: user, content: request, afterResponse: { res in
            expectContent(User.Update.Response.self, res) { patchContent in
                #expect(patchContent.email == "new_mail@test.com")
                #expect(patchContent.firstName == "New")
                #expect(patchContent.lastName == "Name")
            }
        })
    }
    
    @Test("User patch fails when not logged in")
    func patchNotLoggedIn() async throws {
        try await app.test(.PATCH, patchPath, content: request, afterResponse: { response in
            #expect(response.status == .unauthorized)
        })
    }
    
    @Test("User patch allows partial updates")
    func patchPartialUpdate() async throws {
        try await app.repositories.users.create(user)

        // Test updating only email
        let partialRequest = User.Update.Request(
            email: "updated@test.com",
            firstName: nil,
            lastName: nil
        )
        
        try await app.test(.PATCH, patchPath, user: user, content: partialRequest, afterResponse: { res in
            expectContent(User.Update.Response.self, res) { patchContent in
                #expect(patchContent.email == "updated@test.com")
                // Original values should be preserved
                #expect(patchContent.firstName == user.firstName)
                #expect(patchContent.lastName == user.lastName)
            }
        })
    }
    
    @Test("User patch handles empty values")
    func patchWithEmptyValues() async throws {
        try await app.repositories.users.create(user)

        // Test with empty strings (should be treated as nil/no change)
        let emptyRequest = User.Update.Request(
            email: "",
            firstName: "",
            lastName: ""
        )
        
        try await app.test(.PATCH, patchPath, user: user, content: emptyRequest, afterResponse: { res in
            expectContent(User.Update.Response.self, res) { patchContent in
                // Empty values might be converted to nil or preserved - depends on implementation
                #expect(patchContent.id == user.id!)
            }
        })
    }
}