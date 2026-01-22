import Fluent
import Vapor

/// Represents a configuration value for remote configuration.
///
/// Stores typed configuration values (boolean, integer, string) that can be
/// fetched by mobile apps to control behavior remotely without app updates.
final class RemoteConfigModel: @unchecked Sendable, DatabaseModelInterface {
    typealias Module = RemoteConfigModule
    static var schema: String { "remote_config" }

    @ID()
    var id: UUID?

    @Field(key: FieldKeys.v1.key)
    var key: String

    @Field(key: FieldKeys.v1.value)
    var value: String

    @Field(key: FieldKeys.v1.valueType)
    var valueType: ConfigValueType

    @Timestamp(key: FieldKeys.v1.createdAt, on: .create)
    var createdAt: Date?

    @Timestamp(key: FieldKeys.v1.updatedAt, on: .update)
    var updatedAt: Date?

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

// MARK: - Value Type Enum

/// Supported configuration value types.
enum ConfigValueType: String, Codable, CaseIterable {
    case boolean
    case integer
    case string
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

// MARK: - Convenience Methods

extension RemoteConfigModel {
    /// Returns the typed value based on valueType.
    var typedValue: Any {
        switch valueType {
        case .boolean:
            return value.lowercased() == "true"
        case .integer:
            return Int(value) ?? 0
        case .string:
            return value
        }
    }

    /// Creates a RemoteConfigModel with proper type inference.
    static func create(key: String, boolValue: Bool) -> RemoteConfigModel {
        RemoteConfigModel(key: key, value: String(boolValue), valueType: .boolean)
    }

    static func create(key: String, intValue: Int) -> RemoteConfigModel {
        RemoteConfigModel(key: key, value: String(intValue), valueType: .integer)
    }

    static func create(key: String, stringValue: String) -> RemoteConfigModel {
        RemoteConfigModel(key: key, value: stringValue, valueType: .string)
    }
}
