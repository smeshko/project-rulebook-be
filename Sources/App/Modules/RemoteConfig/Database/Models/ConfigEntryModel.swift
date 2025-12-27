import Fluent
import Vapor

final class ConfigEntryModel: Model, Content, @unchecked Sendable {
    static let schema = "config_entries"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "key")
    var key: String

    @Field(key: "value_type")
    var valueType: String

    // Type-specific storage columns (only one populated per row)
    @OptionalField(key: "bool_value")
    var boolValue: Bool?

    @OptionalField(key: "int_value")
    var intValue: Int?

    @OptionalField(key: "string_value")
    var stringValue: String?

    @OptionalField(key: "json_value")
    var jsonValue: String?

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    init() {}

    init(
        id: UUID? = nil,
        key: String,
        valueType: String,
        boolValue: Bool? = nil,
        intValue: Int? = nil,
        stringValue: String? = nil,
        jsonValue: String? = nil
    ) {
        self.id = id
        self.key = key
        self.valueType = valueType
        self.boolValue = boolValue
        self.intValue = intValue
        self.stringValue = stringValue
        self.jsonValue = jsonValue
    }
}

enum ConfigValueType: String, Codable {
    case boolean
    case integer
    case string
    case json
}
