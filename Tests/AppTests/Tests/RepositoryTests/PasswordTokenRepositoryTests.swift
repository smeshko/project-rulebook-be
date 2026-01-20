@testable import App
import Fluent
import VaporTesting
import Testing
import Crypto

@Suite(.serialized)
struct PasswordTokenRepositoryTests {
    let app: Application
    let testWorld: IsolatedTestWorld
    let repository: any PasswordTokenRepository
    let userRepository: any UserRepository
    let user: UserAccountModel
    
    init() async throws {
        testWorld = try await IsolatedTestWorld()
        self.app = testWorld.app
        self.repository = testWorld.passwordTokens
        self.userRepository = testWorld.users
        try await app.autoMigrate()
        
        self.user = .init(email: "test-\(UUID().uuidString.lowercased())@test.com", password: "123")
        
        // Clear any existing data from test repositories
        await testWorld.resetAll()
        
        try await userRepository.create(user)
    }
    
    @Test("Password token can be found by user ID", .tags(.p0Critical, .database, .auth, .unit))
    func findByUserID() async throws {
        let userID = try user.requireID()
        let plainToken = "password-\(UUID().uuidString)"
        let hashedToken = SHA256.hash(plainToken)
        let token = PasswordTokenModel(userID: userID, value: hashedToken)
        try await repository.create(token)
        
        let foundToken = try await repository.find(forUserID: userID)
        #expect(foundToken != nil)
    }
    
    @Test("Password token can be found by token value", .tags(.p0Critical, .database, .auth, .unit))
    func findByToken() async throws {
        let plainToken = "find-\(UUID().uuidString)"
        let hashedToken = SHA256.hash(plainToken)
        let token = PasswordTokenModel(userID: try user.requireID(), value: hashedToken)
        try await repository.create(token)
        let foundToken = try await repository.find(token: plainToken)
        #expect(foundToken != nil)
    }
    
    @Test("Repository can count password tokens", .tags(.p2Extended, .database, .unit))
    func count() async throws {
        let plainToken1 = "count1-\(UUID().uuidString)"
        let plainToken2 = "count2-\(UUID().uuidString)"
        let hashedToken1 = SHA256.hash(plainToken1)
        let hashedToken2 = SHA256.hash(plainToken2)
        let token = PasswordTokenModel(userID: try user.requireID(), value: hashedToken1)
        let token2 = PasswordTokenModel(userID: try user.requireID(), value: hashedToken2)
        try await repository.create(token)
        try await repository.create(token2)
        let count = try await repository.count()
        #expect(count == 2)
    }
    
    @Test("Password token can be created", .tags(.p0Critical, .database, .auth, .unit))
    func create() async throws {
        let plainToken = "token-\(UUID().uuidString)"
        let hashedToken = SHA256.hash(plainToken)
        let token = PasswordTokenModel(userID: try user.requireID(), value: hashedToken)
        try await repository.create(token)
        let foundToken = try await repository.find(id: token.requireID())
        #expect(foundToken != nil)
    }
    
    @Test("Password token can be deleted", .tags(.p1Core, .database, .auth, .unit))
    func delete() async throws {
        let plainToken = "token-\(UUID().uuidString)"
        let hashedToken = SHA256.hash(plainToken)
        let token = PasswordTokenModel(userID: try user.requireID(), value: hashedToken)
        try await repository.create(token)
        try await repository.delete(id: token.requireID())
        let count = try await repository.count()
        #expect(count == 0)
    }
}
