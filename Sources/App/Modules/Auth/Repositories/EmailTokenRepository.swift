import Fluent
import Foundation
import Vapor
import Crypto

protocol EmailTokenRepository: Repository {
    func find(forUserID id: UUID) async throws -> EmailTokenModel?
    func find(token: String) async throws -> EmailTokenModel?
    func delete(forUserID id: UUID) async throws
    func create(_ model: EmailTokenModel) async throws
    func all() async throws -> [EmailTokenModel]
    func find(id: UUID) async throws -> EmailTokenModel?
}

struct DatabaseEmailTokenRepository: EmailTokenRepository, DatabaseRepository {
    typealias Model = EmailTokenModel
    
    let database: Database
    
    func find(forUserID id: UUID) async throws -> EmailTokenModel? {
        try await EmailTokenModel.query(on: database)
            .filter(\.$user.$id == id)
            .with(\.$user)
            .first()
    }
    
    func find(token: String) async throws -> EmailTokenModel? {
        let hashedToken = SHA256.hash(token)
        return try await EmailTokenModel.query(on: database)
            .filter(\.$value == hashedToken)
            .with(\.$user)
            .first()
    }
    
    func delete(forUserID id: UUID) async throws {
        try await EmailTokenModel.query(on: database)
            .filter(\.$user.$id == id)
            .delete()
    }
    
    func all() async throws -> [EmailTokenModel] {
        try await EmailTokenModel
            .query(on: database)
            .with(\.$user)
            .all()
    }
    
    func find(id: UUID) async throws -> EmailTokenModel? {
        try await EmailTokenModel
            .query(on: database)
            .filter(\.$id == id)
            .with(\.$user)
            .first()
    }
    
    func create(_ model: EmailTokenModel) async throws {
        try await model.create(on: database)
    }

}

extension Application.Repositories {
    var emailTokens: any EmailTokenRepository {
        application.serviceCache.emailTokenRepository
    }
}

extension Request.Services {
    var emailTokens: any EmailTokenRepository {
        // Use pre-resolved service from ServiceCache for immediate synchronous access
        request.application.serviceCache.emailTokenRepository
    }
}
