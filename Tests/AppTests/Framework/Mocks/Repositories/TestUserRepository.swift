@testable import App
import Vapor
import Fluent

actor TestUserRepository: UserRepository, TestRepository {
    var users: [UserAccountModel]
    
    /// Alias for consistent test interface
    var entities: [UserAccountModel] {
        get { users }
        set { users = newValue }
    }
    
    init(users: [UserAccountModel] = []) {
        self.users = users
    }
    
    typealias Model = UserAccountModel
    
    func create(_ model: UserAccountModel) async throws {
        // Simulate unique email constraint like a real database
        if users.contains(where: { $0.email == model.email }) {
            throw Abort(.conflict, reason: "UNIQUE constraint failed: users.email")
        }
        model.id = model.id ?? UUID()
        users.append(model)
    }

    func delete(id: UUID) async throws {
        users.removeAll(where: { $0.id == id })
    }
    
    func find(email: String) async throws -> UserAccountModel? {
        users.first(where: { $0.email == email })
    }

    func find(id: UUID) async throws -> UserAccountModel? {
        users.first(where: { $0.id == id })
    }

    func find(appleUserIdentifier: String) async throws -> UserAccountModel? {
        users.first(where: { $0.appleUserIdentifier == appleUserIdentifier })
    }
    
    func all() async throws -> [UserAccountModel] {
        users
    }
    
    func update(_ model: UserAccountModel) async throws {
        guard let id = model.id,
              let index = users.firstIndex(where: { $0.id == id }) else {
            throw Abort(.notFound)
        }
        users[index] = model
    }
    
    func count() async throws -> Int {
        users.count
    }
    
    func reset() async {
        users.removeAll()
    }
    
    // MARK: - Optimized methods with eager loading (test implementations)
    // These methods are not used in tests currently, but need to be implemented for protocol compliance
    
    func findWithTokens(id: UUID) async throws -> (user: UserAccountModel?, refreshTokens: [RefreshTokenModel], emailTokens: [EmailTokenModel], passwordTokens: [PasswordTokenModel]) {
        let user = try await find(id: id)
        return (user: user, refreshTokens: [], emailTokens: [], passwordTokens: [])
    }
    
    func findWithRefreshTokens(id: UUID) async throws -> (user: UserAccountModel?, refreshTokens: [RefreshTokenModel]) {
        let user = try await find(id: id)
        return (user: user, refreshTokens: [])
    }
    
    func findWithEmailTokens(id: UUID) async throws -> (user: UserAccountModel?, emailTokens: [EmailTokenModel]) {
        let user = try await find(id: id)
        return (user: user, emailTokens: [])
    }
    
    func findWithPasswordTokens(id: UUID) async throws -> (user: UserAccountModel?, passwordTokens: [PasswordTokenModel]) {
        let user = try await find(id: id)
        return (user: user, passwordTokens: [])
    }
    
    nonisolated func `for`(_ req: Request) -> TestUserRepository {
        return self
    }
}