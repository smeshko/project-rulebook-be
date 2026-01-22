@testable import App
import Vapor
import Fluent

actor TestConfigRepository: ConfigRepository, TestRepository {
    var configs: [ConfigEntryModel]

    var entities: [ConfigEntryModel] {
        get { configs }
        set { configs = newValue }
    }

    init(configs: [ConfigEntryModel] = []) {
        self.configs = configs
    }

    typealias Model = ConfigEntryModel

    func find(id: UUID) async throws -> ConfigEntryModel? {
        configs.first(where: { $0.id == id })
    }

    func find(key: String) async throws -> ConfigEntryModel? {
        configs.first(where: { $0.key == key })
    }

    func findByCategory(_ category: ConfigCategory) async throws -> [ConfigEntryModel] {
        configs.filter { $0.category == category }
    }

    func all() async throws -> [ConfigEntryModel] {
        configs
    }

    func create(_ model: ConfigEntryModel) async throws {
        if configs.contains(where: { $0.key == model.key }) {
            throw Abort(.conflict, reason: "UNIQUE constraint failed: config_entries.key")
        }
        model.id = model.id ?? UUID()
        configs.append(model)
    }

    func update(_ model: ConfigEntryModel) async throws {
        guard let id = model.id,
              let index = configs.firstIndex(where: { $0.id == id }) else {
            throw Abort(.notFound)
        }
        configs[index] = model
    }

    func delete(_ model: ConfigEntryModel) async throws {
        configs.removeAll(where: { $0.id == model.id })
    }

    func delete(id: UUID) async throws {
        configs.removeAll(where: { $0.id == id })
    }

    func count() async throws -> Int {
        configs.count
    }

    func reset() async {
        configs.removeAll()
    }

    nonisolated func `for`(_ req: Request) -> TestConfigRepository {
        return self
    }
}
