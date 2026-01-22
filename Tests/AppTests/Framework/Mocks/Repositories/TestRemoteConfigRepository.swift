@testable import App
import Vapor

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

    func find(id: UUID) async throws -> RemoteConfigModel? {
        configs.first(where: { $0.id == id })
    }

    func find(key: String) async throws -> RemoteConfigModel? {
        configs.first(where: { $0.key == key })
    }

    func create(_ model: RemoteConfigModel) async throws {
        // Simulate unique key constraint
        if configs.contains(where: { $0.key == model.key }) {
            throw Abort(.conflict, reason: "UNIQUE constraint failed: remote_configs.key")
        }
        model.id = model.id ?? UUID()
        model.createdAt = model.createdAt ?? Date()
        model.updatedAt = model.updatedAt ?? Date()
        configs.append(model)
    }

    func update(_ model: RemoteConfigModel) async throws {
        guard let id = model.id,
              let index = configs.firstIndex(where: { $0.id == id }) else {
            throw Abort(.notFound)
        }
        model.updatedAt = Date()
        configs[index] = model
    }

    func delete(_ model: RemoteConfigModel) async throws {
        guard let id = model.id else {
            throw Abort(.notFound)
        }
        configs.removeAll(where: { $0.id == id })
    }

    func all() async throws -> [RemoteConfigModel] {
        configs
    }

    func deleteByKey(_ key: String) async throws {
        configs.removeAll(where: { $0.key == key })
    }

    func count() async throws -> Int {
        configs.count
    }

    func delete(id: UUID) async throws {
        configs.removeAll(where: { $0.id == id })
    }

    func reset() async {
        configs.removeAll()
    }

    nonisolated func `for`(_ req: Request) -> TestRemoteConfigRepository {
        return self
    }
}
