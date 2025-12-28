import Fluent
import Vapor

protocol ConfigRepository: Repository {
    func find(id: UUID) async throws -> ConfigEntryModel?
    func find(key: String) async throws -> ConfigEntryModel?
    func findAll() async throws -> [ConfigEntryModel]
    func create(_ model: ConfigEntryModel) async throws
    func update(_ model: ConfigEntryModel) async throws
    func delete(_ model: ConfigEntryModel) async throws
}

struct DatabaseConfigRepository: ConfigRepository, DatabaseRepository {
    typealias Model = ConfigEntryModel
    let database: Database

    func find(id: UUID) async throws -> ConfigEntryModel? {
        try await ConfigEntryModel.query(on: database)
            .filter(\.$id == id)
            .first()
    }

    func find(key: String) async throws -> ConfigEntryModel? {
        try await ConfigEntryModel.query(on: database)
            .filter(\.$key == key)
            .first()
    }

    func findAll() async throws -> [ConfigEntryModel] {
        try await ConfigEntryModel.query(on: database)
            .sort(\.$key)
            .all()
    }

    func create(_ model: ConfigEntryModel) async throws {
        try await model.create(on: database)
    }

    func update(_ model: ConfigEntryModel) async throws {
        try await model.update(on: database)
    }

    func delete(_ model: ConfigEntryModel) async throws {
        try await model.delete(on: database)
    }
}

extension Application.Repositories {
    var config: any ConfigRepository {
        application.configRepository
    }
}
