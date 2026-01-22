import Fluent
import Vapor

final class RemoteConfigEntryModel: @unchecked Sendable, DatabaseModelInterface {
    typealias Module = RemoteConfigModule
    static var schema: String { "remote_config_entries" }

    @ID()
    var id: UUID?

    @Field(key: FieldKeys.v1.key)
    var key: String

    @Field(key: FieldKeys.v1.value)
    var value: String

    @Field(key: FieldKeys.v1.valueType)
    var valueType: String

    @OptionalField(key: FieldKeys.v1.description)
    var description: String?

    @Timestamp(key: FieldKeys.v1.createdAt, on: .create)
    var createdAt: Date?

    @Timestamp(key: FieldKeys.v1.updatedAt, on: .update)
    var updatedAt: Date?

    init() { }

    init(
        id: UUID? = nil,
        key: String,
        value: String,
        valueType: String,
        description: String? = nil
    ) {
        self.id = id
        self.key = key
        self.value = value
        self.valueType = valueType
        self.description = description
    }
}

extension RemoteConfigEntryModel {
    struct FieldKeys {
        struct v1 {
            static var key: FieldKey { "key" }
            static var value: FieldKey { "value" }
            static var valueType: FieldKey { "value_type" }
            static var description: FieldKey { "description" }
            static var createdAt: FieldKey { "created_at" }
            static var updatedAt: FieldKey { "updated_at" }
        }
    }
}
