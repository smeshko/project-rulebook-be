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

    @Field(key: FieldKeys.v1.valueType)
    var valueType: String

    @Field(key: FieldKeys.v1.version)
    var version: Int

    @Field(key: FieldKeys.v1.isActive)
    var isActive: Bool

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
        version: Int = 1,
        isActive: Bool = true
    ) {
        self.id = id
        self.key = key
        self.value = value
        self.valueType = valueType
        self.version = version
        self.isActive = isActive
    }
}

extension RemoteConfigModel {
    struct FieldKeys {
        struct v1 {
            static var key: FieldKey { "key" }
            static var value: FieldKey { "value" }
            static var valueType: FieldKey { "value_type" }
            static var version: FieldKey { "version" }
            static var isActive: FieldKey { "is_active" }
            static var createdAt: FieldKey { "created_at" }
            static var updatedAt: FieldKey { "updated_at" }
        }
    }
}
