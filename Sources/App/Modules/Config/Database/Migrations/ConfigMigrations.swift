import Fluent
import Vapor

enum ConfigMigrations {

    struct v1: AsyncMigration {

        func prepare(on db: Database) async throws {
            try await db.schema(ConfigEntryModel.schema)
                .id()
                .field(ConfigEntryModel.FieldKeys.v1.key, .string, .required)
                .field(ConfigEntryModel.FieldKeys.v1.value, .string, .required)
                .field(ConfigEntryModel.FieldKeys.v1.type, .string, .required)
                .field(ConfigEntryModel.FieldKeys.v1.createdAt, .datetime)
                .field(ConfigEntryModel.FieldKeys.v1.updatedAt, .datetime)
                .unique(on: ConfigEntryModel.FieldKeys.v1.key)
                .create()
        }

        func revert(on db: Database) async throws {
            try await db.schema(ConfigEntryModel.schema).delete()
        }
    }

    /// Seed initial feature flags and settings
    struct v1Seed: AsyncMigration {

        func prepare(on db: Database) async throws {
            // Feature flags
            let enableNewScanner = ConfigEntryModel(
                key: "enableNewScanner",
                value: "true",
                type: "boolean"
            )

            let showPromotion = ConfigEntryModel(
                key: "showPromotion",
                value: "false",
                type: "boolean"
            )

            // Settings
            let maxRetries = ConfigEntryModel(
                key: "maxRetries",
                value: "3",
                type: "integer"
            )

            let cacheTimeoutSeconds = ConfigEntryModel(
                key: "cacheTimeoutSeconds",
                value: "300",
                type: "integer"
            )

            try await enableNewScanner.create(on: db)
            try await showPromotion.create(on: db)
            try await maxRetries.create(on: db)
            try await cacheTimeoutSeconds.create(on: db)
        }

        func revert(on db: Database) async throws {
            try await ConfigEntryModel.query(on: db)
                .filter(\.$key ~~ ["enableNewScanner", "showPromotion", "maxRetries", "cacheTimeoutSeconds"])
                .delete()
        }
    }
}
