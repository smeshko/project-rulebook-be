import Fluent
import Vapor

protocol RemoteConfigRepository: Repository {
    func all() async throws -> [RemoteConfigModel]
    func find(key: String) async throws -> RemoteConfigModel?
    func find(id: UUID) async throws -> RemoteConfigModel?
    func create(_ model: RemoteConfigModel) async throws
    func update(_ model: RemoteConfigModel) async throws
    func delete(_ model: RemoteConfigModel) async throws
}

struct DatabaseRemoteConfigRepository: RemoteConfigRepository, DatabaseRepository {
    typealias Model = RemoteConfigModel

    let database: Database

    func all() async throws -> [RemoteConfigModel] {
        try await RemoteConfigModel.query(on: database)
            .filter(\.$deletedAt == nil)
            .all()
    }

    func find(key: String) async throws -> RemoteConfigModel? {
        try await RemoteConfigModel.query(on: database)
            .filter(\.$key == key)
            .filter(\.$deletedAt == nil)
            .first()
    }

    func find(id: UUID) async throws -> RemoteConfigModel? {
        try await RemoteConfigModel.query(on: database)
            .filter(\.$id == id)
            .filter(\.$deletedAt == nil)
            .first()
    }

    func create(_ model: RemoteConfigModel) async throws {
        try await model.create(on: database)
    }

    func update(_ model: RemoteConfigModel) async throws {
        try await model.update(on: database)
    }

    func delete(_ model: RemoteConfigModel) async throws {
        try await model.delete(on: database)
    }
}

extension Application.Repositories {
    var remoteConfig: any RemoteConfigRepository {
        application.remoteConfigRepository
    }
}

extension Request.Services {
    var remoteConfig: any RemoteConfigRepository {
        request.application.remoteConfigRepository
    }
}
