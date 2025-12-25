import AppStoreServerLibrary
import Foundation
import Vapor

/// iOS App Store receipt validator using Apple's App Store Server Library.
///
/// This validator verifies JWS-signed transaction data from StoreKit 2
/// and extracts normalized purchase information.
///
/// ## Validation Process
/// 1. Parse the signed transaction JWS string
/// 2. Verify the certificate chain against Apple's root CA
/// 3. Validate the signature using the leaf certificate
/// 4. Extract transaction payload and verify bundle ID
/// 5. Return normalized ValidatedTransaction
///
/// ## Usage
/// ```swift
/// let validator = AppStoreValidator(config: appStoreConfig, logger: logger)
/// let transaction = try await validator.validate(
///     receiptData: signedTransactionInfo,
///     productId: "com.app.premium"
/// )
/// ```
struct AppStoreValidator: PlatformValidator, Sendable {
    let platform: PurchasePlatform = .ios

    private let config: AppStoreConfig
    private let logger: Logger

    /// Creates an App Store validator with the provided configuration.
    ///
    /// - Parameters:
    ///   - config: App Store configuration with API credentials.
    ///   - logger: Logger for diagnostic output.
    init(config: AppStoreConfig, logger: Logger) {
        self.config = config
        self.logger = logger
    }

    /// Validates a signed transaction from StoreKit 2.
    ///
    /// - Parameters:
    ///   - receiptData: The signedTransactionInfo JWS string from StoreKit 2.
    ///   - productId: Optional product ID for additional validation.
    /// - Returns: Validated transaction with normalized data.
    /// - Throws: `PurchaseValidationError` if validation fails.
    func validate(receiptData: String, productId: String?) async throws -> ValidatedTransaction {
        logger.info("Starting iOS receipt validation", metadata: [
            "productId": .string(productId ?? "none")
        ])

        // Create the signed data verifier for the configured environment
        let environment = mapEnvironment(config.environment)

        let verifier: SignedDataVerifier
        do {
            verifier = try SignedDataVerifier(
                rootCertificates: [],  // Uses Apple's embedded root certificates
                bundleId: config.bundleId,
                appAppleId: config.appAppleId,
                environment: environment,
                enableOnlineChecks: true
            )
        } catch {
            logger.error("Failed to create SignedDataVerifier", metadata: [
                "error": .string(String(describing: error))
            ])
            throw PurchaseValidationError.invalidConfiguration("Failed to initialize App Store verifier: \(error)")
        }

        // Verify and decode the signed transaction
        let verificationResult = await verifier.verifyAndDecodeTransaction(signedTransaction: receiptData)

        let transaction: JWSTransactionDecodedPayload
        switch verificationResult {
        case .valid(let decodedTransaction):
            transaction = decodedTransaction
        case .invalid(let error):
            logger.warning("Transaction verification failed", metadata: [
                "error": .string(String(describing: error))
            ])
            throw mapVerificationError(error)
        }

        // Validate bundle ID matches
        guard transaction.bundleId == config.bundleId else {
            throw PurchaseValidationError.bundleMismatch(
                expected: config.bundleId,
                received: transaction.bundleId ?? "unknown"
            )
        }

        // Validate product ID if provided
        if let expectedProductId = productId {
            guard transaction.productId == expectedProductId else {
                throw PurchaseValidationError.invalidRequest(
                    "Product ID mismatch: expected \(expectedProductId), got \(transaction.productId ?? "unknown")"
                )
            }
        }

        logger.info("iOS receipt validation successful", metadata: [
            "transactionId": .string(transaction.transactionId ?? "unknown"),
            "productId": .string(transaction.productId ?? "unknown")
        ])

        return mapTransaction(transaction)
    }

    // MARK: - Private Helpers

    private func mapEnvironment(_ env: AppStoreConfig.Environment) -> AppStoreEnvironment {
        switch env {
        case .sandbox:
            return .sandbox
        case .production:
            return .production
        }
    }

    private func mapVerificationError(_ error: VerificationError) -> PurchaseValidationError {
        switch error {
        case .INVALID_JWT_FORMAT:
            return .malformedReceipt("Invalid JWS format")
        case .INVALID_CERTIFICATE:
            return .signatureInvalid("Invalid certificate in chain")
        case .VERIFICATION_FAILURE, .RETRYABLE_VERIFICATION_FAILURE:
            return .signatureInvalid("Verification failure")
        case .INVALID_APP_IDENTIFIER:
            return .bundleMismatch(expected: config.bundleId, received: "mismatched")
        case .INVALID_ENVIRONMENT:
            return .invalidConfiguration("Environment mismatch")
        }
    }

    private func mapTransaction(_ payload: JWSTransactionDecodedPayload) -> ValidatedTransaction {
        let purchaseDate = payload.purchaseDate ?? Date()
        let expirationDate = payload.expiresDate

        let status = mapTransactionStatus(
            revocationDate: payload.revocationDate,
            expiresDate: payload.expiresDate
        )

        let environment: PurchaseEnvironment = payload.environment == .sandbox ? .sandbox : .production

        return ValidatedTransaction(
            transactionId: payload.transactionId ?? "",
            originalTransactionId: payload.originalTransactionId ?? "",
            productId: payload.productId ?? "",
            bundleId: payload.bundleId ?? "",
            platform: .ios,
            purchaseDate: purchaseDate,
            expirationDate: expirationDate,
            isTrialPeriod: payload.offerType == .introductoryOffer,
            isAutoRenewEnabled: false,  // Would need subscription status check
            status: status,
            environment: environment,
            rawData: [
                "type": payload.rawType ?? "unknown",
                "inAppOwnershipType": payload.rawInAppOwnershipType ?? "unknown"
            ]
        )
    }

    private func mapTransactionStatus(revocationDate: Date?, expiresDate: Date?) -> PurchaseStatus {
        if revocationDate != nil {
            return .refunded
        }

        if let expires = expiresDate {
            if expires < Date() {
                return .expired
            }
        }

        return .active
    }
}
