@testable import App
import Foundation
import Vapor

actor TestRemoteConfigRepository: RemoteConfigRepository, TestRepository {
    private var entries: [RemoteConfigEntryModel]

    init(entries: [RemoteConfigEntryModel] = []) {
        self.entries = entries
    }

    typealias Model = RemoteConfigEntryModel

    func findAll() async throws -> [RemoteConfigEntryModel] {
        entries.sorted { $0.key < $1.key }
    }

    func find(key: String) async throws -> RemoteConfigEntryModel? {
        entries.first { $0.key == key }
    }

    func find(id: UUID) async throws -> RemoteConfigEntryModel? {
        entries.first { $0.id == id }
    }

    func create(_ model: RemoteConfigEntryModel) async throws {
        if entries.contains(where: { $0.key == model.key }) {
            throw Abort(.conflict, reason: "UNIQUE constraint failed: remote_config_entries.key")
        }
        model.id = model.id ?? UUID()
        model.createdAt = Date()
        model.updatedAt = Date()
        entries.append(model)
    }

    func update(_ model: RemoteConfigEntryModel) async throws {
        guard let identifier = model.id,
              let index = entries.firstIndex(where: { $0.id == identifier }) else {
            throw Abort(.notFound)
        }
        model.updatedAt = Date()
        entries[index] = model
    }

    func delete(_ model: RemoteConfigEntryModel) async throws {
        guard let identifier = model.id else {
            throw Abort(.notFound)
        }
        entries.removeAll { $0.id == identifier }
    }

    func delete(id: UUID) async throws {
        entries.removeAll { $0.id == id }
    }

    func count() async throws -> Int {
        entries.count
    }

    func reset() async {
        entries.removeAll()
    }

    nonisolated func `for`(_ req: Request) -> TestRemoteConfigRepository {
        self
    }
}
