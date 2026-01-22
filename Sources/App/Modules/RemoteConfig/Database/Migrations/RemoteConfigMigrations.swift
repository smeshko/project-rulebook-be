import Fluent
import Vapor

enum RemoteConfigMigrations {

    struct v1: AsyncMigration {

        func prepare(on db: Database) async throws {
            let valueType = try await db.enum("config_value_type")
                .case("boolean")
                .case("integer")
                .case("string")
                .create()

            let category = try await db.enum("config_category")
                .case("feature_flags")
                .case("settings")
                .create()

            try await db.schema(RemoteConfigModel.schema)
                .id()
                .field(RemoteConfigModel.FieldKeys.v1.key, .string, .required)
                .field(RemoteConfigModel.FieldKeys.v1.value, .string, .required)
                .field(RemoteConfigModel.FieldKeys.v1.valueType, valueType, .required)
                .field(RemoteConfigModel.FieldKeys.v1.category, category, .required)
                .field(RemoteConfigModel.FieldKeys.v1.createdAt, .datetime)
                .field(RemoteConfigModel.FieldKeys.v1.updatedAt, .datetime)
                .unique(on: RemoteConfigModel.FieldKeys.v1.key)
                .create()
        }

        func revert(on db: Database) async throws {
            try await db.schema(RemoteConfigModel.schema).delete()
            try await db.enum("config_value_type").delete()
            try await db.enum("config_category").delete()
        }
    }

    struct seed: AsyncMigration {

        func prepare(on db: Database) async throws {
            let enablePaywall = RemoteConfigModel(
                key: "enablePaywall",
                value: "true",
                valueType: .boolean,
                category: .featureFlags
            )
            try await enablePaywall.create(on: db)

            let maxRetries = RemoteConfigModel(
                key: "maxRetries",
                value: "3",
                valueType: .integer,
                category: .settings
            )
            try await maxRetries.create(on: db)
        }

        func revert(on db: Database) async throws {
            try await RemoteConfigModel.query(on: db).delete()
        }
    }
}
