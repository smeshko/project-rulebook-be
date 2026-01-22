import Fluent
import Vapor

protocol RemoteConfigRepository: Repository {
    func find(id: UUID) async throws -> RemoteConfigModel?
    func find(key: String) async throws -> RemoteConfigModel?
    func create(_ model: RemoteConfigModel) async throws
    func update(_ model: RemoteConfigModel) async throws
    func delete(_ model: RemoteConfigModel) async throws
    func all() async throws -> [RemoteConfigModel]
    func deleteByKey(_ key: String) async throws
}

struct DatabaseRemoteConfigRepository: RemoteConfigRepository, DatabaseRepository {
    typealias Model = RemoteConfigModel
    let database: Database

    func find(id: UUID) async throws -> RemoteConfigModel? {
        try await RemoteConfigModel.query(on: database)
            .filter(\.$id == id)
            .first()
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

    func all() async throws -> [RemoteConfigModel] {
        try await RemoteConfigModel.query(on: database).all()
    }

    func deleteByKey(_ key: String) async throws {
        try await RemoteConfigModel.query(on: database)
            .filter(\.$key == key)
            .delete()
    }
}

extension Application.Repositories {
    var remoteConfig: any RemoteConfigRepository {
        application.remoteConfigRepository
    }
}
