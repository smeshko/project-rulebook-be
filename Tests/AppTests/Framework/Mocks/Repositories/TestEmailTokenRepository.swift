@testable import App
import Vapor
import Crypto

final class TestEmailTokenRepository: EmailTokenRepository, TestRepository {
    typealias Model = EmailTokenModel
    var tokens: [EmailTokenModel]
    
    /// Alias for consistent test interface
    var entities: [EmailTokenModel] {
        get { tokens }
        set { tokens = newValue }
    }
    
    init(tokens: [EmailTokenModel] = []) {
        self.tokens = tokens
    }
    
    func find(token: String) async throws -> EmailTokenModel? {
        let hashedToken = SHA256.hash(token)
        return tokens.first(where: { $0.value == hashedToken })
    }
    
    func find(forUserID id: UUID) async throws -> EmailTokenModel? {
        tokens.first(where: { $0.$user.id == id })
    }
    
    func delete(forUserID id: UUID) async throws {
        tokens.removeAll(where: { $0.$user.id == id })
    }
    
    func create(_ model: EmailTokenModel) async throws {
        model.id = UUID()
        tokens.append(model)
    }
    
    func all() async throws -> [EmailTokenModel] {
        tokens
    }
    
    func find(id: UUID) async throws -> EmailTokenModel? {
        tokens.first(where: { $0.id == id })
    }
    
    func delete(id: UUID) async throws {
        tokens.removeAll(where: { $0.id == id })
    }
    
    func count() async throws -> Int {
        tokens.count
    }
    
    func reset() async {
        tokens.removeAll()
    }
    
    func `for`(_ req: Request) -> TestEmailTokenRepository {
        return self
    }
}
