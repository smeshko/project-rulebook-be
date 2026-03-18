import Foundation
@preconcurrency import JWTKit
import NIOConcurrencyHelpers
import Vapor

// MARK: - Notification Type

/// The type of one-time product notification received from Google Play RTDN.
enum GoogleNotificationType: Sendable, Equatable {
    /// The purchase was completed (notificationType = 1).
    case oneTimeProductPurchased

    /// The purchase was canceled (notificationType = 2).
    case oneTimeProductCanceled

    /// The purchase was refunded (notificationType = 3).
    case oneTimeProductRefunded

    /// An unrecognized notification type.
    case unknown(Int)

    init(rawValue: Int) {
        switch rawValue {
        case 1: self = .oneTimeProductPurchased
        case 2: self = .oneTimeProductCanceled
        case 3: self = .oneTimeProductRefunded
        default: self = .unknown(rawValue)
        }
    }

}

// MARK: - Notification Result

/// The decoded result of a Google Play RTDN notification.
struct GoogleNotificationResult: Sendable {
    /// The type of notification received.
    let notificationType: GoogleNotificationType

    /// The purchase token from the notification.
    let purchaseToken: String?

    /// The product identifier (SKU) from the notification.
    let productId: String?

    /// The package name from the developer notification.
    let packageName: String?
}

// MARK: - Errors

/// Errors that can occur during Google notification processing.
enum GoogleNotificationError: Error {
    /// The Pub/Sub verification token is invalid or missing.
    case invalidToken

    /// Failed to decode the Pub/Sub message.
    case decodingFailed(String)

    /// Service configuration is missing or invalid.
    case configurationError(String)

    /// Voided purchase verification via Google API failed.
    case voidedPurchaseVerificationFailed(String)
}

// MARK: - Pub/Sub Message DTOs

/// The top-level Pub/Sub push message envelope.
struct PubSubPushMessage: Content {
    let message: PubSubMessage
    let subscription: String?
}

/// The inner Pub/Sub message containing the base64-encoded data.
struct PubSubMessage: Content {
    let data: String
    let messageId: String?
}

/// The decoded Google Developer Notification payload.
struct GoogleDeveloperNotification: Content {
    let version: String?
    let packageName: String?
    let eventTimeMillis: String?
    let oneTimeProductNotification: OneTimeProductNotification?
}

/// Notification details for a one-time product event.
struct OneTimeProductNotification: Content {
    let version: String?
    let notificationType: Int
    let purchaseToken: String?
    let sku: String?
}

// MARK: - Voided Purchases API Response

/// Response from the Google Play Voided Purchases API.
struct GoogleVoidedPurchasesResponse: Content {
    let voidedPurchases: [GoogleVoidedPurchase]?
    let tokenPagination: TokenPagination?
}

/// A single voided purchase entry.
struct GoogleVoidedPurchase: Content {
    let purchaseToken: String?
    let voidedTimeMillis: String?
    let orderId: String?
    let voidedSource: Int?
    let voidedReason: Int?
}

/// Pagination token for voided purchases API.
struct TokenPagination: Content {
    let nextPageToken: String?
}

// MARK: - Protocol

/// Service responsible for decoding and verifying Google Play RTDN notifications.
protocol GoogleNotificationService: Sendable {
    /// Decodes a base64-encoded Pub/Sub message into a Google notification result.
    ///
    /// - Parameter base64Message: The base64-encoded data from the Pub/Sub push message.
    /// - Returns: The decoded notification result.
    /// - Throws: ``GoogleNotificationError`` if decoding fails.
    func decodeNotification(base64Message: String) throws -> GoogleNotificationResult

    /// Verifies a voided purchase via the Google Play Voided Purchases API
    /// and returns the order ID (transaction ID) if found.
    ///
    /// - Parameter purchaseToken: The purchase token to verify.
    /// - Returns: The order ID of the voided purchase, or nil if not found.
    /// - Throws: ``GoogleNotificationError`` if API verification fails.
    func verifyVoidedPurchase(purchaseToken: String) async throws -> String?
}

// MARK: - Implementation

/// Default implementation of ``GoogleNotificationService``.
///
/// Decodes Google Play RTDN Pub/Sub messages and verifies voided purchases
/// via the Google Play Voided Purchases API using OAuth2 service account authentication.
final class DefaultGoogleNotificationService: GoogleNotificationService, @unchecked Sendable {
    let app: Application

    /// Cached OAuth2 access token and its expiry time.
    private var cachedToken: String?
    private var tokenExpiry: Date?

    /// Lock for thread-safe token cache access.
    private let tokenLock = NIOLock()

    private static let tokenEndpoint = "https://oauth2.googleapis.com/token"
    private static let playAPIBase = "https://androidpublisher.googleapis.com/androidpublisher/v3/applications"
    private static let scope = "https://www.googleapis.com/auth/androidpublisher"

    init(app: Application) {
        self.app = app
    }

