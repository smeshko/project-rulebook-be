@testable import App
import Fluent
import VaporTesting
import Testing

@Suite(.serialized)
struct UserListTests {
    let app: Application
    let user: UserAccountModel
    let testWorld: IsolatedTestWorld
    let listPath = "api/v1/user/list"
    
    init() async throws {
        testWorld = try await IsolatedTestWorld()
        app = testWorld.app
        user = try await testWorld.dataFactory.createAdminUser()
    }
    
    @Test("User list returns all users for admin", .tags(.p1Core, .users, .integration))
    func listHappyPath() async throws {
        await testWorld.resetAll() // Clean state before test
        try await app.repositories.users.create(user)
        try await app.test(.GET, listPath, user: user) { response in
            expectContent([User.List.Response].self, response) { listResponse in
                #expect(listResponse.count == 1)
            }
        }
    }
    
    @Test("User list fails for non-admin user", .tags(.p0Critical, .users, .security, .integration))
    func listRequestedByNonAdminShouldFail() async throws {
        await testWorld.resetAll() // Clean state before test
        let nonAdmin = try UserAccountModel.mock(app: app)
        try await app.repositories.users.create(nonAdmin)
        
        try await app.test(.GET, listPath, user: nonAdmin) { response in
            #expect(response.status == .unauthorized)
        }
    }
    
    @Test("User list fails for unauthenticated request", .tags(.p0Critical, .users, .security, .integration))
    func listUnauthenticatedRequestShouldFail() async throws {
        await testWorld.resetAll() // Clean state before test
        try await app.test(.GET, listPath) { response in
            #expect(response.status == .unauthorized)
        }
    }
}
