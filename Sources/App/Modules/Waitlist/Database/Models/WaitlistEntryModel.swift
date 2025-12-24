import Fluent
import Vapor

final class WaitlistEntryModel: @unchecked Sendable, DatabaseModelInterface {
    typealias Module = WaitlistModule
    static var schema: String { "waitlist_entries" }

    @ID()
    var id: UUID?

    @Field(key: FieldKeys.v1.email)
    var email: String

    @Field(key: FieldKeys.v1.unsubscribeToken)
    var unsubscribeToken: String

    @Timestamp(key: FieldKeys.v1.createdAt, on: .create)
    var createdAt: Date?

    @OptionalField(key: FieldKeys.v1.notifiedAt)
    var notifiedAt: Date?

    init() { }

    init(
        id: UUID? = nil,
        email: String,
        unsubscribeToken: String = UUID().uuidString
    ) {
        self.id = id
        self.email = email
        self.unsubscribeToken = unsubscribeToken
    }
}

extension WaitlistEntryModel {
    struct FieldKeys {
        struct v1 {
            static var email: FieldKey { "email" }
            static var unsubscribeToken: FieldKey { "unsubscribe_token" }
            static var createdAt: FieldKey { "created_at" }
            static var notifiedAt: FieldKey { "notified_at" }
        }
    }
}
