import Fluent
import Vapor

protocol RemoteConfigRepository: Repository {
    func findAll() async throws -> [RemoteConfigModel]
    func find(key: String) async throws -> RemoteConfigModel?
    func create(_ model: RemoteConfigModel) async throws
    func update(_ model: RemoteConfigModel) async throws
    func delete(_ model: RemoteConfigModel) async throws
}

struct DatabaseRemoteConfigRepository: RemoteConfigRepository, DatabaseRepository {
    typealias Model = RemoteConfigModel
    let database: Database

    func findAll() async throws -> [RemoteConfigModel] {
        try await RemoteConfigModel.query(on: database)
            .sort(\.$key)
            .all()
    }

    func find(key: String) async throws -> RemoteConfigModel? {
        try await RemoteConfigModel.query(on: database)
            .filter(\.$key == key)
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

// MARK: - Application.Repositories Extension

extension Application.Repositories {
    var remoteConfig: any RemoteConfigRepository {
        application.remoteConfigRepository
    }
}
