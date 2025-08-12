@testable import App
import Vapor
import Crypto

final class TestRefreshTokenRepository: RefreshTokenRepository, TestRepository {
    var tokens: [RefreshTokenModel]
    typealias Model = RefreshTokenModel
    
    // Test tracking properties
    var createCalled = false
    var deleteCalled = false

    /// Alias for consistent test interface
    var entities: [RefreshTokenModel] {
        get { tokens }
        set { tokens = newValue }
    }

    init(tokens: [RefreshTokenModel] = []) {
        self.tokens = tokens
    }
    
    func find(token: String) async throws -> RefreshTokenModel? {
        tokens.first(where: { $0.value == token })
    }
    
    func find(forUserID id: UUID) async throws -> App.RefreshTokenModel? {
        tokens.first(where: { $0.$user.id == id })
    }
    
    func delete(forUserID id: UUID) async throws {
        tokens.removeAll(where: { $0.$user.id == id })
    }
    
    func create(_ model: RefreshTokenModel) async throws {
        createCalled = true
        model.id = UUID()
        tokens.append(model)
    }
    
    func all() async throws -> [RefreshTokenModel] {
        tokens
    }
    
    func find(id: UUID?) async throws -> (RefreshTokenModel)? {
        tokens.first(where: { $0.id == id })
    }
    
    func delete(id: UUID) async throws {
        deleteCalled = true
        tokens.removeAll(where: { $0.id == id })
    }
    
    func count() async throws -> Int {
        tokens.count
    }
    
    func reset() async {
        tokens.removeAll()
        createCalled = false
        deleteCalled = false
    }
    
    func `for`(_ req: Request) -> TestRefreshTokenRepository {
        return self
    }
}
