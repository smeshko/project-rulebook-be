import Fluent
import Vapor

enum RemoteConfigMigrations {

    struct v1: AsyncMigration {

        func prepare(on db: Database) async throws {
            try await db.schema(RemoteConfigModel.schema)
                .id()
                .field(RemoteConfigModel.FieldKeys.v1.key, .string, .required)
                .field(RemoteConfigModel.FieldKeys.v1.value, .string, .required)
                .field(RemoteConfigModel.FieldKeys.v1.valueType, .string, .required)
                .field(RemoteConfigModel.FieldKeys.v1.createdAt, .datetime)
                .field(RemoteConfigModel.FieldKeys.v1.updatedAt, .datetime)
                .unique(on: RemoteConfigModel.FieldKeys.v1.key)
                .create()
        }

        func revert(on db: Database) async throws {
            try await db.schema(RemoteConfigModel.schema).delete()
        }
    }

    /// Seeds default configuration values for development.
    struct seed: AsyncMigration {

        func prepare(on db: Database) async throws {
            // Feature flags
            let enablePaywall = RemoteConfigModel.create(key: "featureFlags.enablePaywall", boolValue: true)
            try await enablePaywall.create(on: db)

            // Settings
            let maxRetries = RemoteConfigModel.create(key: "settings.maxRetries", intValue: 3)
            try await maxRetries.create(on: db)
        }

        func revert(on db: Database) async throws {
            try await RemoteConfigModel.query(on: db)
                .filter(\.$key ~~ ["featureFlags.enablePaywall", "settings.maxRetries"])
                .delete()
        }
    }
}
