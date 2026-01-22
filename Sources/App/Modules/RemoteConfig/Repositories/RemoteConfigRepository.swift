import Fluent
import Vapor

protocol RemoteConfigRepository: Repository {
    func findAll() async throws -> [RemoteConfigModel]
    func find(key: String) async throws -> RemoteConfigModel?
    func create(_ model: RemoteConfigModel) async throws
    func update(_ model: RemoteConfigModel) async throws
    func delete(key: String) async throws
}

struct DatabaseRemoteConfigRepository: RemoteConfigRepository, DatabaseRepository {
    typealias Model = RemoteConfigModel

    let database: Database

    func findAll() async throws -> [RemoteConfigModel] {
        try await RemoteConfigModel.query(on: database).all()
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

    func delete(key: String) async throws {
        try await RemoteConfigModel.query(on: database)
            .filter(\.$key == key)
            .delete()
    }
}

extension Application.Repositories {
    var remoteConfigs: any RemoteConfigRepository {
        application.remoteConfigRepository
    }
}

extension Request.Services {
    var remoteConfigs: any RemoteConfigRepository {
        request.application.remoteConfigRepository
    }
}
