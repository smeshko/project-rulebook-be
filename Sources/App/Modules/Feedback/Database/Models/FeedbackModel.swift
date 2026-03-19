import Fluent
import Vapor

final class FeedbackModel: @unchecked Sendable, DatabaseModelInterface {
    typealias Module = FeedbackModule
    static var schema: String { "feedbacks" }

    @ID()
    var id: UUID?

    @Field(key: FieldKeys.v1.rulesSummaryId)
    var rulesSummaryId: UUID

    @Field(key: FieldKeys.v1.gameTitle)
    var gameTitle: String

    @Enum(key: FieldKeys.v1.feedbackType)
    var feedbackType: FeedbackType

    @Field(key: FieldKeys.v1.description)
    var description: String

    @OptionalField(key: FieldKeys.v1.userContact)
    var userContact: String?

    @Enum(key: FieldKeys.v1.status)
    var status: FeedbackStatus

    @Timestamp(key: FieldKeys.v1.createdAt, on: .create)
    var createdAt: Date?

    init() {}

    init(
        id: UUID? = nil,
        rulesSummaryId: UUID,
        gameTitle: String,
        feedbackType: FeedbackType,
        description: String,
        userContact: String? = nil,
        status: FeedbackStatus = .pending
    ) {
        self.id = id
        self.rulesSummaryId = rulesSummaryId
        self.gameTitle = gameTitle
        self.feedbackType = feedbackType
        self.description = description
        self.userContact = userContact
        self.status = status
    }
}

extension FeedbackModel {
    struct FieldKeys {
        struct v1 {
            static var rulesSummaryId: FieldKey { "rules_summary_id" }
            static var gameTitle: FieldKey { "game_title" }
            static var feedbackType: FieldKey { "feedback_type" }
            static var description: FieldKey { "description" }
            static var userContact: FieldKey { "user_contact" }
            static var status: FieldKey { "status" }
            static var createdAt: FieldKey { "created_at" }
        }
    }
}

public enum FeedbackType: String, Codable, CaseIterable, Sendable {
    case incorrect
    case incomplete
    case other
}

public enum FeedbackStatus: String, Codable, CaseIterable, Sendable {
    case pending
    case reviewed
    case resolved
}
