import Fluent
import Vapor

final class ConfigValueModel: @unchecked Sendable, DatabaseModelInterface {
    typealias Module = ConfigModule
    static var schema: String { "config_values" }

    @ID()
    var id: UUID?

    @Field(key: FieldKeys.v1.key)
    var key: String

    @Field(key: FieldKeys.v1.value)
    var value: String

    @Field(key: FieldKeys.v1.valueType)
    var valueType: String

    @Timestamp(key: FieldKeys.v1.createdAt, on: .create)
    var createdAt: Date?

    @Timestamp(key: FieldKeys.v1.updatedAt, on: .update)
    var updatedAt: Date?

    init() { }

    init(
        id: UUID? = nil,
        key: String,
        value: String,
        valueType: String
    ) {
        self.id = id
        self.key = key
        self.value = value
        self.valueType = valueType
    }

    /// Decode the stored value based on the value type
    var decodedValue: AnyCodableValue {
        guard let type = Config.ValueType(rawValue: valueType) else {
            return .string(value)
        }
        return AnyCodableValue.from(value, type: type)
    }
}

extension ConfigValueModel {
    struct FieldKeys {
        struct v1 {
            static var key: FieldKey { "key" }
            static var value: FieldKey { "value" }
            static var valueType: FieldKey { "value_type" }
            static var createdAt: FieldKey { "created_at" }
            static var updatedAt: FieldKey { "updated_at" }
        }
    }
}
