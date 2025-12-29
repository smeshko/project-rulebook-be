@testable import App
import Foundation
import Vapor

actor TestConfigRepository: ConfigRepository, TestRepository {
    private var entries: [ConfigEntryModel]

    init(entries: [ConfigEntryModel] = []) {
        self.entries = entries
    }

    typealias Model = ConfigEntryModel

    func find(id: UUID) async throws -> ConfigEntryModel? {
        entries.first { $0.id == id }
    }

    func find(key: String) async throws -> ConfigEntryModel? {
        entries.first { $0.key == key }
    }

    func findAll() async throws -> [ConfigEntryModel] {
        entries.sorted { $0.key < $1.key }
    }

    func create(_ model: ConfigEntryModel) async throws {
        if entries.contains(where: { $0.key == model.key }) {
            throw Abort(.conflict, reason: "UNIQUE constraint failed: config_entries.key")
        }
        model.id = model.id ?? UUID()
        entries.append(model)
    }

    func update(_ model: ConfigEntryModel) async throws {
        guard let identifier = model.id,
              let index = entries.firstIndex(where: { $0.id == identifier }) else {
            throw Abort(.notFound)
        }
        entries[index] = model
    }

    func delete(_ model: ConfigEntryModel) async throws {
        entries.removeAll { $0.id == model.id }
    }

    func delete(key: String) async throws {
        entries.removeAll { $0.key == key }
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

    nonisolated func `for`(_ req: Request) -> TestConfigRepository {
        self
    }
}
