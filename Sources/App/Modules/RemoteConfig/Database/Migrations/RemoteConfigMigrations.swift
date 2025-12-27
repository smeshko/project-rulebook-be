import Fluent
import Vapor

enum RemoteConfigMigrations {
    static func v1() -> any AsyncMigration {
        RemoteConfigMigrations_v1()
    }
}

struct RemoteConfigMigrations_v1: AsyncMigration {
    func prepare(on db: Database) async throws {
        try await db.schema(RemoteConfigModel.schema)
            .id()
            .field(RemoteConfigModel.FieldKeys.v1.key, .string, .required)
            .field(RemoteConfigModel.FieldKeys.v1.value, .string, .required)
            .field(RemoteConfigModel.FieldKeys.v1.valueType, .string, .required)
            .field(RemoteConfigModel.FieldKeys.v1.version, .int, .required)
            .field(RemoteConfigModel.FieldKeys.v1.isActive, .bool, .required)
            .field(RemoteConfigModel.FieldKeys.v1.createdAt, .datetime)
            .field(RemoteConfigModel.FieldKeys.v1.updatedAt, .datetime)
            .unique(on: RemoteConfigModel.FieldKeys.v1.key)
            .create()
    }

    func revert(on db: Database) async throws {
        try await db.schema(RemoteConfigModel.schema).delete()
    }
}
