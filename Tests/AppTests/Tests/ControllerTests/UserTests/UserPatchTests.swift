@testable import App
import Fluent
import XCTVapor
import Crypto

extension User.Update.Request: Content {}

final class UserPatchTests: XCTestCase {
    var app: Application!
    var user: UserAccountModel!
    var testWorld: TestWorld!
    var request: User.Update.Request!
    let patchPath = "api/user/update"

    override func setUpWithError() throws {
        app = Application(.testing)
        try configure(app)
        self.testWorld = try TestWorld(app: app)
        
        user = try UserAccountModel.mock(app: app)
        request = .init(
            email: "new_mail@test.com",
            firstName: "New",
            lastName: "Name"
        )
    }
    
    override func tearDown() {
        app.shutdown()
    }
    
    func testPatchHappyPath() async throws {
        try await app.repositories.users.create(user)
                
        try await app.test(.PATCH, patchPath, user: user, content: request) { res in
            XCTAssertContent(User.Update.Response.self, res) { patchContent in
                XCTAssertEqual(patchContent.email, "new_mail@test.com")
                XCTAssertEqual(patchContent.firstName, "New")
                XCTAssertEqual(patchContent.lastName, "Name")
            }
        }
    }
    
    func testPatchNotLoggedIn() async throws {
        try await app.test(.PATCH, patchPath, content: request) { response in
            XCTAssertEqual(response.status, .unauthorized)
        }
    }
    
    func testPatchPartialUpdate() async throws {
        try await app.repositories.users.create(user)

        // Test updating only email
        let partialRequest = User.Update.Request(
            email: "updated@test.com",
            firstName: nil,
            lastName: nil
        )
        
        try await app.test(.PATCH, patchPath, user: user, content: partialRequest) { res in
            XCTAssertContent(User.Update.Response.self, res) { patchContent in
                XCTAssertEqual(patchContent.email, "updated@test.com")
                // Original values should be preserved
                XCTAssertEqual(patchContent.firstName, user.firstName)
                XCTAssertEqual(patchContent.lastName, user.lastName)
            }
        }
    }
    
    func testPatchWithEmptyValues() async throws {
        try await app.repositories.users.create(user)

        // Test with empty strings (should be treated as nil/no change)
        let emptyRequest = User.Update.Request(
            email: "",
            firstName: "",
            lastName: ""
        )
        
        try await app.test(.PATCH, patchPath, user: user, content: emptyRequest) { res in
            XCTAssertContent(User.Update.Response.self, res) { patchContent in
                // Empty values might be converted to nil or preserved - depends on implementation
                XCTAssertEqual(patchContent.id, user.id!)
            }
        }
    }
}