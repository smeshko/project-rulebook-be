import Fluent
import Vapor

enum ConfigMigrations {

    struct v1: AsyncMigration {

        func prepare(on db: Database) async throws {
            try await db.schema(ConfigEntryModel.schema)
                .id()
                .field(ConfigEntryModel.FieldKeys.v1.key, .string, .required)
                .field(ConfigEntryModel.FieldKeys.v1.value, .string, .required)
                .field(ConfigEntryModel.FieldKeys.v1.valueType, .string, .required)
                .field(ConfigEntryModel.FieldKeys.v1.category, .string, .required)
                .field(ConfigEntryModel.FieldKeys.v1.createdAt, .datetime)
                .field(ConfigEntryModel.FieldKeys.v1.updatedAt, .datetime)
                .unique(on: ConfigEntryModel.FieldKeys.v1.key)
                .create()
        }

        func revert(on db: Database) async throws {
            try await db.schema(ConfigEntryModel.schema).delete()
        }
    }
}
