import Fluent
import Vapor

enum CacheAdminMigrations {
    struct v1: AsyncMigration {
        func prepare(on db: Database) async throws {
            try await db.schema(GameRequestStats.schema)
                .id()
                .field(GameRequestStats.FieldKeys.v1.sanitizedGameTitle, .string, .required)
                .field(GameRequestStats.FieldKeys.v1.requestCount, .int, .required, .sql(.default(0)))
                .field(GameRequestStats.FieldKeys.v1.lastRequestedAt, .datetime)
                .field(GameRequestStats.FieldKeys.v1.createdAt, .datetime)
                .field(GameRequestStats.FieldKeys.v1.updatedAt, .datetime)
                .unique(on: GameRequestStats.FieldKeys.v1.sanitizedGameTitle)
                .create()
        }

        func revert(on db: Database) async throws {
            try await db.schema(GameRequestStats.schema).delete()
        }
    }
}
