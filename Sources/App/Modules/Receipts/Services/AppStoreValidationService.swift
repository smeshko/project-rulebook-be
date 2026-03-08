import AppStoreServerLibrary
import Foundation
import Vapor

// MARK: - Validation Result

/// Result of a successful App Store transaction verification.
struct AppStoreValidationResult: Sendable {
    /// The unique transaction identifier.
    let transactionId: String

    /// The product identifier from App Store Connect.
    let productId: String

    /// The bundle identifier of the app that made the purchase.
    let bundleId: String

    /// The date when the purchase was made.
    let purchaseDate: Date

    /// The App Store environment (e.g., "Sandbox" or "Production").
    let environment: String
}

// MARK: - Validation Errors

/// Errors that can occur during App Store receipt validation.
enum AppStoreValidationError: Error, Equatable {
    /// The JWS signature verification failed.
    case invalidSignature

    /// The certificate chain in the JWS could not be verified.
    case invalidCertificateChain

    /// The bundle ID in the transaction doesn't match the configured bundle ID.
    case bundleIdMismatch

    /// The service is not properly configured (missing credentials or certificates).
    case configurationError(String)

    /// A general verification failure with a descriptive reason.
    case verificationFailed(String)
}

// MARK: - Protocol

/// Service responsible for verifying App Store signed transactions.
///
/// This service validates JWS (JSON Web Signature) signed transaction data
/// from Apple's App Store using Apple's root certificates and the
/// App Store Server Library.
protocol AppStoreValidationService: Sendable {
    /// Verifies a signed transaction from the App Store.
    ///
    /// - Parameter signedTransaction: The JWS-encoded signed transaction string from the client.
    /// - Returns: The validated transaction details.
    /// - Throws: ``AppStoreValidationError`` if verification fails.
    func verify(signedTransaction: String) async throws -> AppStoreValidationResult
}

// MARK: - Implementation

/// Default implementation of ``AppStoreValidationService`` using Apple's App Store Server Library.
///
/// Uses ``SignedDataVerifier`` from `AppStoreServerLibrary` to verify JWS transactions
/// with Apple's x5c certificate chain. The verifier handles signature validation,
/// certificate chain verification, and environment checking.
final class DefaultAppStoreValidationService: AppStoreValidationService, @unchecked Sendable {
    let app: Application

    init(app: Application) {
        self.app = app
    }

    func verify(signedTransaction: String) async throws -> AppStoreValidationResult {
        let verifier = try createVerifier()

        let result = await verifier.verifyAndDecodeTransaction(signedTransaction: signedTransaction)

        switch result {
        case .valid(let transaction):
            return try extractResult(from: transaction)
        case .invalid(let error):
            app.logger.warning("App Store transaction verification failed", metadata: [
                "error": .string(String(describing: error))
            ])
            throw mapVerificationError(error)
        }
    }

    // MARK: - Private

    private func createVerifier() throws -> SignedDataVerifier {
        let config: AppleConfig
        do {
            config = try app.configuration.apple
        } catch {
            throw AppStoreValidationError.configurationError(
                "Failed to load Apple configuration: \(error)"
            )
        }

        let rootCertificates = try loadAppleRootCertificates()

        let environment: AppStoreServerLibrary.Environment
        switch config.environment.lowercased() {
        case "production":
            environment = .production
        case "sandbox":
            environment = .sandbox
        default:
            throw AppStoreValidationError.configurationError(
                "Invalid APPLE_ENVIRONMENT '\(config.environment)'. Must be 'production' or 'sandbox'."
            )
        }

        do {
            return try SignedDataVerifier(
                rootCertificates: rootCertificates,
                bundleId: config.bundleId,
                appAppleId: config.appAppleId,
                environment: environment,
                enableOnlineChecks: true
            )
        } catch {
            throw AppStoreValidationError.configurationError(
                "Failed to create SignedDataVerifier: \(error)"
            )
        }
    }

