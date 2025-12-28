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

    @Field(key: FieldKeys.v1.type)
    var type: String

    @Timestamp(key: FieldKeys.v1.createdAt, on: .create)
    var createdAt: Date?

    @Timestamp(key: FieldKeys.v1.updatedAt, on: .update)
    var updatedAt: Date?

    init() { }

    init(
        id: UUID? = nil,
        key: String,
        value: String,
        type: String
    ) {
        self.id = id
        self.key = key
        self.value = value
        self.type = type
    }

    // MARK: - Value Helpers

    /// Get the value as a Boolean (for boolean type entries)
    var boolValue: Bool? {
        guard type == "boolean" else { return nil }
        return value.lowercased() == "true"
    }

    /// Get the value as an Integer (for integer type entries)
    var intValue: Int? {
        guard type == "integer" else { return nil }
        return Int(value)
    }

    /// Get the value as any Codable value
    var anyValue: AnyCodable {
        switch type {
        case "boolean":
            return AnyCodable(boolValue ?? false)
        case "integer":
            return AnyCodable(intValue ?? 0)
        case "json":
            // Try to decode as JSON
            if let data = value.data(using: .utf8),
               let json = try? JSONDecoder().decode(AnyCodable.self, from: data) {
                return json
            }
            return AnyCodable(value)
        default:
            return AnyCodable(value)
        }
    }
}

extension ConfigEntryModel {
    struct FieldKeys {
        struct v1 {
            static var key: FieldKey { "config_key" }
            static var value: FieldKey { "config_value" }
            static var type: FieldKey { "config_type" }
            static var createdAt: FieldKey { "created_at" }
            static var updatedAt: FieldKey { "updated_at" }
        }
    }
}
