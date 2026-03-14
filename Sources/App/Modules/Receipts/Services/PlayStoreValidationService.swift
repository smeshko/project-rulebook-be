import Foundation
@preconcurrency import JWTKit
import NIOConcurrencyHelpers
import Vapor

// MARK: - Validation Result

/// Result of a successful Play Store purchase verification.
struct PlayStoreValidationResult: Sendable {
    /// The unique order ID from Google Play (acts as transaction identifier).
    let transactionId: String

    /// The product identifier (SKU) of the purchased item.
    let productId: String

    /// The date when the purchase was made.
    let purchaseDate: Date
}

// MARK: - Validation Errors

/// Errors that can occur during Play Store receipt validation.
enum PlayStoreValidationError: Error, Equatable {
    /// The purchase token is invalid or malformed.
    case invalidToken

    /// The purchase was not found (product/token combination doesn't exist).
    case purchaseNotFound

    /// The service is not properly configured (missing credentials).
    case configurationError(String)

    /// A general verification failure with a descriptive reason.
    case verificationFailed(String)

    /// The Google API returned an unexpected error.
    case apiError(Int, String)

    static func == (lhs: PlayStoreValidationError, rhs: PlayStoreValidationError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidToken, .invalidToken):
            return true
        case (.purchaseNotFound, .purchaseNotFound):
            return true
        case (.configurationError(let a), .configurationError(let b)):
            return a == b
        case (.verificationFailed(let a), .verificationFailed(let b)):
            return a == b
        case (.apiError(let c1, let m1), .apiError(let c2, let m2)):
            return c1 == c2 && m1 == m2
        default:
            return false
        }
    }
}

// MARK: - Protocol

/// Service responsible for verifying Google Play Store purchases.
///
/// This service validates purchase tokens by calling the Google Play Developer API
/// using OAuth2 service account authentication.
protocol PlayStoreValidationService: Sendable {
    /// Verifies a Play Store purchase.
    ///
    /// - Parameters:
    ///   - productId: The product identifier (SKU) of the purchased item.
    ///   - purchaseToken: The purchase token received from the client.
    /// - Returns: The validated purchase details.
    /// - Throws: ``PlayStoreValidationError`` if verification fails.
    func verify(productId: String, purchaseToken: String) async throws -> PlayStoreValidationResult
}

// MARK: - Google OAuth2 JWT Claims

/// JWT claims for Google service account OAuth2 token exchange.
struct GoogleServiceAccountClaims: JWTPayload {
    /// The email address of the service account.
    var iss: IssuerClaim

    /// The required OAuth2 scope.
    var scope: String

    /// The token endpoint URL.
    var aud: AudienceClaim

    /// Token issued at time.
    var iat: IssuedAtClaim

    /// Token expiration time.
    var exp: ExpirationClaim

    func verify(using signer: JWTSigner) throws {
        try exp.verifyNotExpired()
    }
}

// MARK: - Google API Response Types

/// Response from Google OAuth2 token endpoint.
struct GoogleTokenResponse: Content {
    let accessToken: String
    let tokenType: String
    let expiresIn: Int

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
    }
}

/// Response from Google Play Developer API purchases.products.get endpoint.
struct GooglePlayPurchaseResponse: Content {
    /// 0 = Purchased, 1 = Canceled, 2 = Pending
    let purchaseState: Int?

    /// 0 = Yet to be acknowledged, 1 = Acknowledged
    let acknowledgementState: Int?

    /// The order ID of the purchase.
    let orderId: String?

    /// Time the product was purchased, in milliseconds since the epoch.
    let purchaseTimeMillis: String?

    /// The consumption state of the inapp product. 0 = Yet to be consumed, 1 = Consumed.
    let consumptionState: Int?
}

/// Error response from Google APIs.
struct GoogleAPIErrorResponse: Content {
    let error: GoogleAPIError?

    struct GoogleAPIError: Content {
        let code: Int?
        let message: String?
    }
}

// MARK: - Implementation

/// Default implementation of ``PlayStoreValidationService`` using Google Play Developer API.
///
/// Uses OAuth2 service account JWT flow to authenticate with Google APIs,
/// then calls `purchases.products.get` to verify one-time purchases.
/// Access tokens are cached for their lifetime (typically 1 hour).
final class DefaultPlayStoreValidationService: PlayStoreValidationService, @unchecked Sendable {
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

    func verify(productId: String, purchaseToken: String) async throws -> PlayStoreValidationResult {
        guard !purchaseToken.isEmpty else {
            throw PlayStoreValidationError.invalidToken
        }

        guard !productId.isEmpty else {
            throw PlayStoreValidationError.verificationFailed("Product ID cannot be empty")
        }

        let config: GooglePlayConfig
        do {
            config = try app.configuration.google
        } catch {
            throw PlayStoreValidationError.configurationError(
                "Failed to load Google Play configuration: \(error)"
            )
        }

        let accessToken = try await getAccessToken(config: config)
        return try await verifyPurchase(
            packageName: config.packageName,
            productId: productId,
            purchaseToken: purchaseToken,
            accessToken: accessToken
        )
    }

