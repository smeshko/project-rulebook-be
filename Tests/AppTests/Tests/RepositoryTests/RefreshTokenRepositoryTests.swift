@testable import App
import Fluent
import XCTVapor
import Testing

struct RefreshTokenRepositoryTests {
    let app: Application
    let repository: any RefreshTokenRepository
    let user: UserAccountModel
    
    init() async throws {
        self.app = try TestWorld.makeTestAppSync()
        self.repository = DatabaseRefreshTokenRepository(database: app.db)
        try await app.autoMigrate()
        self.user = UserAccountModel(
            email: "test@test.com",
            password: "123"
        )
    }
    
    @Test("Refresh token can be created and retrieved")
    func creatingToken() async throws {
        try await user.create(on: app.db)
        let token = try RefreshTokenModel(value: "123", userID: user.requireID())
        try await repository.create(token)
        
        #expect(token.id != nil)
        
        let tokenRetrieved = try await RefreshTokenModel.find(token.id, on: app.db)
        #expect(tokenRetrieved != nil)
        #expect(tokenRetrieved!.$user.id == try user.requireID())
    }
    
    @Test("Refresh token can be found by ID")
    func findingTokenById() async throws {
        try await user.create(on: app.db)
        let token = try RefreshTokenModel(value: "123", userID: user.requireID())
        try await token.create(on: app.db)
        let tokenId = try token.requireID()
        let tokenFound = try await repository.find(id: tokenId)
        #expect(tokenFound != nil)
    }
    
    @Test("Refresh token can be found by token string")
    func findingTokenByTokenString() async throws {
        try await user.create(on: app.db)
        let token = try RefreshTokenModel(value: "123", userID: user.requireID())
        try await token.create(on: app.db)
        let tokenFound = try await repository.find(token: "123")
        #expect(tokenFound != nil)
    }
    
    @Test("Refresh token can be deleted")
    func deletingToken() async throws {
        try await user.create(on: app.db)
        let token = try RefreshTokenModel(value: "123", userID: user.requireID())
        try await token.create(on: app.db)
        let tokenCount = try await RefreshTokenModel.query(on: app.db).count()
        #expect(tokenCount == 1)
        try await repository.delete(id: token.requireID())
        let newTokenCount = try await RefreshTokenModel.query(on: app.db).count()
        #expect(newTokenCount == 0)
    }
    
    @Test("Repository can count refresh tokens")
    func getCount() async throws {
        try await user.create(on: app.db)
        let token = try RefreshTokenModel(value: "123", userID: user.requireID())
        try await token.create(on: app.db)
        let tokenCount = try await repository.count()
        #expect(tokenCount == 1)
    }
}
