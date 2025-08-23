@testable import App
import Fluent
import VaporTesting
import Testing
import Crypto

@Suite(.serialized)
struct EmailTokenRepositoryTests {
    let app: Application
    let testWorld: IsolatedTestWorld
    let repository: any EmailTokenRepository
    let user: UserAccountModel
    
    init() async throws {
        testWorld = try await IsolatedTestWorld()
        self.app = testWorld.app
        self.repository = DatabaseEmailTokenRepository(database: app.db)
        try await app.autoMigrate()
        
        self.user = .init(email: "test-\(UUID().uuidString.lowercased())@test.com", password: "123")
        
        // Clear any existing data from shared database
        try await clearDatabaseData()
    }
    
    private func clearDatabaseData() async throws {
        // Clear all data from tables in reverse dependency order to avoid foreign key constraints
        try await RefreshTokenModel.query(on: app.db).delete()
        try await EmailTokenModel.query(on: app.db).delete() 
        try await PasswordTokenModel.query(on: app.db).delete()
        try await UserAccountModel.query(on: app.db).delete()
    }
    
    @Test("Email token can be created")
    func creatingEmailToken() async throws {
        try await user.create(on: app.db)
        let plainToken = "email-\(UUID().uuidString)"
        let hashedToken = SHA256.hash(plainToken)
        let emailToken = EmailTokenModel(userID: try user.requireID(), value: hashedToken)
        try await repository.create(emailToken)
        
        let count = try await EmailTokenModel.query(on: app.db).count()
        #expect(count == 1)
    }
    
    @Test("Email token can be found by token value")
    func findingEmailTokenByToken() async throws {
        try await user.create(on: app.db)
        let plainToken = "email-find-\(UUID().uuidString)"
        let hashedToken = SHA256.hash(plainToken)
        let emailToken = EmailTokenModel(userID: try user.requireID(), value: hashedToken)
        try await emailToken.create(on: app.db)
        let found = try await repository.find(token: plainToken)
        #expect(found != nil)
    }
    
    @Test("Email token can be deleted")
    func deleteEmailToken() async throws {
        try await user.create(on: app.db)
        let plainToken = "email-delete-\(UUID().uuidString)"
        let hashedToken = SHA256.hash(plainToken)
        let emailToken = EmailTokenModel(userID: try user.requireID(), value: hashedToken)
        try await emailToken.create(on: app.db)
        try await repository.delete(id: emailToken.requireID())
        let count = try await EmailTokenModel.query(on: app.db).count()
        #expect(count == 0)
    }
}
