import Foundation

/// Platform identifier for distinguishing iOS and Android purchases.
///
/// Used to route receipt validation to the appropriate platform-specific
/// validator (App Store Server API or Google Play Developer API).
///
/// ## Usage
/// ```swift
/// let platform = PurchasePlatform.detect(from: request.headers)
/// switch platform {
/// case .ios:
///     return try await iosValidator.validate(receipt)
/// case .android:
///     return try await androidValidator.validate(receipt)
/// }
/// ```
public enum PurchasePlatform: String, Codable, Sendable {
    /// Apple iOS platform - uses App Store Server API for validation.
    case ios

    /// Google Android platform - uses Google Play Developer API for validation.
    case android

    /// Human-readable description of the platform.
    public var displayName: String {
        switch self {
        case .ios:
            return "iOS"
        case .android:
            return "Android"
        }
    }
}

/// Errors that can occur during purchase validation.
///
/// This enum provides a comprehensive set of error types for all stages
/// of receipt validation, from request parsing to platform-specific validation.
///
/// ## Error Categories
/// - **Request Errors**: Invalid input from the client
/// - **Validation Errors**: Receipt signature or content validation failures
/// - **Configuration Errors**: Missing or invalid service configuration
/// - **Platform Errors**: Platform-specific API errors
public enum PurchaseValidationError: Error, Sendable {

    // MARK: - Request Errors

    /// The request body could not be parsed or is missing required fields.
    case invalidRequest(String)

    /// The specified platform is not supported or recognized.
    case unsupportedPlatform(String)

    /// The receipt data is malformed, corrupted, or in an invalid format.
    case malformedReceipt(String)

    // MARK: - Validation Errors

    /// The receipt signature verification failed.
    ///
    /// For iOS: JWS signature is invalid or certificate chain is untrusted.
    /// For Android: Purchase token signature verification failed.
    case signatureInvalid(String)

    /// The receipt belongs to a different application.
    ///
    /// The bundle ID (iOS) or package name (Android) doesn't match configuration.
    case bundleMismatch(expected: String, received: String)

    /// The purchase transaction could not be found.
    case transactionNotFound(String)

    /// The receipt has expired and is no longer valid.
    case receiptExpired(String)

    /// The purchase was refunded by the platform.
    case purchaseRefunded(String)

    /// The purchase was cancelled by the user.
    case purchaseCancelled(String)

    // MARK: - Configuration Errors

    /// Platform credentials are not configured.
    case platformNotConfigured(PurchasePlatform)

    /// Configuration values are invalid or incomplete.
    case invalidConfiguration(String)

    // MARK: - Platform API Errors

    /// The App Store Server API returned an error.
    case appStoreError(code: Int, message: String)

    /// The Google Play Developer API returned an error.
    case googlePlayError(code: Int, message: String)

    /// Network or communication error with the platform API.
    case networkError(String)

    /// The platform API returned an unexpected response.
    case unexpectedResponse(String)

    // MARK: - Internal Errors

    /// An unexpected internal error occurred.
    case internalError(String)
}

// MARK: - LocalizedError Conformance

extension PurchaseValidationError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidRequest(let message):
            return "Invalid request: \(message)"
        case .unsupportedPlatform(let platform):
            return "Unsupported platform: \(platform)"
        case .malformedReceipt(let message):
            return "Malformed receipt: \(message)"
        case .signatureInvalid(let message):
            return "Invalid signature: \(message)"
        case .bundleMismatch(let expected, let received):
            return "Bundle mismatch: expected \(expected), received \(received)"
        case .transactionNotFound(let message):
            return "Transaction not found: \(message)"
        case .receiptExpired(let message):
            return "Receipt expired: \(message)"
        case .purchaseRefunded(let message):
            return "Purchase was refunded: \(message)"
        case .purchaseCancelled(let message):
            return "Purchase was cancelled: \(message)"
        case .platformNotConfigured(let platform):
            return "\(platform.displayName) is not configured for purchase validation"
        case .invalidConfiguration(let message):
            return "Invalid configuration: \(message)"
        case .appStoreError(let code, let message):
            return "App Store error (\(code)): \(message)"
        case .googlePlayError(let code, let message):
            return "Google Play error (\(code)): \(message)"
        case .networkError(let message):
            return "Network error: \(message)"
        case .unexpectedResponse(let message):
            return "Unexpected response: \(message)"
        case .internalError(let message):
            return "Internal error: \(message)"
        }
    }
}

// MARK: - HTTP Status Mapping

import Vapor

extension PurchaseValidationError: AbortError {
    public var status: HTTPResponseStatus {
        switch self {
        case .invalidRequest, .malformedReceipt, .unsupportedPlatform:
            return .badRequest
        case .signatureInvalid, .bundleMismatch:
            return .unauthorized
        case .transactionNotFound:
            return .notFound
        case .receiptExpired, .purchaseRefunded, .purchaseCancelled:
            return .gone
        case .platformNotConfigured, .invalidConfiguration:
            return .serviceUnavailable
        case .appStoreError, .googlePlayError, .networkError, .unexpectedResponse:
            return .badGateway
        case .internalError:
            return .internalServerError
        }
    }

    public var reason: String {
        errorDescription ?? "Unknown purchase validation error"
    }
}
