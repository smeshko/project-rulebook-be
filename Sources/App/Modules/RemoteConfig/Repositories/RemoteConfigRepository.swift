import Fluent
import Vapor

protocol RemoteConfigRepository: Repository {
    func findAll() async throws -> [RemoteConfigEntryModel]
    func find(key: String) async throws -> RemoteConfigEntryModel?
    func find(id: UUID) async throws -> RemoteConfigEntryModel?
    func create(_ model: RemoteConfigEntryModel) async throws
    func update(_ model: RemoteConfigEntryModel) async throws
    func delete(_ model: RemoteConfigEntryModel) async throws
}

struct DatabaseRemoteConfigRepository: RemoteConfigRepository, DatabaseRepository {
    typealias Model = RemoteConfigEntryModel
    let database: Database

    func findAll() async throws -> [RemoteConfigEntryModel] {
        try await RemoteConfigEntryModel.query(on: database)
            .sort(\.$key)
            .all()
    }

    func find(key: String) async throws -> RemoteConfigEntryModel? {
        try await RemoteConfigEntryModel.query(on: database)
            .filter(\.$key == key)
            .first()
    }

    func find(id: UUID) async throws -> RemoteConfigEntryModel? {
        try await RemoteConfigEntryModel.find(id, on: database)
    }

    func create(_ model: RemoteConfigEntryModel) async throws {
        try await model.create(on: database)
    }

    func update(_ model: RemoteConfigEntryModel) async throws {
        try await model.update(on: database)
    }

    func delete(_ model: RemoteConfigEntryModel) async throws {
        try await model.delete(on: database)
    }
}

extension Application.Repositories {
    var remoteConfig: any RemoteConfigRepository {
        application.remoteConfigRepository
    }
}
