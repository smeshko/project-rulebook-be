import Fluent
import Vapor

final class RemoteConfigModel: @unchecked Sendable, DatabaseModelInterface {
    typealias Module = RemoteConfigModule
    static var schema: String { "remote_configs" }

    @ID()
    var id: UUID?

    @Field(key: FieldKeys.v1.key)
    var key: String

    @Field(key: FieldKeys.v1.value)
    var value: String

    @Enum(key: FieldKeys.v1.valueType)
    var valueType: RemoteConfigValueType

    @Enum(key: FieldKeys.v1.category)
    var category: RemoteConfigCategory

    @Timestamp(key: FieldKeys.v1.createdAt, on: .create)
    var createdAt: Date?

    @Timestamp(key: FieldKeys.v1.updatedAt, on: .update)
    var updatedAt: Date?

    init() {}

    init(
        id: UUID? = nil,
        key: String,
        value: String,
        valueType: RemoteConfigValueType,
        category: RemoteConfigCategory
    ) {
        self.id = id
        self.key = key
        self.value = value
        self.valueType = valueType
        self.category = category
    }
}

extension RemoteConfigModel {
    struct FieldKeys {
        struct v1 {
            static var key: FieldKey { "key" }
            static var value: FieldKey { "value" }
            static var valueType: FieldKey { "value_type" }
            static var category: FieldKey { "category" }
            static var createdAt: FieldKey { "created_at" }
            static var updatedAt: FieldKey { "updated_at" }
        }
    }
}

public enum RemoteConfigValueType: String, Codable, CaseIterable, Sendable {
    case boolean
    case integer
    case string
}

public enum RemoteConfigCategory: String, Codable, CaseIterable, Sendable {
    case featureFlag
    case setting
}
