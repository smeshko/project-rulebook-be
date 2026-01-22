import Fluent
import Vapor

final class ConfigEntryModel: @unchecked Sendable, DatabaseModelInterface {
    typealias Module = ConfigModule
    static var schema: String { "config_entries" }

    @ID()
    var id: UUID?

    @Field(key: FieldKeys.v1.key)
    var key: String

    @Field(key: FieldKeys.v1.value)
    var value: String

    @Field(key: FieldKeys.v1.valueType)
    var valueType: ConfigValueType

    @Field(key: FieldKeys.v1.category)
    var category: ConfigCategory

    @Timestamp(key: FieldKeys.v1.createdAt, on: .create)
    var createdAt: Date?

    @Timestamp(key: FieldKeys.v1.updatedAt, on: .update)
    var updatedAt: Date?

    init() { }

    init(
        id: UUID? = nil,
        key: String,
        value: String,
        valueType: ConfigValueType,
        category: ConfigCategory
    ) {
        self.id = id
        self.key = key
        self.value = value
        self.valueType = valueType
        self.category = category
    }
}

extension ConfigEntryModel {
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

enum ConfigValueType: String, Codable, CaseIterable {
    case boolean
    case integer
    case string
}

enum ConfigCategory: String, Codable, CaseIterable {
    case featureFlag = "feature_flag"
    case setting
}
