@testable import App
import Vapor

final class TestConfigRepository: ConfigRepository, @unchecked Sendable {
    typealias Model = ConfigEntryModel

    private var entries: [UUID: ConfigEntryModel] = [:]

    func find(id: UUID) async throws -> ConfigEntryModel? {
        entries[id]
    }

    func find(key: String) async throws -> ConfigEntryModel? {
        entries.values.first { $0.key == key }
    }

    func findAll() async throws -> [ConfigEntryModel] {
        Array(entries.values).sorted { $0.key < $1.key }
    }

    func create(_ model: ConfigEntryModel) async throws {
        if model.id == nil {
            model.id = UUID()
        }
        entries[model.id!] = model
    }

    func update(_ model: ConfigEntryModel) async throws {
        guard let id = model.id else { return }
        entries[id] = model
    }

    func delete(_ model: ConfigEntryModel) async throws {
        guard let id = model.id else { return }
        entries.removeValue(forKey: id)
    }

    func delete(id: UUID) async throws {
        entries.removeValue(forKey: id)
    }

    func count() async throws -> Int {
        entries.count
    }

    func `for`(_ req: Request) -> Self {
        self
    }

    // MARK: - Test Helpers

    func reset() async {
        entries.removeAll()
    }

    func seed() async throws {
        // Seed initial config entries like the production migration
        let enableNewScanner = ConfigEntryModel(
            key: "enableNewScanner",
            value: "true",
            type: "boolean"
        )
        let showPromotion = ConfigEntryModel(
            key: "showPromotion",
            value: "false",
            type: "boolean"
        )
        let maxRetries = ConfigEntryModel(
            key: "maxRetries",
            value: "3",
            type: "integer"
        )
        let cacheTimeoutSeconds = ConfigEntryModel(
            key: "cacheTimeoutSeconds",
            value: "300",
            type: "integer"
        )

        try await create(enableNewScanner)
        try await create(showPromotion)
        try await create(maxRetries)
        try await create(cacheTimeoutSeconds)
    }
}
