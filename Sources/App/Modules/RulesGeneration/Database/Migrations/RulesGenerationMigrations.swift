import Fluent
import Vapor

enum RulesGenerationMigrations {
    /// v2 migration: drops and recreates the generated_rules table with the expanded schema.
    /// This replaces v1 — the DB is flushed on deploy so no incremental migration is needed.
    struct v2: AsyncMigration {
        func prepare(on db: Database) async throws {
            // Drop old table if it exists (clean slate deploy)
            // Use try? to silently ignore if table doesn't exist (e.g., fresh SQLite in tests)
            try? await db.schema(GeneratedRuleModel.schema).delete()

            try await db.schema(GeneratedRuleModel.schema)
                .id()
                .field(GeneratedRuleModel.FieldKeys.v2.originalTitle, .string, .required)
                .field(GeneratedRuleModel.FieldKeys.v2.sanitizedTitle, .string, .required)
                .field(GeneratedRuleModel.FieldKeys.v2.cacheKey, .string, .required)
                .field(GeneratedRuleModel.FieldKeys.v2.title, .string, .required)
                .field(GeneratedRuleModel.FieldKeys.v2.playerCount, .string, .required)
                .field(GeneratedRuleModel.FieldKeys.v2.playTime, .string, .required)
                .field(GeneratedRuleModel.FieldKeys.v2.complexity, .double, .required)
                .field(GeneratedRuleModel.FieldKeys.v2.recommendedAge, .string, .required)
                .field(GeneratedRuleModel.FieldKeys.v2.mechanics, .array(of: .string), .required)
                .field(GeneratedRuleModel.FieldKeys.v2.summary, .string, .required)
                .field(GeneratedRuleModel.FieldKeys.v2.winCondition, .string, .required)
                .field(GeneratedRuleModel.FieldKeys.v2.endGameTrigger, .string, .required)
                .field(GeneratedRuleModel.FieldKeys.v2.scoringCategories, .json, .required)
                .field(GeneratedRuleModel.FieldKeys.v2.components, .json, .required)
                .field(GeneratedRuleModel.FieldKeys.v2.initialSetup, .json, .required)
                .field(GeneratedRuleModel.FieldKeys.v2.turnStructure, .json, .required)
                .field(GeneratedRuleModel.FieldKeys.v2.firstRoundGuide, .json, .required)
                .field(GeneratedRuleModel.FieldKeys.v2.glossary, .json, .required)
                .field(GeneratedRuleModel.FieldKeys.v2.deepDive, .array(of: .string), .required)
                .field(GeneratedRuleModel.FieldKeys.v2.commonMistakes, .json, .required)
                .field(GeneratedRuleModel.FieldKeys.v2.quickReference, .json, .required)
                .field(GeneratedRuleModel.FieldKeys.v2.resourcesVideoLinks, .array(of: .string), .required)
                .field(GeneratedRuleModel.FieldKeys.v2.resourcesWebLinks, .array(of: .string), .required)
                .field(GeneratedRuleModel.FieldKeys.v2.confidence, .int, .required, .sql(.default(0)))
                .field(GeneratedRuleModel.FieldKeys.v2.notes, .string, .required)
                .field(GeneratedRuleModel.FieldKeys.v2.lastAccessedAt, .datetime)
                .field(GeneratedRuleModel.FieldKeys.v2.createdAt, .datetime)
                .field(GeneratedRuleModel.FieldKeys.v2.updatedAt, .datetime)
                .field(GeneratedRuleModel.FieldKeys.v2.deletedAt, .datetime)
                .unique(on: GeneratedRuleModel.FieldKeys.v2.sanitizedTitle)
                .unique(on: GeneratedRuleModel.FieldKeys.v2.cacheKey)
                .create()
        }

        func revert(on db: Database) async throws {
            try await db.schema(GeneratedRuleModel.schema).delete()
        }
    }
}
