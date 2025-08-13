import Fluent
import Vapor

protocol UserRepository: Repository {
    func find(id: UUID) async throws -> UserAccountModel?
    func find(email: String) async throws -> UserAccountModel?
    func find(appleUserIdentifier: String) async throws -> UserAccountModel?
    func create(_ model: UserAccountModel) async throws
    func all() async throws -> [UserAccountModel]
    func update(_ model: UserAccountModel) async throws
}

struct DatabaseUserRepository: UserRepository, DatabaseRepository {
    typealias Model = UserAccountModel
    
    let database: Database

    func find(appleUserIdentifier: String) async throws -> UserAccountModel? {
        try await UserAccountModel.query(on: database)
            .filter(\.$appleUserIdentifier == appleUserIdentifier)
            .first()
    }

    func find(email: String) async throws -> UserAccountModel? {
        try await UserAccountModel.query(on: database)
            .filter(\.$email == email)
            .first()
    }
    
    func find(id: UUID) async throws -> UserAccountModel? {
        try await UserAccountModel.query(on: database)
            .filter(\.$id == id)
            .first()
    }
    
    func all() async throws -> [UserAccountModel] {
        try await UserAccountModel.query(on: database)
            .all()
    }
    
    func create(_ model: UserAccountModel) async throws {
        try await model.create(on: database)
    }
    
    func update(_ model: UserAccountModel) async throws {
        try await model.update(on: database)
    }
}

extension Application.Repositories {
    var users: any UserRepository {
        application.serviceCache.userRepository
    }
}

extension Request.Services {
    var users: any UserRepository {
        // Use pre-resolved service from ServiceCache for immediate synchronous access
        request.application.serviceCache.userRepository
    }
}
