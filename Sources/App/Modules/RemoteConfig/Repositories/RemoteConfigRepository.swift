import Fluent
import Vapor

protocol RemoteConfigRepository: Repository {
    func find(id: UUID) async throws -> RemoteConfigEntryModel?
    func find(key: String) async throws -> RemoteConfigEntryModel?
    func all() async throws -> [RemoteConfigEntryModel]
    func create(_ model: RemoteConfigEntryModel) async throws
    func update(_ model: RemoteConfigEntryModel) async throws
    func delete(_ model: RemoteConfigEntryModel) async throws
    func count() async throws -> Int
}

struct DatabaseRemoteConfigRepository: RemoteConfigRepository, DatabaseRepository {
    typealias Model = RemoteConfigEntryModel
    let database: Database

    func find(id: UUID) async throws -> RemoteConfigEntryModel? {
        try await RemoteConfigEntryModel.query(on: database)
            .filter(\.$id == id)
            .first()
    }

    func find(key: String) async throws -> RemoteConfigEntryModel? {
        try await RemoteConfigEntryModel.query(on: database)
            .filter(\.$key == key)
            .first()
    }

    func all() async throws -> [RemoteConfigEntryModel] {
        try await RemoteConfigEntryModel.query(on: database)
            .sort(\.$key)
            .all()
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

    func count() async throws -> Int {
        try await RemoteConfigEntryModel.query(on: database).count()
    }
}

extension Application.Repositories {
    var remoteConfig: any RemoteConfigRepository {
        application.remoteConfigRepository
    }
}