    private func extractResult(from transaction: JWSTransactionDecodedPayload) throws -> AppStoreValidationResult {
        guard let transactionId = transaction.transactionId else {
            throw AppStoreValidationError.verificationFailed("Missing transactionId in decoded payload")
        }

        guard let productId = transaction.productId else {
            throw AppStoreValidationError.verificationFailed("Missing productId in decoded payload")
        }

        guard let bundleId = transaction.bundleId else {
            throw AppStoreValidationError.verificationFailed("Missing bundleId in decoded payload")
        }

        guard let purchaseDate = transaction.purchaseDate else {
            throw AppStoreValidationError.verificationFailed("Missing purchaseDate in decoded payload")
        }
        guard let environment = transaction.environment?.rawValue else {
            throw AppStoreValidationError.verificationFailed("Missing environment in decoded payload")
        }

        app.logger.info("App Store transaction verified successfully", metadata: [
            "transactionId": .string(transactionId),
            "productId": .string(productId),
            "bundleId": .string(bundleId)
        ])

        return AppStoreValidationResult(
            transactionId: transactionId,
            productId: productId,
            bundleId: bundleId,
            purchaseDate: purchaseDate,
            environment: environment
        )
    }

    private func mapVerificationError(_ error: VerificationError) -> AppStoreValidationError {
        switch error {
        case .INVALID_JWT_FORMAT:
            return .invalidSignature
        case .INVALID_CERTIFICATE:
            return .invalidCertificateChain
        case .VERIFICATION_FAILURE:
            return .verificationFailed("Signature verification failed")
        case .INVALID_APP_IDENTIFIER:
            return .bundleIdMismatch
        case .INVALID_ENVIRONMENT:
            return .verificationFailed("Environment mismatch between transaction and configuration")
        }
    }

    /// Loads Apple Root CA certificates for JWS signature verification.
    ///
    /// Uses the Apple Root CA - G3 certificate, which is the root certificate
    /// for the App Store Server API's signing chain.
    /// Source: https://www.apple.com/certificateauthority/
    private func loadAppleRootCertificates() throws -> [Foundation.Data] {
        // Apple Root CA - G3 (DER-encoded, base64)
        // Verified against Apple's official app-store-server-library-swift test suite
        let appleRootCAG3Base64 = "MIICQzCCAcmgAwIBAgIILcX8iNLFS5UwCgYIKoZIzj0EAwMwZzEbMBkGA1UEAwwSQXBwbGUgUm9vdCBDQSAtIEczMSYwJAYDVQQLDB1BcHBsZSBDZXJ0aWZpY2F0aW9uIEF1dGhvcml0eTETMBEGA1UECgwKQXBwbGUgSW5jLjELMAkGA1UEBhMCVVMwHhcNMTQwNDMwMTgxOTA2WhcNMzkwNDMwMTgxOTA2WjBnMRswGQYDVQQDDBJBcHBsZSBSb290IENBIC0gRzMxJjAkBgNVBAsMHUFwcGxlIENlcnRpZmljYXRpb24gQXV0aG9yaXR5MRMwEQYDVQQKDApBcHBsZSBJbmMuMQswCQYDVQQGEwJVUzB2MBAGByqGSM49AgEGBSuBBAAiA2IABJjpLz1AcqTtkyJygRMc3RCV8cWjTnHcFBbZDuWmBSp3ZHtfTjjTuxxEtX/1H7YyYl3J6YRbTzBPEVoA/VhYDKX1DyxNB0cTddqXl5dvMVztK517IDvYuVTZXpmkOlEKMaNCMEAwHQYDVR0OBBYEFLuw3qFYM4iapIqZ3r6966/ayySrMA8GA1UdEwEB/wQFMAMBAf8wDgYDVR0PAQH/BAQDAgEGMAoGCCqGSM49BAMDA2gAMGUCMQCD6cHEFl4aXTQY2e3v9GwOAEZLuN+yRhHFD/3meoyhpmvOwgPUnPWTxnS4at+qIxUCMG1mihDK1A3UT82NQz60imOlM27jbdoXt2QfyFMm+YhidDkLF1vLUagM6BgD56KyKA=="

        guard let certData = Foundation.Data(base64Encoded: appleRootCAG3Base64) else {
            throw AppStoreValidationError.configurationError("Failed to decode Apple Root CA G3 certificate")
        }

        return [certData]
    }
}
