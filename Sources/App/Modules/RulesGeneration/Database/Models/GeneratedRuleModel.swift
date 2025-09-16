import Fluent
import Vapor

/// Database representation of a generated rules summary persisted for reuse.
final class GeneratedRuleModel: @unchecked Sendable, DatabaseModelInterface {
    typealias Module = RulesGenerationModule

    static var schema: String { "generated_rules" }

    @ID()
    var id: UUID?

    @Field(key: FieldKeys.v1.originalTitle)
    var originalTitle: String

    @Field(key: FieldKeys.v1.sanitizedTitle)
    var sanitizedTitle: String

    @Field(key: FieldKeys.v1.cacheKey)
    var cacheKey: String

    @Field(key: FieldKeys.v1.title)
    var title: String

    @Field(key: FieldKeys.v1.playerCount)
    var playerCount: String

    @Field(key: FieldKeys.v1.playTime)
    var playTime: String

    @Field(key: FieldKeys.v1.summary)
    var summary: String

    @Field(key: FieldKeys.v1.initialSetup)
    var initialSetup: [String]

    @Field(key: FieldKeys.v1.firstRoundGuide)
    var firstRoundGuide: [String]

    @Field(key: FieldKeys.v1.winCondition)
    var winCondition: String

    @Field(key: FieldKeys.v1.deepDive)
    var deepDive: [String]

    @Field(key: FieldKeys.v1.resourcesVideoLinks)
    var resourcesVideoLinks: [String]

    @Field(key: FieldKeys.v1.resourcesWebLinks)
    var resourcesWebLinks: [String]

    @Field(key: FieldKeys.v1.confidence)
    var confidence: Int

    @Field(key: FieldKeys.v1.notes)
    var notes: String

    @Timestamp(key: FieldKeys.v1.lastAccessedAt, on: .none)
    var lastAccessedAt: Date?

    @Timestamp(key: FieldKeys.v1.createdAt, on: .create)
    var createdAt: Date?

    @Timestamp(key: FieldKeys.v1.updatedAt, on: .update)
    var updatedAt: Date?

    @Timestamp(key: FieldKeys.v1.deletedAt, on: .delete)
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
        summary: String,
        initialSetup: [String],
        firstRoundGuide: [String],
        winCondition: String,
        deepDive: [String],
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
        self.summary = summary
        self.initialSetup = initialSetup
        self.firstRoundGuide = firstRoundGuide
        self.winCondition = winCondition
        self.deepDive = deepDive
        self.resourcesVideoLinks = resourcesVideoLinks
        self.resourcesWebLinks = resourcesWebLinks
        self.confidence = confidence
        self.notes = notes
        self.lastAccessedAt = lastAccessedAt
    }
}

extension GeneratedRuleModel {
    enum FieldKeys {
        enum v1 {
            static var originalTitle: FieldKey { "game_title_original" }
            static var sanitizedTitle: FieldKey { "game_title_sanitized" }
            static var cacheKey: FieldKey { "cache_key" }
            static var title: FieldKey { "title" }
            static var playerCount: FieldKey { "player_count" }
            static var playTime: FieldKey { "play_time" }
            static var summary: FieldKey { "summary" }
            static var initialSetup: FieldKey { "initial_setup" }
            static var firstRoundGuide: FieldKey { "first_round_guide" }
            static var winCondition: FieldKey { "win_condition" }
            static var deepDive: FieldKey { "deep_dive" }
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
