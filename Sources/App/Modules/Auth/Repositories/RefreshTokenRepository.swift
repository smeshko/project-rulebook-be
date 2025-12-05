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
            .with(\.$user)
            .first()
    }

    func find(token: String) async throws -> RefreshTokenModel? {
        try await RefreshTokenModel.query(on: database)
            .filter(\.$value == token)
            .with(\.$user)
            .first()
    }
    
    func delete(forUserID id: UUID) async throws {
        try await RefreshTokenModel.query(on: database)
            .filter(\.$user.$id == id)
            .delete()
    }
    
    func all() async throws -> [RefreshTokenModel] {
        try await RefreshTokenModel.query(on: database)
            .with(\.$user)
            .all()
    }
    
    func find(id: UUID?) async throws -> RefreshTokenModel? {
        guard let id = id else { return nil }
        return try await RefreshTokenModel.query(on: database)
            .filter(\.$id == id)
            .with(\.$user)
            .first()
    }
    
    func create(_ model: RefreshTokenModel) async throws {
        try await model.create(on: database)
    }
}

extension Application.Repositories {
    var refreshTokens: any RefreshTokenRepository {
        application.refreshTokenRepository
    }
}

extension Request.Services {
    var refreshTokens: any RefreshTokenRepository {
        request.application.refreshTokenRepository
    }
}
