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

    func all() async throws -> [RemoteConfigModel] {
        configs.filter { $0.deletedAt == nil }
    }

    func find(key: String) async throws -> RemoteConfigModel? {
        configs.first { $0.key == key && $0.deletedAt == nil }
    }

    func find(id: UUID) async throws -> RemoteConfigModel? {
        configs.first { $0.id == id && $0.deletedAt == nil }
    }

    func create(_ model: RemoteConfigModel) async throws {
        // Simulate unique key constraint
        if configs.contains(where: { $0.key == model.key && $0.deletedAt == nil }) {
            throw Abort(.conflict, reason: "UNIQUE constraint failed: remote_configs.key")
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
        guard let id = model.id,
              let index = configs.firstIndex(where: { $0.id == id }) else {
            throw Abort(.notFound)
        }
        // Soft delete
        model.deletedAt = Date()
        configs[index] = model
    }

    func delete(id: UUID) async throws {
        guard let index = configs.firstIndex(where: { $0.id == id }) else {
            throw Abort(.notFound)
        }
        configs[index].deletedAt = Date()
    }

    func count() async throws -> Int {
        configs.filter { $0.deletedAt == nil }.count
    }

    func reset() async {
        configs.removeAll()
    }

    nonisolated func `for`(_ req: Request) -> TestRemoteConfigRepository {
        return self
    }
}
