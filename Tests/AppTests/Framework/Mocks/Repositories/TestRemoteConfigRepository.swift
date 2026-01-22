@testable import App
import Vapor
import Fluent

actor TestRemoteConfigRepository: RemoteConfigRepository, TestRepository {
    var configs: [RemoteConfigModel]

    /// Alias for consistent test interface
    var entities: [RemoteConfigModel] {
        get { configs }
        set { configs = newValue }
    }

    init(configs: [RemoteConfigModel] = []) {
        self.configs = configs
    }

    typealias Model = RemoteConfigModel

    func findAll() async throws -> [RemoteConfigModel] {
        configs.sorted { $0.key < $1.key }
    }

    func find(key: String) async throws -> RemoteConfigModel? {
        configs.first(where: { $0.key == key })
    }

    func create(_ model: RemoteConfigModel) async throws {
        // Simulate unique key constraint like a real database
        if configs.contains(where: { $0.key == model.key }) {
            throw Abort(.conflict, reason: "UNIQUE constraint failed: remote_config.key")
        }
        model.id = model.id ?? UUID()
        configs.append(model)
    }

    func update(_ model: RemoteConfigModel) async throws {
        guard let id = model.id,
              let index = configs.firstIndex(where: { $0.id == id }) else {
            throw Abort(.notFound)
        }
        configs[index] = model
    }

    func delete(_ model: RemoteConfigModel) async throws {
        guard let id = model.id else {
            throw Abort(.notFound)
        }
        configs.removeAll(where: { $0.id == id })
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

    nonisolated func `for`(_ req: Request) -> TestRemoteConfigRepository {
        return self
    }
}
