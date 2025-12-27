import Fluent
import Vapor

enum RemoteConfigMigrations {
    static func v1() -> any AsyncMigration {
        RemoteConfigMigrations_v1()
    }
}

private struct RemoteConfigMigrations_v1: AsyncMigration {
    func prepare(on db: Database) async throws {
        // Migration will be implemented in Task 2
    }

    func revert(on db: Database) async throws {
        // Revert will be implemented in Task 2
    }
}
