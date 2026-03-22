import Fluent
import Vapor

/// Tracks request frequency per game for cache warming prioritization.
final class GameRequestStats: @unchecked Sendable, DatabaseModelInterface {
    typealias Module = CacheAdminModule

    static var schema: String { "game_request_stats" }

    @ID()
    var id: UUID?

    @Field(key: FieldKeys.v1.sanitizedGameTitle)
    var sanitizedGameTitle: String

    @Field(key: FieldKeys.v1.requestCount)
    var requestCount: Int

    @Timestamp(key: FieldKeys.v1.lastRequestedAt, on: .none)
    var lastRequestedAt: Date?

    @Timestamp(key: FieldKeys.v1.createdAt, on: .create)
    var createdAt: Date?

    @Timestamp(key: FieldKeys.v1.updatedAt, on: .update)
    var updatedAt: Date?

    init() { }

    init(
        id: UUID? = nil,
        sanitizedGameTitle: String,
        requestCount: Int = 0,
        lastRequestedAt: Date? = nil
    ) {
        self.id = id
        self.sanitizedGameTitle = sanitizedGameTitle
        self.requestCount = requestCount
        self.lastRequestedAt = lastRequestedAt
    }
}

extension GameRequestStats {
    enum FieldKeys {
        enum v1 {
            static var sanitizedGameTitle: FieldKey { "sanitized_game_title" }
            static var requestCount: FieldKey { "request_count" }
            static var lastRequestedAt: FieldKey { "last_requested_at" }
            static var createdAt: FieldKey { "created_at" }
            static var updatedAt: FieldKey { "updated_at" }
        }
    }
}
