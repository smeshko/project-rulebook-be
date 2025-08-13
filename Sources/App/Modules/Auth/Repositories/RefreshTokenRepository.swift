import Fluent
import Vapor

protocol RefreshTokenRepository: Repository {
    func find(forUserID id: UUID) async throws -> RefreshTokenModel?
    func find(token: String) async throws -> RefreshTokenModel?
    func delete(forUserID id: UUID) async throws
    func create(_ model: RefreshTokenModel) async throws
    func all() async throws -> [RefreshTokenModel]
    func find(id: UUID?) async throws -> RefreshTokenModel?
}

struct DatabaseRefreshTokenRepository: RefreshTokenRepository, DatabaseRepository {
    typealias Model = RefreshTokenModel
    let database: Database
    
    func find(forUserID id: UUID) async throws -> RefreshTokenModel? {
        try await RefreshTokenModel.query(on: database)
            .filter(\.$user.$id == id)
            .first()
    }

    func find(token: String) async throws -> RefreshTokenModel? {
        try await RefreshTokenModel.query(on: database)
            .filter(\.$value == token)
            .first()
    }
    
    func delete(forUserID id: UUID) async throws {
        try await RefreshTokenModel.query(on: database)
            .filter(\.$user.$id == id)
            .delete()
    }
    
    func all() async throws -> [RefreshTokenModel] {
        try await RefreshTokenModel.query(on: database).all()
    }
    
    func find(id: UUID?) async throws -> RefreshTokenModel? {
        try await RefreshTokenModel.find(id, on: database)
    }
    
    func create(_ model: RefreshTokenModel) async throws {
        try await model.create(on: database)
    }
}

extension Application.Repositories {
    var refreshTokens: any RefreshTokenRepository {
        application.serviceCache.refreshTokenRepository
    }
}

extension Request.Services {
    var refreshTokens: any RefreshTokenRepository {
        // Use pre-resolved service from ServiceCache for immediate synchronous access
        request.application.serviceCache.refreshTokenRepository
    }
}
