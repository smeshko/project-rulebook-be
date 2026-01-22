import Fluent
import Vapor

/// Database model for storing remote configuration key-value pairs.
/// Supports typed values (boolean, integer, string) for flexible configuration management.
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
    var valueType: String

    @Timestamp(key: FieldKeys.v1.createdAt, on: .create)
    var createdAt: Date?

    @Timestamp(key: FieldKeys.v1.updatedAt, on: .update)
    var updatedAt: Date?

    init() {}

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
}

// MARK: - Field Keys

extension RemoteConfigModel {
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

// MARK: - Value Type Enum

extension RemoteConfigModel {
    /// Supported value types for remote configuration entries.
    enum ValueType: String, Codable, CaseIterable {
        case boolean
        case integer
        case string

        /// Validates that the provided value matches the expected type.
        func validate(_ value: String) -> Bool {
            switch self {
            case .boolean:
                return value.lowercased() == "true" || value.lowercased() == "false"
            case .integer:
                return Int(value) != nil
            case .string:
                return true
            }
        }
    }
}
