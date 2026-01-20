import Fluent
import Vapor

enum RemoteConfigMigrations {

    struct v1: AsyncMigration {

        func prepare(on db: Database) async throws {
            try await db.schema(RemoteConfigEntryModel.schema)
                .id()
                .field(RemoteConfigEntryModel.FieldKeys.v1.key, .string, .required)
                .field(RemoteConfigEntryModel.FieldKeys.v1.value, .string, .required)
                .field(RemoteConfigEntryModel.FieldKeys.v1.valueType, .string, .required)
                .field(RemoteConfigEntryModel.FieldKeys.v1.description, .string)
                .field(RemoteConfigEntryModel.FieldKeys.v1.createdAt, .datetime)
                .field(RemoteConfigEntryModel.FieldKeys.v1.updatedAt, .datetime)
                .unique(on: RemoteConfigEntryModel.FieldKeys.v1.key)
                .create()
        }

        func revert(on db: Database) async throws {
            try await db.schema(RemoteConfigEntryModel.schema).delete()
        }
    }
}
