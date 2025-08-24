@testable import App
import Fluent
import VaporTesting
import Testing

@Suite(.serialized)
struct RefreshTokenRepositoryTests {
    let app: Application
    let testWorld: IsolatedTestWorld
    let repository: any RefreshTokenRepository
    let userRepository: any UserRepository
    let user: UserAccountModel
    
    init() async throws {
        testWorld = try await IsolatedTestWorld()
        self.app = testWorld.app
        self.repository = testWorld.refreshTokens
        self.userRepository = testWorld.users
        try await app.autoMigrate()
        
        self.user = UserAccountModel(
            email: "test-\(UUID().uuidString.lowercased())@test.com",
            password: "123"
        )
        
        // Clear any existing data from test repositories
        await testWorld.resetAll()
    }
    
    @Test("Refresh token can be created and retrieved")
    func creatingToken() async throws {
        try await userRepository.create(user)
        let tokenValue = "create-\(UUID().uuidString)"
        let token = try RefreshTokenModel(value: tokenValue, userID: user.requireID())
        try await repository.create(token)
        
        #expect(token.id != nil)
        
        let tokenRetrieved = try await repository.find(id: token.requireID())
        #expect(tokenRetrieved != nil)
        let userID = try user.requireID()
        #expect(tokenRetrieved!.$user.id == userID)
    }
    
    @Test("Refresh token can be found by ID")
    func findingTokenById() async throws {
        try await userRepository.create(user)
        let tokenValue = "token-\(UUID().uuidString)"
        let token = try RefreshTokenModel(value: tokenValue, userID: user.requireID())
        try await repository.create(token)
        let tokenId = try token.requireID()
        let tokenFound = try await repository.find(id: tokenId)
        #expect(tokenFound != nil)
    }
    
    @Test("Refresh token can be found by token string")
    func findingTokenByTokenString() async throws {
        try await userRepository.create(user)
        let tokenValue = "token-\(UUID().uuidString)"
        let token = try RefreshTokenModel(value: tokenValue, userID: user.requireID())
        try await repository.create(token)
        let tokenFound = try await repository.find(token: tokenValue)
        #expect(tokenFound != nil)
    }
    
    @Test("Refresh token can be deleted")
    func deletingToken() async throws {
        try await userRepository.create(user)
        let tokenValue = "token-\(UUID().uuidString)"
        let token = try RefreshTokenModel(value: tokenValue, userID: user.requireID())
        try await repository.create(token)
        let tokenCount = try await repository.count()
        #expect(tokenCount == 1)
        try await repository.delete(id: token.requireID())
        let newTokenCount = try await repository.count()
        #expect(newTokenCount == 0)
    }
    
    @Test("Repository can count refresh tokens")
    func getCount() async throws {
        try await userRepository.create(user)
        let tokenValue = "token-\(UUID().uuidString)"
        let token = try RefreshTokenModel(value: tokenValue, userID: user.requireID())
        try await repository.create(token)
        let tokenCount = try await repository.count()
        #expect(tokenCount == 1)
    }
}
