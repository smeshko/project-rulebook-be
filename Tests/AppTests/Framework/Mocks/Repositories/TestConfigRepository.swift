@testable import App
import Vapor
import Fluent

actor TestConfigRepository: ConfigRepository, TestRepository {
    var configs: [ConfigValueModel]

    /// Alias for consistent test interface
    var entities: [ConfigValueModel] {
        get { configs }
        set { configs = newValue }
    }

    init(configs: [ConfigValueModel] = []) {
        self.configs = configs
    }

    typealias Model = ConfigValueModel

    func create(_ model: ConfigValueModel) async throws {
        // Simulate unique key constraint like a real database
        if configs.contains(where: { $0.key == model.key }) {
            throw Abort(.conflict, reason: "UNIQUE constraint failed: config_values.key")
        }
        model.id = model.id ?? UUID()
        configs.append(model)
    }

    func delete(id: UUID) async throws {
        configs.removeAll(where: { $0.id == id })
    }

    func delete(_ model: ConfigValueModel) async throws {
        configs.removeAll(where: { $0.id == model.id })
    }

    func find(id: UUID) async throws -> ConfigValueModel? {
        configs.first(where: { $0.id == id })
    }

    func find(key: String) async throws -> ConfigValueModel? {
        configs.first(where: { $0.key == key })
    }

    func all() async throws -> [ConfigValueModel] {
        configs
    }

    func update(_ model: ConfigValueModel) async throws {
        guard let id = model.id,
              let index = configs.firstIndex(where: { $0.id == id }) else {
            throw Abort(.notFound)
        }
        configs[index] = model
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
