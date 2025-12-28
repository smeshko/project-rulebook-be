import Fluent
import Vapor

protocol ConfigRepository: Repository {
    func find(id: UUID) async throws -> ConfigValueModel?
    func find(key: String) async throws -> ConfigValueModel?
    func create(_ model: ConfigValueModel) async throws
    func update(_ model: ConfigValueModel) async throws
    func delete(_ model: ConfigValueModel) async throws
    func all() async throws -> [ConfigValueModel]
}

struct DatabaseConfigRepository: ConfigRepository, DatabaseRepository {
    typealias Model = ConfigValueModel
    let database: Database

    func find(id: UUID) async throws -> ConfigValueModel? {
        try await ConfigValueModel.query(on: database)
            .filter(\.$id == id)
            .first()
    }

    func find(key: String) async throws -> ConfigValueModel? {
        try await ConfigValueModel.query(on: database)
            .filter(\.$key == key)
            .first()
    }

    func create(_ model: ConfigValueModel) async throws {
        try await model.create(on: database)
    }

    func update(_ model: ConfigValueModel) async throws {
        try await model.update(on: database)
    }

    func delete(_ model: ConfigValueModel) async throws {
        try await model.delete(on: database)
    }

    func all() async throws -> [ConfigValueModel] {
        try await ConfigValueModel.query(on: database).all()
    }
}

extension Application.Repositories {
    var config: any ConfigRepository {
        application.configRepository
    }
}
