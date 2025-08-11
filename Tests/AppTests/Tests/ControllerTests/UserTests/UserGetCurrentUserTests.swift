@testable import App
import Fluent
import XCTVapor
import Crypto

final class UserGetCurrentUserTests: XCTestCase {
    var app: Application!
    var testWorld: TestWorld!
    let path = "api/user/me"
    
    override func setUpWithError() throws {
        app = try TestWorld.makeTestAppSync()
        self.testWorld = try TestWorld(app: app)
    }
    
    override func tearDown() {
        app.shutdown()
    }
    
    func testCurrentUserHappyPath() async throws {
        let user = try UserAccountModel.mock(app: app)
        try await app.repositories.users.create(user)
        
        try await app.test(.GET, path, user: user) { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertContent(User.Detail.Response.self, res) { userContent in
                XCTAssertEqual(userContent.email, "test@test.com")
                XCTAssertEqual(userContent.isAdmin, false)
                XCTAssertEqual(userContent.firstName, user.firstName)
                XCTAssertEqual(userContent.lastName, user.lastName)
                XCTAssertEqual(userContent.id, user.id)
            }
        }
    }
    
    func testCurrentUserNotLoggedIn() throws {
        try app.test(.GET, path) { response in
            XCTAssertEqual(response.status, .unauthorized)
        }
    }
}