import Fluent
import Vapor

enum RulesGenerationMigrations {
    struct v1: AsyncMigration {
        func prepare(on db: Database) async throws {
            try await db.schema(GeneratedRuleModel.schema)
                .id()
                .field(GeneratedRuleModel.FieldKeys.v1.originalTitle, .string, .required)
                .field(GeneratedRuleModel.FieldKeys.v1.sanitizedTitle, .string, .required)
                .field(GeneratedRuleModel.FieldKeys.v1.cacheKey, .string, .required)
                .field(GeneratedRuleModel.FieldKeys.v1.title, .string, .required)
                .field(GeneratedRuleModel.FieldKeys.v1.playerCount, .string, .required)
                .field(GeneratedRuleModel.FieldKeys.v1.playTime, .string, .required)
                .field(GeneratedRuleModel.FieldKeys.v1.summary, .string, .required)
                .field(GeneratedRuleModel.FieldKeys.v1.initialSetup, .array(of: .string), .required)
                .field(GeneratedRuleModel.FieldKeys.v1.firstRoundGuide, .array(of: .string), .required)
                .field(GeneratedRuleModel.FieldKeys.v1.winCondition, .string, .required)
                .field(GeneratedRuleModel.FieldKeys.v1.deepDive, .array(of: .string), .required)
                .field(GeneratedRuleModel.FieldKeys.v1.resourcesVideoLinks, .array(of: .string), .required)
                .field(GeneratedRuleModel.FieldKeys.v1.resourcesWebLinks, .array(of: .string), .required)
                .field(GeneratedRuleModel.FieldKeys.v1.confidence, .int, .required, .sql(.default(0)))
                .field(GeneratedRuleModel.FieldKeys.v1.notes, .string, .required)
                .field(GeneratedRuleModel.FieldKeys.v1.lastAccessedAt, .datetime)
                .field(GeneratedRuleModel.FieldKeys.v1.createdAt, .datetime)
                .field(GeneratedRuleModel.FieldKeys.v1.updatedAt, .datetime)
                .field(GeneratedRuleModel.FieldKeys.v1.deletedAt, .datetime)
                .unique(on: GeneratedRuleModel.FieldKeys.v1.sanitizedTitle)
                .unique(on: GeneratedRuleModel.FieldKeys.v1.cacheKey)
                .create()
        }

        func revert(on db: Database) async throws {
            try await db.schema(GeneratedRuleModel.schema).delete()
        }
    }
}
