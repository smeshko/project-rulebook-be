import Fluent
import Vapor

enum WaitlistMigrations {

    struct v1: AsyncMigration {

        func prepare(on db: Database) async throws {
            try await db.schema(WaitlistEntryModel.schema)
                .id()
                .field(WaitlistEntryModel.FieldKeys.v1.email, .string, .required)
                .field(WaitlistEntryModel.FieldKeys.v1.unsubscribeToken, .string, .required)
                .field(WaitlistEntryModel.FieldKeys.v1.createdAt, .datetime)
                .field(WaitlistEntryModel.FieldKeys.v1.notifiedAt, .datetime)
                .unique(on: WaitlistEntryModel.FieldKeys.v1.email)
                .unique(on: WaitlistEntryModel.FieldKeys.v1.unsubscribeToken)
                .create()
        }

        func revert(on db: Database) async throws {
            try await db.schema(WaitlistEntryModel.schema).delete()
        }
    }
}
