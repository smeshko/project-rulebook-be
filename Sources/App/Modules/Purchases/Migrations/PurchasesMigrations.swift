import Fluent

/// Migration creating the receipts table for purchase tracking.
struct CreateReceiptsTable: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("receipts")
            .id()
            .field("transaction_id", .string, .required)
            .field("original_transaction_id", .string, .required)
            .field("product_id", .string, .required)
            .field("device_id", .string, .required)
            .field("platform", .string, .required)
            .field("purchase_date", .datetime, .required)
            .field("expiration_date", .datetime)
            .field("status", .string, .required)
            .field("environment", .string, .required)
            .field("is_trial_period", .bool, .required)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            // Unique constraint on transaction_id + platform to prevent duplicates
            .unique(on: "transaction_id", "platform")
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("receipts").delete()
    }
}

/// Migration to add purchase-related enums.
struct AddPurchaseEnums: AsyncMigration {
    func prepare(on database: Database) async throws {
        _ = try await database.enum("purchase_platform")
            .case("ios")
            .case("android")
            .create()

        _ = try await database.enum("purchase_status")
            .case("active")
            .case("expired")
            .case("refunded")
            .case("cancelled")
            .case("gracePeriod")
            .case("billingRetry")
            .case("unknown")
            .create()

        _ = try await database.enum("purchase_environment")
            .case("production")
            .case("sandbox")
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.enum("purchase_environment").delete()
        try await database.enum("purchase_status").delete()
        try await database.enum("purchase_platform").delete()
    }
}

/// All purchases-related migrations in order.
enum PurchasesMigrations {
    static var all: [any AsyncMigration] {
        [
            AddPurchaseEnums(),  // Enums first
            CreateReceiptsTable(),
        ]
    }
}
