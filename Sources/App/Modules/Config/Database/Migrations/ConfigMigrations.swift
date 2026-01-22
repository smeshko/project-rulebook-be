import Fluent
import Vapor

enum ConfigMigrations {

    struct v1: AsyncMigration {

        func prepare(on db: Database) async throws {
            // Create enum types for PostgreSQL
            let valueTypeEnum = try await db.enum("config_value_type")
                .case("boolean")
                .case("integer")
                .case("string")
                .create()

            let categoryEnum = try await db.enum("config_category")
                .case("feature_flag")
                .case("setting")
                .create()

            try await db.schema(ConfigEntryModel.schema)
                .id()
                .field(ConfigEntryModel.FieldKeys.v1.key, .string, .required)
                .field(ConfigEntryModel.FieldKeys.v1.value, .string, .required)
                .field(ConfigEntryModel.FieldKeys.v1.valueType, valueTypeEnum, .required)
                .field(ConfigEntryModel.FieldKeys.v1.category, categoryEnum, .required)
                .field(ConfigEntryModel.FieldKeys.v1.createdAt, .datetime)
                .field(ConfigEntryModel.FieldKeys.v1.updatedAt, .datetime)
                .unique(on: ConfigEntryModel.FieldKeys.v1.key)
                .create()
        }

        func revert(on db: Database) async throws {
            try await db.schema(ConfigEntryModel.schema).delete()
            try await db.enum("config_category").delete()
            try await db.enum("config_value_type").delete()
        }
    }
}
