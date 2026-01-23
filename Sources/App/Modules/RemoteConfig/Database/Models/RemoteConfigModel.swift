import Fluent
import Vapor

/// Database model for storing remote configuration values.
///
/// Supports typed configuration values (boolean, integer, string) organized into
/// categories (feature flags and settings) for mobile app configuration.
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

    @Timestamp(key: FieldKeys.v1.deletedAt, on: .delete)
    var deletedAt: Date?

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

// MARK: - Field Keys

extension RemoteConfigModel {
    struct FieldKeys {
        struct v1 {
            static var key: FieldKey { "key" }
            static var value: FieldKey { "value" }
            static var valueType: FieldKey { "value_type" }
            static var category: FieldKey { "category" }
            static var createdAt: FieldKey { "created_at" }
            static var updatedAt: FieldKey { "updated_at" }
            static var deletedAt: FieldKey { "deleted_at" }
        }
    }
}

// MARK: - Enums

/// Supported value types for remote configuration.
enum RemoteConfigValueType: String, Codable, CaseIterable {
    case boolean
    case integer
    case string
}

/// Categories for organizing remote configuration.
enum RemoteConfigCategory: String, Codable, CaseIterable {
    case featureFlag = "featureFlag"
    case setting = "setting"
}
