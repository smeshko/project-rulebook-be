import Foundation
import Vapor

/// Unified purchase validation service that delegates to platform-specific validators.
///
/// This service provides a single entry point for validating purchases from any
/// supported platform. It maintains platform-specific validators and routes
/// validation requests appropriately.
///
/// ## Usage
/// ```swift
/// let validator = UnifiedPurchaseValidator(
///     iosValidator: appStoreValidator,
///     androidValidator: googlePlayValidator,
///     logger: logger
/// )
///
/// let transaction = try await validator.validate(
///     platform: .ios,
///     receiptData: signedTransaction,
///     productId: "com.app.premium"
/// )
/// ```
///
/// ## Thread Safety
/// This service is designed to be Sendable and can be safely used concurrently
/// from multiple request handlers.
struct UnifiedPurchaseValidator: PurchaseValidatorService, Sendable {
    private let iosValidator: AppStoreValidator?
    private let androidValidator: GooglePlayValidator?
    private let logger: Logger

    /// Creates a unified purchase validator with optional platform-specific validators.
    ///
    /// - Parameters:
    ///   - iosValidator: Optional iOS App Store validator (nil if not configured).
    ///   - androidValidator: Optional Android Google Play validator (nil if not configured).
    ///   - logger: Logger for diagnostic output.
    init(
        iosValidator: AppStoreValidator?,
        androidValidator: GooglePlayValidator?,
        logger: Logger
    ) {
        self.iosValidator = iosValidator
        self.androidValidator = androidValidator
        self.logger = logger
    }

    /// Validates a purchase receipt and returns the transaction details.
    ///
    /// Routes the validation request to the appropriate platform-specific validator
    /// based on the platform parameter.
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
    ) async throws -> ValidatedTransaction {
        logger.info("Validating purchase", metadata: [
            "platform": .string(platform.rawValue),
            "hasProductId": .string(productId != nil ? "true" : "false")
        ])

        switch platform {
        case .ios:
            guard let validator = iosValidator else {
                throw PurchaseValidationError.platformNotConfigured(.ios)
            }
            return try await validator.validate(receiptData: receiptData, productId: productId)

        case .android:
            guard let validator = androidValidator else {
                throw PurchaseValidationError.platformNotConfigured(.android)
            }
            return try await validator.validate(receiptData: receiptData, productId: productId)
        }
    }

    /// Checks if a specific platform is configured and available.
    ///
    /// - Parameter platform: The platform to check.
    /// - Returns: `true` if the platform is configured and ready for validation.
    func isConfigured(platform: PurchasePlatform) -> Bool {
        switch platform {
        case .ios:
            return iosValidator != nil
        case .android:
            return androidValidator != nil
        }
    }
}