    func decodeNotification(base64Message: String) throws -> GoogleNotificationResult {
        guard let messageData = Data(base64Encoded: base64Message) else {
            throw GoogleNotificationError.decodingFailed("Failed to base64-decode Pub/Sub message data")
        }

        let decoder = JSONDecoder()
        let developerNotification: GoogleDeveloperNotification
        do {
            developerNotification = try decoder.decode(GoogleDeveloperNotification.self, from: messageData)
        } catch {
            throw GoogleNotificationError.decodingFailed(
                "Failed to decode DeveloperNotification JSON: \(error)"
            )
        }

        guard let oneTimeNotification = developerNotification.oneTimeProductNotification else {
            return GoogleNotificationResult(
                notificationType: .unknown(0),
                purchaseToken: nil,
                productId: nil,
                packageName: developerNotification.packageName
            )
        }

        return GoogleNotificationResult(
            notificationType: GoogleNotificationType(rawValue: oneTimeNotification.notificationType),
            purchaseToken: oneTimeNotification.purchaseToken,
            productId: oneTimeNotification.sku,
            packageName: developerNotification.packageName
        )
    }

    func verifyVoidedPurchase(purchaseToken: String) async throws -> String? {
        let config: GooglePlayConfig
        do {
            config = try app.configuration.google
        } catch {
            throw GoogleNotificationError.configurationError(
                "Failed to load Google Play configuration: \(error)"
            )
        }

        let accessToken = try await getAccessToken(config: config)

        let url = "\(Self.playAPIBase)/\(config.packageName)/purchases/voidedpurchases"

        let response: ClientResponse
        do {
            response = try await app.client.get(URI(string: url)) { req in
                req.headers.bearerAuthorization = BearerAuthorization(token: accessToken)
            }
        } catch {
            throw GoogleNotificationError.voidedPurchaseVerificationFailed(
                "Voided Purchases API request failed: \(error)"
            )
        }

        if response.status == .unauthorized {
            // Invalidate cached token on 401 (matching PlayStoreValidationService pattern)
            tokenLock.withLock {
                cachedToken = nil
                tokenExpiry = nil
            }
            throw GoogleNotificationError.voidedPurchaseVerificationFailed(
                "Voided Purchases API authentication failed — token may have expired"
            )
        }

        guard response.status == .ok else {
            throw GoogleNotificationError.voidedPurchaseVerificationFailed(
                "Voided Purchases API returned HTTP \(response.status.code)"
            )
        }

        let voidedResponse = try response.content.decode(GoogleVoidedPurchasesResponse.self)

        guard let voidedPurchases = voidedResponse.voidedPurchases else {
            return nil
        }

        let match = voidedPurchases.first { $0.purchaseToken == purchaseToken }
        return match?.orderId
    }

    // MARK: - Private OAuth2 Token Exchange

    /// Retrieves a valid OAuth2 access token, using the cache if available.
    private func getAccessToken(config: GooglePlayConfig) async throws -> String {
        let (cached, expiry) = tokenLock.withLock {
            (cachedToken, tokenExpiry)
        }

        if let cached, let expiry, Date() < expiry {
            return cached
        }

        return try await requestAccessToken(config: config)
    }

    /// Generates a JWT and exchanges it for an OAuth2 access token.
    private func requestAccessToken(config: GooglePlayConfig) async throws -> String {
        let now = Date()
        let claims = GoogleServiceAccountClaims(
            iss: IssuerClaim(value: config.serviceAccountEmail),
            scope: Self.scope,
            aud: AudienceClaim(value: Self.tokenEndpoint),
            iat: IssuedAtClaim(value: now),
            exp: ExpirationClaim(value: now.addingTimeInterval(3600))
        )

        let normalizedKey = config.privateKey.replacingOccurrences(of: "\\n", with: "\n")
        guard let privateKeyData = normalizedKey.data(using: .utf8), !privateKeyData.isEmpty else {
            throw GoogleNotificationError.configurationError(
                "Google service account private key is empty or contains invalid characters"
            )
        }
        let signers = JWTSigners()
        do {
            try signers.use(.rs256(key: .private(pem: privateKeyData)))
        } catch {
            throw GoogleNotificationError.configurationError(
                "Failed to load Google service account private key: \(error)"
            )
        }

        let jwt: String
        do {
            jwt = try signers.sign(claims)
        } catch {
            throw GoogleNotificationError.configurationError(
                "Failed to sign JWT for Google OAuth2: \(error)"
            )
        }

        let response = try await app.client.post(URI(string: Self.tokenEndpoint)) { req in
            try req.content.encode([
                "grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer",
                "assertion": jwt,
            ], as: .urlEncodedForm)
        }

        guard response.status == .ok else {
            let errorBody = try? response.content.decode(GoogleAPIErrorResponse.self)
            let message = errorBody?.error?.message ?? "HTTP \(response.status.code)"
            throw GoogleNotificationError.configurationError(
                "Failed to obtain access token from Google: \(message)"
            )
        }

        let tokenResponse = try response.content.decode(GoogleTokenResponse.self)

        tokenLock.withLock {
            cachedToken = tokenResponse.accessToken
            tokenExpiry = Date().addingTimeInterval(Double(max(0, tokenResponse.expiresIn - 300)))
        }

        return tokenResponse.accessToken
    }
}
