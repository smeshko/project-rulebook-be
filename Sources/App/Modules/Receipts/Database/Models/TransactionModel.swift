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

    @Field(key: FieldKeys.v2.receiptHash)
    var receiptHash: String

    @Enum(key: FieldKeys.v3.status)
    var status: TransactionStatus

    @OptionalField(key: FieldKeys.v3.refundedAt)
    var refundedAt: Date?

    init() {}

    init(
        id: UUID? = nil,
        transactionId: String,
        platform: TransactionPlatform,
        productId: String,
        creditAmount: Int,
        receiptHash: String,
        status: TransactionStatus = .valid,
        refundedAt: Date? = nil
    ) {
        self.id = id
        self.transactionId = transactionId
        self.platform = platform
        self.productId = productId
        self.creditAmount = creditAmount
        self.receiptHash = receiptHash
        self.status = status
        self.refundedAt = refundedAt
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
        struct v2 {
            static var receiptHash: FieldKey { "receipt_hash" }
        }
        struct v3 {
            static var status: FieldKey { "status" }
            static var refundedAt: FieldKey { "refunded_at" }
        }
    }
}

public enum TransactionPlatform: String, Codable, CaseIterable, Sendable {
    case ios
    case android
}

public enum TransactionStatus: String, Codable, CaseIterable, Sendable {
    case valid
    case refunded
    case revoked
}
