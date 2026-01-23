import Fluent
import Vapor

enum RemoteConfigMigrations {

    struct v1: AsyncMigration {

        func prepare(on db: Database) async throws {
            // Create enum types for PostgreSQL
            try await db.enum("remote_config_value_type")
                .case("boolean")
                .case("integer")
                .case("string")
                .create()

            try await db.enum("remote_config_category")
                .case("featureFlag")
                .case("setting")
                .create()

            let valueTypeEnum = try await db.enum("remote_config_value_type").read()
            let categoryEnum = try await db.enum("remote_config_category").read()

            try await db.schema(RemoteConfigModel.schema)
                .id()
                .field(RemoteConfigModel.FieldKeys.v1.key, .string, .required)
                .field(RemoteConfigModel.FieldKeys.v1.value, .string, .required)
                .field(RemoteConfigModel.FieldKeys.v1.valueType, valueTypeEnum, .required)
                .field(RemoteConfigModel.FieldKeys.v1.category, categoryEnum, .required)
                .field(RemoteConfigModel.FieldKeys.v1.createdAt, .datetime)
                .field(RemoteConfigModel.FieldKeys.v1.updatedAt, .datetime)
                .unique(on: RemoteConfigModel.FieldKeys.v1.key)
                .create()
        }

        func revert(on db: Database) async throws {
            try await db.schema(RemoteConfigModel.schema).delete()
            try await db.enum("remote_config_value_type").delete()
            try await db.enum("remote_config_category").delete()
        }
    }

    struct seed: AsyncMigration {

        func prepare(on db: Database) async throws {
            let configs = [
                RemoteConfigModel(
                    key: "enablePaywall",
                    value: "true",
                    valueType: .boolean,
                    category: .featureFlag
                ),
                RemoteConfigModel(
                    key: "maxRetries",
                    value: "3",
                    valueType: .integer,
                    category: .setting
                ),
            ]

            for config in configs {
                try await config.create(on: db)
            }
        }

        func revert(on db: Database) async throws {
            try await RemoteConfigModel.query(on: db).delete()
        }
    }
}
