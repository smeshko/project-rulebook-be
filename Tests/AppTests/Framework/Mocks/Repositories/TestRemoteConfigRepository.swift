@testable import App
import Vapor
import Fluent

actor TestRemoteConfigRepository: RemoteConfigRepository, TestRepository {
    var entries: [RemoteConfigEntryModel]

    var entities: [RemoteConfigEntryModel] {
        get { entries }
        set { entries = newValue }
    }

    init(entries: [RemoteConfigEntryModel] = []) {
        self.entries = entries
    }

    typealias Model = RemoteConfigEntryModel

    func find(id: UUID) async throws -> RemoteConfigEntryModel? {
        entries.first(where: { $0.id == id })
    }

    func find(key: String) async throws -> RemoteConfigEntryModel? {
        entries.first(where: { $0.key == key })
    }

    func all() async throws -> [RemoteConfigEntryModel] {
        entries.sorted { $0.key < $1.key }
    }

    func create(_ model: RemoteConfigEntryModel) async throws {
        if entries.contains(where: { $0.key == model.key }) {
            throw Abort(.conflict, reason: "UNIQUE constraint failed: remote_config_entries.key")
        }
        model.id = model.id ?? UUID()
        model.createdAt = Date()
        entries.append(model)
    }

    func update(_ model: RemoteConfigEntryModel) async throws {
        guard let id = model.id,
              let index = entries.firstIndex(where: { $0.id == id }) else {
            throw Abort(.notFound)
        }
        model.updatedAt = Date()
        entries[index] = model
    }

    func delete(_ model: RemoteConfigEntryModel) async throws {
        guard let id = model.id else {
            throw Abort(.badRequest)
        }
        entries.removeAll(where: { $0.id == id })
    }

    func delete(id: UUID) async throws {
        entries.removeAll(where: { $0.id == id })
    }

    func count() async throws -> Int {
        entries.count
    }

    func reset() async {
        entries.removeAll()
    }

    nonisolated func `for`(_ req: Request) -> TestRemoteConfigRepository {
        return self
    }
}
