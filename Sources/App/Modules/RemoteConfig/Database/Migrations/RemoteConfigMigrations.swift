import Fluent

struct RemoteConfigMigrations {
    static func v1() -> Migration {
        RemoteConfigMigration_v1()
    }
}

struct RemoteConfigMigration_v1: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema(ConfigEntryModel.schema)
            .id()
            .field("key", .string, .required)
            .field("value_type", .string, .required)
            .field("bool_value", .bool)
            .field("int_value", .int)
            .field("string_value", .string)
            .field("json_value", .string)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .unique(on: "key")
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema(ConfigEntryModel.schema).delete()
    }
}
