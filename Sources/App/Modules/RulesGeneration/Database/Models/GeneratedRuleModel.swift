import Fluent
import Vapor

/// Database representation of a generated rules summary persisted for reuse.
final class GeneratedRuleModel: @unchecked Sendable, DatabaseModelInterface {
    typealias Module = RulesGenerationModule

    static var schema: String { "generated_rules" }

    @ID()
    var id: UUID?

    @Field(key: FieldKeys.v2.originalTitle)
    var originalTitle: String

    @Field(key: FieldKeys.v2.sanitizedTitle)
    var sanitizedTitle: String

    @Field(key: FieldKeys.v2.cacheKey)
    var cacheKey: String

    @Field(key: FieldKeys.v2.title)
    var title: String

    @Field(key: FieldKeys.v2.playerCount)
    var playerCount: String

    @Field(key: FieldKeys.v2.playTime)
    var playTime: String

    @Field(key: FieldKeys.v2.complexity)
    var complexity: Double

    @Field(key: FieldKeys.v2.recommendedAge)
    var recommendedAge: String

    @Field(key: FieldKeys.v2.mechanics)
    var mechanics: [String]

    @Field(key: FieldKeys.v2.summary)
    var summary: String

    @Field(key: FieldKeys.v2.winCondition)
    var winCondition: String

    @Field(key: FieldKeys.v2.endGameTrigger)
    var endGameTrigger: String

    @Field(key: FieldKeys.v2.scoringCategories)
    var scoringCategories: [RulesSummary.Response.ScoringCategory]

    @Field(key: FieldKeys.v2.components)
    var components: [RulesSummary.Response.Component]

    @Field(key: FieldKeys.v2.initialSetup)
    var initialSetup: [RulesSummary.Response.SetupStep]

    @Field(key: FieldKeys.v2.turnStructure)
    var turnStructure: RulesSummary.Response.TurnStructure

    @Field(key: FieldKeys.v2.firstRoundGuide)
    var firstRoundGuide: [RulesSummary.Response.GuideStep]

    @Field(key: FieldKeys.v2.glossary)
    var glossary: [RulesSummary.Response.GlossaryTerm]

    @Field(key: FieldKeys.v2.deepDive)
    var deepDive: [String]

    @Field(key: FieldKeys.v2.commonMistakes)
    var commonMistakes: [RulesSummary.Response.CommonMistake]

    @Field(key: FieldKeys.v2.quickReference)
    var quickReference: RulesSummary.Response.QuickReference

    @Field(key: FieldKeys.v2.resourcesVideoLinks)
    var resourcesVideoLinks: [String]

    @Field(key: FieldKeys.v2.resourcesWebLinks)
    var resourcesWebLinks: [String]

    @Field(key: FieldKeys.v2.confidence)
    var confidence: Int

    @Field(key: FieldKeys.v2.notes)
    var notes: String

    @Timestamp(key: FieldKeys.v2.lastAccessedAt, on: .none)
    var lastAccessedAt: Date?

    @Timestamp(key: FieldKeys.v2.createdAt, on: .create)
    var createdAt: Date?

    @Timestamp(key: FieldKeys.v2.updatedAt, on: .update)
    var updatedAt: Date?

    @Timestamp(key: FieldKeys.v2.deletedAt, on: .delete)
    var deletedAt: Date?

    init() { }

    init(
        id: UUID? = nil,
        originalTitle: String,
        sanitizedTitle: String,
        cacheKey: String,
        title: String,
        playerCount: String,
        playTime: String,
        complexity: Double,
        recommendedAge: String,
        mechanics: [String],
        summary: String,
        winCondition: String,
        endGameTrigger: String,
        scoringCategories: [RulesSummary.Response.ScoringCategory],
        components: [RulesSummary.Response.Component],
        initialSetup: [RulesSummary.Response.SetupStep],
        turnStructure: RulesSummary.Response.TurnStructure,
        firstRoundGuide: [RulesSummary.Response.GuideStep],
        glossary: [RulesSummary.Response.GlossaryTerm],
        deepDive: [String],
        commonMistakes: [RulesSummary.Response.CommonMistake],
        quickReference: RulesSummary.Response.QuickReference,
        resourcesVideoLinks: [String],
        resourcesWebLinks: [String],
        confidence: Int,
        notes: String,
        lastAccessedAt: Date? = nil
    ) {
        self.id = id
        self.originalTitle = originalTitle
        self.sanitizedTitle = sanitizedTitle
        self.cacheKey = cacheKey
        self.title = title
        self.playerCount = playerCount
        self.playTime = playTime
        self.complexity = complexity
        self.recommendedAge = recommendedAge
        self.mechanics = mechanics
        self.summary = summary
        self.winCondition = winCondition
        self.endGameTrigger = endGameTrigger
        self.scoringCategories = scoringCategories
        self.components = components
        self.initialSetup = initialSetup
        self.turnStructure = turnStructure
        self.firstRoundGuide = firstRoundGuide
        self.glossary = glossary
        self.deepDive = deepDive
        self.commonMistakes = commonMistakes
        self.quickReference = quickReference
        self.resourcesVideoLinks = resourcesVideoLinks
        self.resourcesWebLinks = resourcesWebLinks
        self.confidence = confidence
        self.notes = notes
        self.lastAccessedAt = lastAccessedAt
    }
}

extension GeneratedRuleModel {
    enum FieldKeys {
        enum v2 {
            static var originalTitle: FieldKey { "game_title_original" }
            static var sanitizedTitle: FieldKey { "game_title_sanitized" }
            static var cacheKey: FieldKey { "cache_key" }
            static var title: FieldKey { "title" }
            static var playerCount: FieldKey { "player_count" }
            static var playTime: FieldKey { "play_time" }
            static var complexity: FieldKey { "complexity" }
            static var recommendedAge: FieldKey { "recommended_age" }
            static var mechanics: FieldKey { "mechanics" }
            static var summary: FieldKey { "summary" }
            static var winCondition: FieldKey { "win_condition" }
            static var endGameTrigger: FieldKey { "end_game_trigger" }
            static var scoringCategories: FieldKey { "scoring_categories" }
            static var components: FieldKey { "components" }
            static var initialSetup: FieldKey { "initial_setup" }
            static var turnStructure: FieldKey { "turn_structure" }
            static var firstRoundGuide: FieldKey { "first_round_guide" }
            static var glossary: FieldKey { "glossary" }
            static var deepDive: FieldKey { "deep_dive" }
            static var commonMistakes: FieldKey { "common_mistakes" }
            static var quickReference: FieldKey { "quick_reference" }
            static var resourcesVideoLinks: FieldKey { "resources_video_links" }
            static var resourcesWebLinks: FieldKey { "resources_web_links" }
            static var confidence: FieldKey { "confidence" }
            static var notes: FieldKey { "notes" }
            static var lastAccessedAt: FieldKey { "last_accessed_at" }
            static var createdAt: FieldKey { "created_at" }
            static var updatedAt: FieldKey { "updated_at" }
            static var deletedAt: FieldKey { "deleted_at" }
        }
    }
}
