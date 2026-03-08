import Fluent
import Vapor

final class TransactionModel: @unchecked Sendable, DatabaseModelInterface {
    typealias Module = ReceiptsModule
    static var schema: String { "transactions" }

    @ID()
    var id: UUID?

    @Field(key: FieldKeys.v1.transactionId)
    var transactionId: String

    @Enum(key: FieldKeys.v1.platform)
    var platform: TransactionPlatform

    @Field(key: FieldKeys.v1.productId)
    var productId: String

    @Field(key: FieldKeys.v1.creditAmount)
    var creditAmount: Int

    @Timestamp(key: FieldKeys.v1.createdAt, on: .create)
    var createdAt: Date?

    init() {}

    init(
        id: UUID? = nil,
        transactionId: String,
        platform: TransactionPlatform,
        productId: String,
        creditAmount: Int
    ) {
        self.id = id
        self.transactionId = transactionId
        self.platform = platform
        self.productId = productId
        self.creditAmount = creditAmount
    }
}

extension TransactionModel {
    struct FieldKeys {
        struct v1 {
            static var transactionId: FieldKey { "transaction_id" }
            static var platform: FieldKey { "platform" }
            static var productId: FieldKey { "product_id" }
            static var creditAmount: FieldKey { "credit_amount" }
            static var createdAt: FieldKey { "created_at" }
        }
    }
}

public enum TransactionPlatform: String, Codable, CaseIterable, Sendable {
    case ios
    case android
}
