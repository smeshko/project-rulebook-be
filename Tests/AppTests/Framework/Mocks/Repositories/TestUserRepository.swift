@testable import App
import Vapor
import Fluent

actor TestUserRepository: UserRepository, TestRepository {
    var users: [UserAccountModel]
    
    init(users: [UserAccountModel] = []) {
        self.users = users
    }
    
    typealias Model = UserAccountModel
    
    func create(_ model: UserAccountModel) async throws {
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
}