    // MARK: - Private

    /// Retrieves a valid access token, using the cache if available.
    private func getAccessToken(config: GooglePlayConfig) async throws -> String {
        // Check cache first
        let (cached, expiry) = tokenLock.withLock {
            (cachedToken, tokenExpiry)
        }

        if let cached, let expiry, Date() < expiry {
            return cached
        }

        // Generate new token
        let token = try await requestAccessToken(config: config)
        return token
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

        // Sign JWT with RS256 using the service account private key
        // Normalize escaped newlines from environment variables (\\n → \n)
        let normalizedKey = config.privateKey.replacingOccurrences(of: "\\n", with: "\n")
        guard let privateKeyData = normalizedKey.data(using: .utf8), !privateKeyData.isEmpty else {
            throw PlayStoreValidationError.configurationError(
                "Google service account private key is empty or contains invalid characters"
            )
        }
        let signers = JWTSigners()
        do {
            try signers.use(.rs256(key: .private(pem: privateKeyData)))
        } catch {
            throw PlayStoreValidationError.configurationError(
                "Failed to load Google service account private key: \(error)"
            )
        }

        let jwt: String
        do {
            jwt = try signers.sign(claims)
        } catch {
            throw PlayStoreValidationError.configurationError(
                "Failed to sign JWT for Google OAuth2: \(error)"
            )
        }

        // Exchange JWT for access token
        let response = try await app.client.post(URI(string: Self.tokenEndpoint)) { req in
            try req.content.encode([
                "grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer",
                "assertion": jwt,
            ], as: .urlEncodedForm)
        }

        guard response.status == .ok else {
            let errorBody = try? response.content.decode(GoogleAPIErrorResponse.self)
            let message = errorBody?.error?.message ?? "HTTP \(response.status.code)"
            throw PlayStoreValidationError.configurationError(
                "Failed to obtain access token from Google: \(message)"
            )
        }

        let tokenResponse = try response.content.decode(GoogleTokenResponse.self)

        // Cache the token with a 5-minute safety margin
        tokenLock.withLock {
            cachedToken = tokenResponse.accessToken
            tokenExpiry = Date().addingTimeInterval(Double(max(0, tokenResponse.expiresIn - 300)))
        }

        return tokenResponse.accessToken
    }

    /// Calls Google Play Developer API to verify the purchase.
    private func verifyPurchase(
        packageName: String,
        productId: String,
        purchaseToken: String,
        accessToken: String
    ) async throws -> PlayStoreValidationResult {
        guard let encodedProductId = productId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let encodedToken = purchaseToken.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            throw PlayStoreValidationError.invalidToken
        }
        let url = "\(Self.playAPIBase)/\(packageName)/purchases/products/\(encodedProductId)/tokens/\(encodedToken)"

        let response = try await app.client.get(URI(string: url)) { req in
            req.headers.bearerAuthorization = BearerAuthorization(token: accessToken)
        }

        switch response.status {
        case .ok:
            break
        case .notFound:
            throw PlayStoreValidationError.purchaseNotFound
        case .unauthorized:
            // Invalidate cached token on 401
            tokenLock.withLock {
                cachedToken = nil
                tokenExpiry = nil
            }
            throw PlayStoreValidationError.verificationFailed(
                "Google API authentication failed — token may have expired"
            )
        case .badRequest:
            throw PlayStoreValidationError.invalidToken
        default:
            let errorBody = try? response.content.decode(GoogleAPIErrorResponse.self)
            let message = errorBody?.error?.message ?? "Unknown error"
            throw PlayStoreValidationError.apiError(
                Int(response.status.code),
                message
            )
        }

        let purchase = try response.content.decode(GooglePlayPurchaseResponse.self)

        // Validate purchase state (0 = Purchased)
        guard let purchaseState = purchase.purchaseState else {
            throw PlayStoreValidationError.verificationFailed("Missing purchaseState in purchase response")
        }
        guard purchaseState == 0 else {
            throw PlayStoreValidationError.verificationFailed(
                "Purchase is not in a valid state (state: \(purchaseState))"
            )
        }

        guard let orderId = purchase.orderId else {
            throw PlayStoreValidationError.verificationFailed("Missing orderId in purchase response")
        }

        let purchaseDate: Date
        if let millis = purchase.purchaseTimeMillis, let millisValue = Double(millis) {
            purchaseDate = Date(timeIntervalSince1970: millisValue / 1000.0)
        } else {
            purchaseDate = Date()
        }

        app.logger.info("Play Store purchase verified successfully", metadata: [
            "orderId": .string(orderId),
            "productId": .string(productId),
        ])

        return PlayStoreValidationResult(
            transactionId: orderId,
            productId: productId,
            purchaseDate: purchaseDate
        )
    }
}
