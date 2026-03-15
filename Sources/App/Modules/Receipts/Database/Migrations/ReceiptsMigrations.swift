import Fluent
import Vapor

enum ReceiptsMigrations {

    struct v1: AsyncMigration {

        func prepare(on db: Database) async throws {
            try await db.enum("transaction_platform")
                .case("ios")
                .case("android")
                .create()

            let platformEnum = try await db.enum("transaction_platform").read()

            try await db.schema(TransactionModel.schema)
                .id()
                .field(TransactionModel.FieldKeys.v1.transactionId, .string, .required)
                .field(TransactionModel.FieldKeys.v1.platform, platformEnum, .required)
                .field(TransactionModel.FieldKeys.v1.productId, .string, .required)
                .field(TransactionModel.FieldKeys.v1.creditAmount, .int, .required)
                .field(TransactionModel.FieldKeys.v1.createdAt, .datetime)
                .unique(on: TransactionModel.FieldKeys.v1.transactionId)
                .create()
        }

        func revert(on db: Database) async throws {
            try await db.schema(TransactionModel.schema).delete()
            try await db.enum("transaction_platform").delete()
        }
    }

    struct v2: AsyncMigration {

        func prepare(on db: Database) async throws {
            try await db.schema(TransactionModel.schema)
                .field(TransactionModel.FieldKeys.v2.receiptHash, .string, .required)
                .update()
        }

        func revert(on db: Database) async throws {
            try await db.schema(TransactionModel.schema)
                .deleteField(TransactionModel.FieldKeys.v2.receiptHash)
                .update()
        }
    }
}
