import Foundation

/// Validated transaction information returned from platform-specific validators.
///
/// This struct provides a normalized representation of purchase data from both
/// iOS App Store and Android Google Play, enabling unified handling of validated
/// purchases regardless of the source platform.
///
/// ## Fields
/// All fields are populated from the platform-specific transaction data:
/// - For iOS: Extracted from the decoded JWS transaction payload
/// - For Android: Extracted from the purchases.products.get API response
public struct ValidatedTransaction: Sendable {
    /// The unique transaction identifier from the platform.
    ///
    /// - iOS: The `transactionId` from JWSTransactionDecodedPayload
    /// - Android: The `orderId` from the purchase response
    public let transactionId: String

    /// The original transaction ID for subscription renewals or restores.
    ///
    /// - iOS: The `originalTransactionId` from JWSTransactionDecodedPayload
    /// - Android: Same as `transactionId` for one-time purchases
    public let originalTransactionId: String

    /// The product identifier that was purchased.
    ///
    /// - iOS: The `productId` from the transaction payload
    /// - Android: The `productId` from the purchase response
    public let productId: String

    /// The bundle ID (iOS) or package name (Android) of the purchasing app.
    public let bundleId: String

    /// The platform where the purchase was made.
    public let platform: PurchasePlatform

    /// The date and time when the purchase was made.
    public let purchaseDate: Date

    /// The date and time when the subscription expires (nil for consumables).
    public let expirationDate: Date?

    /// Whether this is a trial period for subscriptions.
    public let isTrialPeriod: Bool

    /// Whether auto-renew is enabled for subscriptions.
    public let isAutoRenewEnabled: Bool

    /// The current status of the purchase.
    public let status: PurchaseStatus

    /// The environment where the purchase was made.
    public let environment: PurchaseEnvironment

    /// Raw platform-specific data for debugging or extended processing.
    public let rawData: [String: String]?

    public init(
        transactionId: String,
        originalTransactionId: String,
        productId: String,
        bundleId: String,
        platform: PurchasePlatform,
        purchaseDate: Date,
        expirationDate: Date? = nil,
        isTrialPeriod: Bool = false,
        isAutoRenewEnabled: Bool = false,
        status: PurchaseStatus = .active,
        environment: PurchaseEnvironment = .production,
        rawData: [String: String]? = nil
    ) {
        self.transactionId = transactionId
        self.originalTransactionId = originalTransactionId
        self.productId = productId
        self.bundleId = bundleId
        self.platform = platform
        self.purchaseDate = purchaseDate
        self.expirationDate = expirationDate
        self.isTrialPeriod = isTrialPeriod
        self.isAutoRenewEnabled = isAutoRenewEnabled
        self.status = status
        self.environment = environment
        self.rawData = rawData
    }
}

/// Status of a purchase or subscription.
public enum PurchaseStatus: String, Codable, Sendable {
    /// The purchase is currently active and valid.
    case active

    /// The purchase has expired (for subscriptions).
    case expired

    /// The purchase was refunded by the platform.
    case refunded

    /// The purchase was cancelled by the user.
    case cancelled

    /// The subscription is in a grace period after failed renewal.
    case gracePeriod

    /// The subscription is in billing retry status.
    case billingRetry

    /// The purchase status is unknown or could not be determined.
    case unknown
}

/// Environment where the purchase was made.
public enum PurchaseEnvironment: String, Codable, Sendable {
    /// Production environment (App Store / Google Play).
    case production

    /// Sandbox/testing environment.
    case sandbox
}

/// Protocol for platform-specific purchase validators.
///
/// Implementations of this protocol handle the platform-specific logic for
/// validating receipts or purchase tokens from iOS App Store or Android Google Play.
///
/// ## Implementation Requirements
/// - Must be thread-safe and use async/await
/// - Should validate signatures cryptographically
/// - Must verify bundle/package name matches configuration
/// - Should return normalized ValidatedTransaction
///
/// ## Example Implementation
/// ```swift
/// struct AppStoreValidator: PlatformValidator {
///     let platform: PurchasePlatform = .ios
///
///     func validate(receiptData: String) async throws -> ValidatedTransaction {
///         // Verify JWS signature using App Store Server Library
///         // Extract and normalize transaction data
///         // Return ValidatedTransaction
///     }
/// }
/// ```
public protocol PlatformValidator: Sendable {
    /// The platform this validator handles.
    var platform: PurchasePlatform { get }

    /// Validates a receipt or purchase token and returns the transaction details.
    ///
    /// - Parameter receiptData: The receipt data from the client.
    ///   - For iOS: The signedTransactionInfo JWS string
    ///   - For Android: The purchase token from the Play Store
    /// - Parameter productId: Optional product ID for additional validation.
    /// - Returns: A validated transaction with normalized data.
    /// - Throws: `PurchaseValidationError` if validation fails.
    func validate(receiptData: String, productId: String?) async throws -> ValidatedTransaction
}

/// Unified purchase validation service interface.
///
/// This service provides a single entry point for validating purchases from
/// any supported platform. It delegates to platform-specific validators based
/// on the request and returns normalized transaction data.
///
/// ## Usage
/// ```swift
/// let validator = app.purchaseValidator
/// let transaction = try await validator.validate(
///     platform: .ios,
///     receiptData: signedTransaction,
///     productId: "com.app.premium"
/// )
/// ```
public protocol PurchaseValidatorService: Sendable {
    /// Validates a purchase receipt and returns the transaction details.
    ///
    /// - Parameters:
    ///   - platform: The platform the purchase came from.
    ///   - receiptData: Platform-specific receipt or token data.
    ///   - productId: Optional product ID for validation.
    /// - Returns: Validated and normalized transaction data.
    /// - Throws: `PurchaseValidationError` on validation failure.
    func validate(
        platform: PurchasePlatform,
        receiptData: String,
        productId: String?
    ) async throws -> ValidatedTransaction

    /// Checks if a specific platform is configured and available.
    ///
    /// - Parameter platform: The platform to check.
    /// - Returns: `true` if the platform is configured and ready for validation.
    func isConfigured(platform: PurchasePlatform) -> Bool
}
