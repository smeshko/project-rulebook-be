import Fluent
import Vapor

enum ConfigValueType: String, Codable, Sendable {
    case boolean
    case integer
    case string
    case json
}

final class RemoteConfigModel: @unchecked Sendable, DatabaseModelInterface {
    typealias Module = RemoteConfigModule
    static var schema: String { "remote_configs" }

    @ID()
    var id: UUID?

    @Field(key: FieldKeys.v1.key)
    var key: String

    @Field(key: FieldKeys.v1.value)
    var value: String

    @Field(key: FieldKeys.v1.valueType)
    var valueType: ConfigValueType

    @Timestamp(key: FieldKeys.v1.updatedAt, on: .update)
    var updatedAt: Date?

    @Timestamp(key: FieldKeys.v1.createdAt, on: .create)
    var createdAt: Date?

    init() { }

    init(
        id: UUID? = nil,
        key: String,
        value: String,
        valueType: ConfigValueType
    ) {
        self.id = id
        self.key = key
        self.value = value
        self.valueType = valueType
    }
}

extension RemoteConfigModel {
    struct FieldKeys {
        struct v1 {
            static var key: FieldKey { "config_key" }
            static var value: FieldKey { "config_value" }
            static var valueType: FieldKey { "value_type" }
            static var updatedAt: FieldKey { "updated_at" }
            static var createdAt: FieldKey { "created_at" }
        }
    }
}
