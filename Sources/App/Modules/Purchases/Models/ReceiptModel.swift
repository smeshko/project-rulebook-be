import Fluent
import Foundation
import Vapor

/// Database model for storing validated purchase receipts.
///
/// This model persists validated transaction data for:
/// - Duplicate detection (prevent processing same receipt twice)
/// - Historical record of purchases
/// - Subscription tracking and expiration monitoring
/// - Purchase analytics and reporting
///
/// ## Usage
/// ```swift
/// let receipt = ReceiptModel(
///     transactionId: "123456",
///     originalTransactionId: "123456",
///     productId: "com.app.premium",
///     userId: userId,
///     platform: .ios,
///     purchaseDate: Date(),
///     environment: .production
/// )
/// try await receipt.create(on: db)
/// ```
final class ReceiptModel: Model, @unchecked Sendable {
    static let schema = "receipts"

    /// Primary key - auto-generated UUID.
    @ID(key: .id)
    var id: UUID?

    /// Platform-specific transaction identifier.
    /// For iOS: transactionId from JWSTransactionDecodedPayload
    /// For Android: orderId from purchases.products.get response
    @Field(key: "transaction_id")
    var transactionId: String

    /// Original transaction ID for subscription renewals.
    /// For iOS: originalTransactionId
    /// For Android: same as transactionId for one-time purchases
    @Field(key: "original_transaction_id")
    var originalTransactionId: String

    /// Product identifier that was purchased.
    @Field(key: "product_id")
    var productId: String

    /// ID of the user who made the purchase.
    @Field(key: "user_id")
    var userId: UUID

    /// Platform where the purchase was made.
    @Enum(key: "platform")
    var platform: PurchasePlatform

    /// Date and time of the purchase.
    @Field(key: "purchase_date")
    var purchaseDate: Date

    /// Subscription expiration date (nil for consumables).
    @OptionalField(key: "expiration_date")
    var expirationDate: Date?

    /// Current status of the purchase.
    @Enum(key: "status")
    var status: PurchaseStatus

    /// Environment (production or sandbox).
    @Enum(key: "environment")
    var environment: PurchaseEnvironment

    /// Whether this is a trial period (subscriptions only).
    @Field(key: "is_trial_period")
    var isTrialPeriod: Bool

    /// Record creation timestamp.
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    /// Record last update timestamp.
    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    /// Empty initializer required by Fluent.
    init() {}

    /// Creates a new receipt record.
    ///
    /// - Parameters:
    ///   - id: Optional ID (auto-generated if nil).
    ///   - transactionId: Platform-specific transaction ID.
    ///   - originalTransactionId: Original transaction ID for renewals.
    ///   - productId: Product identifier.
    ///   - userId: User who made the purchase.
    ///   - platform: iOS or Android.
    ///   - purchaseDate: When the purchase was made.
    ///   - expirationDate: When subscription expires (nil for consumables).
    ///   - status: Current purchase status.
    ///   - environment: Production or sandbox.
    ///   - isTrialPeriod: Whether this is a trial.
    init(
        id: UUID? = nil,
        transactionId: String,
        originalTransactionId: String,
        productId: String,
        userId: UUID,
        platform: PurchasePlatform,
        purchaseDate: Date,
        expirationDate: Date? = nil,
        status: PurchaseStatus = .active,
        environment: PurchaseEnvironment = .production,
        isTrialPeriod: Bool = false
    ) {
        self.id = id
        self.transactionId = transactionId
        self.originalTransactionId = originalTransactionId
        self.productId = productId
        self.userId = userId
        self.platform = platform
        self.purchaseDate = purchaseDate
        self.expirationDate = expirationDate
        self.status = status
        self.environment = environment
        self.isTrialPeriod = isTrialPeriod
    }
}

// MARK: - Convenience Initializer from ValidatedTransaction

extension ReceiptModel {
    /// Creates a receipt model from a validated transaction.
    ///
    /// - Parameters:
    ///   - transaction: The validated transaction from the validator.
    ///   - userId: The user ID to associate with this receipt.
    convenience init(from transaction: ValidatedTransaction, userId: UUID) {
        self.init(
            transactionId: transaction.transactionId,
            originalTransactionId: transaction.originalTransactionId,
            productId: transaction.productId,
            userId: userId,
            platform: transaction.platform,
            purchaseDate: transaction.purchaseDate,
            expirationDate: transaction.expirationDate,
            status: transaction.status,
            environment: transaction.environment,
            isTrialPeriod: transaction.isTrialPeriod
        )
    }
}
