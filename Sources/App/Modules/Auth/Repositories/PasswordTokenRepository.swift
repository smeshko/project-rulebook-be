import Fluent
import Vapor
import Crypto

protocol PasswordTokenRepository: Repository {
    func find(forUserID id: UUID) async throws -> PasswordTokenModel?
    func find(token: String) async throws -> PasswordTokenModel?
    func delete(forUserID id: UUID) async throws
    func create(_ model: PasswordTokenModel) async throws
    func all() async throws -> [PasswordTokenModel]
    func find(id: UUID) async throws -> PasswordTokenModel?
}

struct DatabasePasswordTokenRepository: PasswordTokenRepository, DatabaseRepository {
    typealias Model = PasswordTokenModel
    
    let database: Database
    
    func find(forUserID id: UUID) async throws -> PasswordTokenModel? {
        try await PasswordTokenModel.query(on: database)
            .filter(\.$user.$id == id)
            .with(\.$user)
            .first()
     }
    
    func find(token: String) async throws -> PasswordTokenModel? {
        let hashedToken = SHA256.hash(token)
        return try await PasswordTokenModel.query(on: database)
            .filter(\.$value == hashedToken)
            .with(\.$user)
            .first()
    }

    func delete(forUserID id: UUID) async throws {
        try await PasswordTokenModel.query(on: database)
            .filter(\.$user.$id == id)
            .delete()
    }
    
    func all() async throws -> [PasswordTokenModel] {
        try await PasswordTokenModel
            .query(on: database)
            .with(\.$user)
            .all()
    }
    
    func find(id: UUID) async throws -> PasswordTokenModel? {
        try await PasswordTokenModel
            .query(on: database)
            .filter(\.$id == id)
            .with(\.$user)
            .first()
    }
    
    func create(_ model: PasswordTokenModel) async throws {
        try await model.create(on: database)
    }
}

extension Application.Repositories {
    var passwordTokens: any PasswordTokenRepository {
        application.passwordTokenRepository
    }
}

extension Request.Services {
    var passwordTokens: any PasswordTokenRepository {
        // Use pre-resolved service from ServiceCache for immediate synchronous access
        request.application.passwordTokenRepository
    }
}
