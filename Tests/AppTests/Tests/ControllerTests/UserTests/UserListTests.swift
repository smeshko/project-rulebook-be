@testable import App
import Fluent
import XCTVapor
import Testing

@Suite(.serialized)
struct UserListTests {
    let app: Application
    let user: UserAccountModel
    let testWorld: TestWorld
    let listPath = "api/user/list"
    
    init() async throws {
        testWorld = try await TestWorld()
        app = testWorld.app
        user = try UserAccountModel.mock(app: app, isAdmin: true)
    }
    
    @Test("User list returns all users for admin")
    func listHappyPath() async throws {
        try await app.repositories.users.create(user)
        try await app.test(.GET, listPath, user: user) { response in
            expectContent([User.List.Response].self, response) { listResponse in
                #expect(listResponse.count == 1)
            }
        }
    }
    
    @Test("User list fails for non-admin user")
    func listRequestedByNonAdminShouldFail() async throws {
        let nonAdmin = try UserAccountModel.mock(app: app)
        try await app.repositories.users.create(nonAdmin)
        
        try await app.test(.GET, listPath, user: nonAdmin) { response in
            #expect(response.status == .unauthorized)
        }
    }
    
    @Test("User list fails for unauthenticated request")
    func listUnauthenticatedRequestShouldFail() throws {
        try app.test(.GET, listPath) { response in
            #expect(response.status == .unauthorized)
        }
    }
}
