@testable import App
import Vapor

actor TestRemoteConfigRepository: RemoteConfigRepository, TestRepository {
    var configs: [RemoteConfigModel]

    var entities: [RemoteConfigModel] {
        get { configs }
        set { configs = newValue }
    }

    init(configs: [RemoteConfigModel] = []) {
        self.configs = configs
    }

    typealias Model = RemoteConfigModel

    func create(_ model: RemoteConfigModel) async throws {
        // Simulate unique key constraint
        if configs.contains(where: { $0.key == model.key }) {
            throw Abort(.conflict, reason: "UNIQUE constraint failed: remote_configs.key")
        }
        model.id = model.id ?? UUID()
        configs.append(model)
    }

    func delete(id: UUID) async throws {
        configs.removeAll(where: { $0.id == id })
    }

    func find(id: UUID) async throws -> RemoteConfigModel? {
        configs.first(where: { $0.id == id })
    }

    func find(key: String) async throws -> RemoteConfigModel? {
        configs.first(where: { $0.key == key })
    }

    func all() async throws -> [RemoteConfigModel] {
        configs
    }

    func update(_ model: RemoteConfigModel) async throws {
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

    nonisolated func `for`(_ req: Request) -> TestRemoteConfigRepository {
        return self
    }
}
