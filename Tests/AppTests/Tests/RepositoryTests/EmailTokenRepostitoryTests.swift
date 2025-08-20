@testable import App
import Fluent
import VaporTesting
import Testing

@Suite(.serialized)
struct EmailTokenRepositoryTests {
    let app: Application
    let testWorld: TestWorld
    let repository: any EmailTokenRepository
    let user: UserAccountModel
    
    init() async throws {
        testWorld = try await TestWorld()
        self.app = testWorld.app
        self.repository = DatabaseEmailTokenRepository(database: app.db)
        try await app.autoMigrate()
        
        self.user = .init(email: "test-\(UUID().uuidString.lowercased())@test.com", password: "123")
    }
    
    @Test("Email token can be created")
    func creatingEmailToken() async throws {
        try await user.create(on: app.db)
        let emailToken = EmailTokenModel(userID: try user.requireID(), value: "emailToken")
        try await repository.create(emailToken)
        
        let count = try await EmailTokenModel.query(on: app.db).count()
        #expect(count == 1)
    }
    
    @Test("Email token can be found by token value")
    func findingEmailTokenByToken() async throws {
        try await user.create(on: app.db)
        let emailToken = EmailTokenModel(userID: try user.requireID(), value: "123")
        try await emailToken.create(on: app.db)
        let found = try await repository.find(token: "123")
        #expect(found != nil)
    }
    
    @Test("Email token can be deleted")
    func deleteEmailToken() async throws {
        try await user.create(on: app.db)
        let emailToken = EmailTokenModel(userID: try user.requireID(), value: "123")
        try await emailToken.create(on: app.db)
        try await repository.delete(id: emailToken.requireID())
        let count = try await EmailTokenModel.query(on: app.db).count()
        #expect(count == 0)
    }
}
