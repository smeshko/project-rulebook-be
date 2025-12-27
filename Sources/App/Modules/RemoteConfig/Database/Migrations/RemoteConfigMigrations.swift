import Fluent
import Vapor

enum RemoteConfigMigrations {
    struct v1: AsyncMigration {
        func prepare(on database: Database) async throws {
            // Create enum type for config value types
            let valueTypeEnum = try await database.enum("config_value_type")
                .case("boolean")
                .case("integer")
                .case("string")
                .case("json")
                .create()

            // Create remote_configs table
            try await database.schema(RemoteConfigModel.schema)
                .id()
                .field(RemoteConfigModel.FieldKeys.v1.key, .string, .required)
                .field(RemoteConfigModel.FieldKeys.v1.value, .string, .required)
                .field(RemoteConfigModel.FieldKeys.v1.valueType, valueTypeEnum, .required)
                .field(RemoteConfigModel.FieldKeys.v1.createdAt, .datetime)
                .field(RemoteConfigModel.FieldKeys.v1.updatedAt, .datetime)
                .unique(on: RemoteConfigModel.FieldKeys.v1.key)
                .create()
        }

        func revert(on database: Database) async throws {
            try await database.schema(RemoteConfigModel.schema).delete()
            try await database.enum("config_value_type").delete()
        }
    }
}
