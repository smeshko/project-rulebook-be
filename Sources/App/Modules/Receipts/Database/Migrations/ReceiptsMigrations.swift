import Fluent
import Vapor

enum ReceiptsMigrations {

    struct v1: AsyncMigration {

        func prepare(on db: Database) async throws {
            try await db.schema(TransactionModel.schema)
                .id()
                .field(TransactionModel.FieldKeys.v1.transactionId, .string, .required)
                .field(TransactionModel.FieldKeys.v1.platform, .string, .required)
                .field(TransactionModel.FieldKeys.v1.productId, .string, .required)
                .field(TransactionModel.FieldKeys.v1.creditAmount, .int, .required)
                .field(TransactionModel.FieldKeys.v1.createdAt, .datetime)
                .unique(on: TransactionModel.FieldKeys.v1.transactionId)
                .create()
        }

        func revert(on db: Database) async throws {
            try await db.schema(TransactionModel.schema).delete()
        }
    }
}
