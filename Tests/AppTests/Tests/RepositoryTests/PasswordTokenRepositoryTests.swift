@testable import App
import Fluent
import VaporTesting
import Testing

@Suite(.serialized)
struct PasswordTokenRepositoryTests {
    let app: Application
    let testWorld: TestWorld
    let repository: any PasswordTokenRepository
    let user: UserAccountModel
    
    init() async throws {
        testWorld = try await TestWorld()
        self.app = testWorld.app
        self.repository = DatabasePasswordTokenRepository(database: app.db)
        try await app.autoMigrate()
        
        self.user = .init(email: "test-\(UUID().uuidString.lowercased())@test.com", password: "123")
        try await user.create(on: app.db)
    }
    
    @Test("Password token can be found by user ID")
    func findByUserID() async throws {
        let userID = try user.requireID()
        let token = PasswordTokenModel(userID: userID, value: "123")
        try await token.create(on: app.db)
        
        let foundToken = try await repository.find(forUserID: userID)
        #expect(foundToken != nil)
    }
    
    @Test("Password token can be found by token value")
    func findByToken() async throws {
        let token = PasswordTokenModel(userID: try user.requireID(), value: "token123")
        try await token.create(on: app.db)
        let foundToken = try await repository.find(token: "token123")
        #expect(foundToken != nil)
    }
    
    @Test("Repository can count password tokens")
    func count() async throws {
        let token = PasswordTokenModel(userID: try user.requireID(), value: "token123")
        let token2 = PasswordTokenModel(userID: try user.requireID(), value: "token1234")
        try await [token, token2].create(on: app.db)
        let count = try await repository.count()
        #expect(count == 2)
    }
    
    @Test("Password token can be created")
    func create() async throws {
        let token = PasswordTokenModel(userID: try user.requireID(), value: "token123")
        try await repository.create(token)
        let foundToken = try await PasswordTokenModel.find(try token.requireID(), on: app.db)
        #expect(foundToken != nil)
    }
    
    @Test("Password token can be deleted")
    func delete() async throws {
        let token = PasswordTokenModel(userID: try user.requireID(), value: "token123")
        try await token.create(on: app.db)
        try await repository.delete(id: token.requireID())
        let count = try await PasswordTokenModel.query(on: app.db).count()
        #expect(count == 0)
    }
}
