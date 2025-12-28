import Fluent
import Vapor

enum ConfigMigrations {

    struct v1: AsyncMigration {

        func prepare(on db: Database) async throws {
            try await db.schema(ConfigValueModel.schema)
                .id()
                .field(ConfigValueModel.FieldKeys.v1.key, .string, .required)
                .field(ConfigValueModel.FieldKeys.v1.value, .string, .required)
                .field(ConfigValueModel.FieldKeys.v1.valueType, .string, .required)
                .field(ConfigValueModel.FieldKeys.v1.createdAt, .datetime)
                .field(ConfigValueModel.FieldKeys.v1.updatedAt, .datetime)
                .unique(on: ConfigValueModel.FieldKeys.v1.key)
                .create()
        }

        func revert(on db: Database) async throws {
            try await db.schema(ConfigValueModel.schema).delete()
        }
    }
}
