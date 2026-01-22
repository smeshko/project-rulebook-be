import Fluent
import Vapor

protocol ConfigRepository: Repository {
    func find(id: UUID) async throws -> ConfigEntryModel?
    func find(key: String) async throws -> ConfigEntryModel?
    func findByCategory(_ category: ConfigCategory) async throws -> [ConfigEntryModel]
    func all() async throws -> [ConfigEntryModel]
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

    func findByCategory(_ category: ConfigCategory) async throws -> [ConfigEntryModel] {
        try await ConfigEntryModel.query(on: database)
            .filter(\.$category == category)
            .all()
    }

    func all() async throws -> [ConfigEntryModel] {
        try await ConfigEntryModel.query(on: database).all()
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
