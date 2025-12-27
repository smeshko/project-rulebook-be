import Fluent
import Vapor

protocol RemoteConfigRepository: Repository {
    func getAll() async throws -> [RemoteConfigModel]
    func get(key: String) async throws -> RemoteConfigModel?
    func update(key: String, value: String, type: ConfigValueType) async throws -> RemoteConfigModel
    func delete(key: String) async throws
}

struct DatabaseRemoteConfigRepository: RemoteConfigRepository, DatabaseRepository {
    typealias Model = RemoteConfigModel
    let database: Database

    func getAll() async throws -> [RemoteConfigModel] {
        try await RemoteConfigModel.query(on: database).all()
    }

    func get(key: String) async throws -> RemoteConfigModel? {
        try await RemoteConfigModel.query(on: database)
            .filter(\.$key == key)
            .first()
    }

    func update(key: String, value: String, type: ConfigValueType) async throws -> RemoteConfigModel {
        if let existing = try await get(key: key) {
            existing.value = value
            existing.valueType = type
            try await existing.update(on: database)
            return existing
        } else {
            let new = RemoteConfigModel(key: key, value: value, valueType: type)
            try await new.create(on: database)
            return new
        }
    }

    func delete(key: String) async throws {
        if let config = try await get(key: key) {
            try await config.delete(on: database)
        }
    }
}

extension Application.Repositories {
    var remoteConfig: any RemoteConfigRepository {
        application.remoteConfigRepository
    }
}
