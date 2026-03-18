@preconcurrency import AppStoreServerLibrary
import Foundation
import Vapor

// MARK: - Notification Result

struct AppleNotificationResult: Sendable {
    let notificationType: NotificationTypeV2
    let rawNotificationType: String?
    let subtype: String?
    let originalTransactionId: String?
}

// MARK: - Errors

enum AppleNotificationError: Error {
    case invalidSignature
    case verificationFailed(String)
    case configurationError(String)
}

// MARK: - Protocol

protocol AppleNotificationService: Sendable {
    func verifyAndDecode(signedPayload: String) async throws -> AppleNotificationResult
}

// MARK: - Implementation

final class DefaultAppleNotificationService: AppleNotificationService, @unchecked Sendable {
    let app: Application

    init(app: Application) {
        self.app = app
    }

    func verifyAndDecode(signedPayload: String) async throws -> AppleNotificationResult {
        let verifier = try createVerifier()

        let result = await verifier.verifyAndDecodeNotification(signedPayload: signedPayload)

        switch result {
        case .valid(let payload):
            return try await extractResult(from: payload, verifier: verifier)
        case .invalid(let error):
            app.logger.warning("Apple notification verification failed", metadata: [
                "error": .string(String(describing: error))
            ])
            throw AppleNotificationError.invalidSignature
        }
    }

    // MARK: - Private

    private func createVerifier() throws -> SignedDataVerifier {
        let config: AppleConfig
        do {
            config = try app.configuration.apple
        } catch {
            throw AppleNotificationError.configurationError(
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
            throw AppleNotificationError.configurationError(
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
            throw AppleNotificationError.configurationError(
                "Failed to create SignedDataVerifier: \(error)"
            )
        }
    }

    private func extractResult(
        from payload: ResponseBodyV2DecodedPayload,
        verifier: SignedDataVerifier
    ) async throws -> AppleNotificationResult {
        guard let notificationType = payload.notificationType else {
            throw AppleNotificationError.verificationFailed("Missing notificationType in payload")
        }

        var originalTransactionId: String?

        if let signedTransactionInfo = payload.data?.signedTransactionInfo {
            let txnResult = await verifier.verifyAndDecodeTransaction(
                signedTransaction: signedTransactionInfo
            )
            switch txnResult {
            case .valid(let transaction):
                originalTransactionId = transaction.originalTransactionId
            case .invalid(let error):
                app.logger.warning("Failed to verify transaction info in notification", metadata: [
                    "error": .string(String(describing: error))
                ])
            }
        }

        return AppleNotificationResult(
            notificationType: notificationType,
            rawNotificationType: payload.rawNotificationType,
            subtype: payload.rawSubtype,
            originalTransactionId: originalTransactionId
        )
    }

    private func loadAppleRootCertificates() throws -> [Foundation.Data] {
        let appleRootCAG3Base64 = "MIICQzCCAcmgAwIBAgIILcX8iNLFS5UwCgYIKoZIzj0EAwMwZzEbMBkGA1UEAwwSQXBwbGUgUm9vdCBDQSAtIEczMSYwJAYDVQQLDB1BcHBsZSBDZXJ0aWZpY2F0aW9uIEF1dGhvcml0eTETMBEGA1UECgwKQXBwbGUgSW5jLjELMAkGA1UEBhMCVVMwHhcNMTQwNDMwMTgxOTA2WhcNMzkwNDMwMTgxOTA2WjBnMRswGQYDVQQDDBJBcHBsZSBSb290IENBIC0gRzMxJjAkBgNVBAsMHUFwcGxlIENlcnRpZmljYXRpb24gQXV0aG9yaXR5MRMwEQYDVQQKDApBcHBsZSBJbmMuMQswCQYDVQQGEwJVUzB2MBAGByqGSM49AgEGBSuBBAAiA2IABJjpLz1AcqTtkyJygRMc3RCV8cWjTnHcFBbZDuWmBSp3ZHtfTjjTuxxEtX/1H7YyYl3J6YRbTzBPEVoA/VhYDKX1DyxNB0cTddqXl5dvMVztK517IDvYuVTZXpmkOlEKMaNCMEAwHQYDVR0OBBYEFLuw3qFYM4iapIqZ3r6966/ayySrMA8GA1UdEwEB/wQFMAMBAf8wDgYDVR0PAQH/BAQDAgEGMAoGCCqGSM49BAMDA2gAMGUCMQCD6cHEFl4aXTQY2e3v9GwOAEZLuN+yRhHFD/3meoyhpmvOwgPUnPWTxnS4at+qIxUCMG1mihDK1A3UT82NQz60imOlM27jbdoXt2QfyFMm+YhidDkLF1vLUagM6BgD56KyKA=="

        guard let certData = Foundation.Data(base64Encoded: appleRootCAG3Base64) else {
            throw AppleNotificationError.configurationError("Failed to decode Apple Root CA G3 certificate")
        }

        return [certData]
    }
}
