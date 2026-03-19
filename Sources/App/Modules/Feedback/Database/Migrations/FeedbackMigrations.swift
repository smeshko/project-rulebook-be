import Fluent
import Vapor

enum FeedbackMigrations {

    struct v1: AsyncMigration {

        func prepare(on db: Database) async throws {
            try await db.enum("feedback_type")
                .case("incorrect")
                .case("incomplete")
                .case("other")
                .create()

            try await db.enum("feedback_status")
                .case("pending")
                .case("reviewed")
                .case("resolved")
                .create()

            let feedbackTypeEnum = try await db.enum("feedback_type").read()
            let feedbackStatusEnum = try await db.enum("feedback_status").read()

            try await db.schema(FeedbackModel.schema)
                .id()
                .field(FeedbackModel.FieldKeys.v1.rulesSummaryId, .uuid,
                       .references(GeneratedRuleModel.schema, "id", onDelete: .setNull))
                .field(FeedbackModel.FieldKeys.v1.gameTitle, .string, .required)
                .field(FeedbackModel.FieldKeys.v1.feedbackType, feedbackTypeEnum, .required)
                .field(FeedbackModel.FieldKeys.v1.description, .string, .required)
                .field(FeedbackModel.FieldKeys.v1.userContact, .string)
                .field(FeedbackModel.FieldKeys.v1.status, feedbackStatusEnum, .required)
                .field(FeedbackModel.FieldKeys.v1.createdAt, .datetime)
                .create()
        }

        func revert(on db: Database) async throws {
            try await db.schema(FeedbackModel.schema).delete()
            try await db.enum("feedback_type").delete()
            try await db.enum("feedback_status").delete()
        }
    }
}
