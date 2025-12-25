import Foundation
import Vapor

/// Android Google Play purchase validator using the Google Play Developer API.
///
/// This validator verifies Android purchase tokens by calling the Google Play
/// Developer API and extracts normalized purchase information.
///
/// ## Validation Process
/// 1. Authenticate with Google using service account credentials
/// 2. Call purchases.products.get API with the purchase token
/// 3. Validate the response and extract purchase details
/// 4. Verify package name matches configuration
/// 5. Return normalized ValidatedTransaction
///
/// ## Usage
/// ```swift
/// let validator = GooglePlayValidator(config: googlePlayConfig, client: httpClient, logger: logger)
/// let transaction = try await validator.validate(
///     receiptData: purchaseToken,
///     productId: "com.app.premium"
/// )
/// ```
///
/// ## Note
/// This is a stub implementation that validates the structure of the request.
/// Full implementation requires Google OAuth2 authentication and API calls.
struct GooglePlayValidator: PlatformValidator, Sendable {
    let platform: PurchasePlatform = .android

    private let config: GooglePlayConfig
    private let client: Client
    private let logger: Logger

    /// Creates a Google Play validator with the provided configuration.
    ///
    /// - Parameters:
    ///   - config: Google Play configuration with service account credentials.
    ///   - client: HTTP client for API requests.
    ///   - logger: Logger for diagnostic output.
    init(config: GooglePlayConfig, client: Client, logger: Logger) {
        self.config = config
        self.client = client
        self.logger = logger
    }

    /// Validates a purchase token from Google Play.
    ///
    /// - Parameters:
    ///   - receiptData: The purchase token from Google Play Billing Library.
    ///   - productId: The product ID (required for Google Play validation).
    /// - Returns: Validated transaction with normalized data.
    /// - Throws: `PurchaseValidationError` if validation fails.
    func validate(receiptData: String, productId: String?) async throws -> ValidatedTransaction {
        guard let productId = productId else {
            throw PurchaseValidationError.invalidRequest("Product ID is required for Google Play validation")
        }

        logger.info("Starting Android purchase validation", metadata: [
            "productId": .string(productId),
            "packageName": .string(config.packageName)
        ])

        // Validate the purchase token is not empty
        guard !receiptData.isEmpty else {
            throw PurchaseValidationError.malformedReceipt("Purchase token is empty")
        }

        // In a full implementation, we would:
        // 1. Authenticate with Google OAuth2 using service account
        // 2. Call purchases.products.get API
        // 3. Parse and validate the response

        // For now, call the Google Play API
        let transaction = try await callGooglePlayAPI(
            purchaseToken: receiptData,
            productId: productId
        )

        logger.info("Android purchase validation successful", metadata: [
            "transactionId": .string(transaction.transactionId),
            "productId": .string(transaction.productId)
        ])

        return transaction
    }

    // MARK: - Private Helpers

    /// Authenticates with Google and calls the purchases.products.get API.
    private func callGooglePlayAPI(purchaseToken: String, productId: String) async throws -> ValidatedTransaction {
        // Get OAuth2 access token using service account
        let accessToken = try await getAccessToken()

        // Build the API URL
        let apiURL = "https://androidpublisher.googleapis.com/androidpublisher/v3/applications/\(config.packageName)/purchases/products/\(productId)/tokens/\(purchaseToken)"

        // Make the API request
        let response = try await client.get(URI(string: apiURL)) { request in
            request.headers.add(name: .authorization, value: "Bearer \(accessToken)")
        }

        // Check response status
        guard response.status == .ok else {
            let errorBody = response.body.map { String(buffer: $0) } ?? "Unknown error"
            logger.error("Google Play API error", metadata: [
                "status": .string("\(response.status.code)"),
                "body": .string(errorBody)
            ])
            throw PurchaseValidationError.googlePlayError(
                code: Int(response.status.code),
                message: errorBody
            )
        }

        // Parse the response
        guard let body = response.body else {
            throw PurchaseValidationError.unexpectedResponse("Empty response body")
        }

        let purchaseResponse = try JSONDecoder().decode(GooglePlayPurchaseResponse.self, from: body)

        return mapPurchaseResponse(purchaseResponse, productId: productId, purchaseToken: purchaseToken)
    }

    /// Gets an OAuth2 access token using the service account credentials.
    private func getAccessToken() async throws -> String {
        // Parse service account JSON
        guard let jsonData = config.serviceAccountJson.data(using: .utf8) else {
            throw PurchaseValidationError.invalidConfiguration("Invalid service account JSON")
        }

        let serviceAccount = try JSONDecoder().decode(GoogleServiceAccount.self, from: jsonData)

        // Create JWT for OAuth2 token request
        let now = Date()
        let jwt = GoogleOAuthJWT(
            iss: serviceAccount.client_email,
            scope: "https://www.googleapis.com/auth/androidpublisher",
            aud: "https://oauth2.googleapis.com/token",
            iat: Int(now.timeIntervalSince1970),
            exp: Int(now.addingTimeInterval(3600).timeIntervalSince1970)
        )

        // Sign the JWT (simplified - in production use proper JWT signing)
        let jwtString = try signJWT(jwt, privateKey: serviceAccount.private_key)

        // Exchange JWT for access token
        let tokenResponse = try await client.post(URI(string: "https://oauth2.googleapis.com/token")) { request in
            request.headers.add(name: .contentType, value: "application/x-www-form-urlencoded")
            let body = "grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=\(jwtString)"
            request.body = .init(string: body)
        }

        guard tokenResponse.status == .ok, let body = tokenResponse.body else {
            throw PurchaseValidationError.networkError("Failed to get OAuth2 token")
        }

        let token = try JSONDecoder().decode(GoogleOAuthTokenResponse.self, from: body)
        return token.access_token
    }

    /// Signs a JWT using the service account private key.
    /// Note: This is a placeholder - in production, use a proper JWT library.
    private func signJWT(_ jwt: GoogleOAuthJWT, privateKey: String) throws -> String {
        let encoder = JSONEncoder()
        let header = ["alg": "RS256", "typ": "JWT"]
        let headerData = try encoder.encode(header)
        let payloadData = try encoder.encode(jwt)

        let headerBase64 = headerData.base64URLEncodedString()
        let payloadBase64 = payloadData.base64URLEncodedString()

        // In production, this should sign with the RSA private key
        // For now, we throw an error indicating full implementation is needed
        throw PurchaseValidationError.platformNotConfigured(.android)
    }

    /// Maps the Google Play API response to a ValidatedTransaction.
    private func mapPurchaseResponse(_ response: GooglePlayPurchaseResponse, productId: String, purchaseToken: String) -> ValidatedTransaction {
        let purchaseDate = Date(timeIntervalSince1970: TimeInterval(response.purchaseTimeMillis) / 1000)

        let status: PurchaseStatus
        switch response.purchaseState {
        case 0:
            status = .active
        case 1:
            status = .cancelled
        case 2:
            status = .gracePeriod
        default:
            status = .unknown
        }

        // Check for consumption (consumables)
        if response.consumptionState == 1 {
            // Already consumed - treat as active (it was valid when consumed)
        }

        // Check for acknowledgement
        let isAcknowledged = response.acknowledgementState == 1

        return ValidatedTransaction(
            transactionId: response.orderId ?? purchaseToken,
            originalTransactionId: response.orderId ?? purchaseToken,
            productId: productId,
            bundleId: config.packageName,
            platform: .android,
            purchaseDate: purchaseDate,
            expirationDate: nil,  // One-time purchases don't expire
            isTrialPeriod: false,
            isAutoRenewEnabled: false,
            status: status,
            environment: response.purchaseType == 0 ? .sandbox : .production,
            rawData: [
                "acknowledged": String(isAcknowledged),
                "purchaseType": String(response.purchaseType ?? -1)
            ]
        )
    }
}

// MARK: - Google Play API Response Models

/// Response from Google Play purchases.products.get API.
struct GooglePlayPurchaseResponse: Decodable {
    /// The order ID (transaction ID).
    let orderId: String?

    /// Time of purchase in milliseconds since epoch.
    let purchaseTimeMillis: Int64

    /// Purchase state: 0=Purchased, 1=Cancelled, 2=Pending
    let purchaseState: Int

    /// Consumption state: 0=Not consumed, 1=Consumed
    let consumptionState: Int

    /// Acknowledgement state: 0=Not acknowledged, 1=Acknowledged
    let acknowledgementState: Int

    /// Purchase type: 0=Test, 1=Promo, not present for normal purchases
    let purchaseType: Int?
}

/// Google service account credentials JSON structure.
struct GoogleServiceAccount: Decodable {
    let type: String
    let project_id: String
    let private_key_id: String
    let private_key: String
    let client_email: String
    let client_id: String
    let auth_uri: String
    let token_uri: String
}

/// JWT payload for Google OAuth2 token request.
struct GoogleOAuthJWT: Encodable {
    let iss: String
    let scope: String
    let aud: String
    let iat: Int
    let exp: Int
}

/// Response from Google OAuth2 token endpoint.
struct GoogleOAuthTokenResponse: Decodable {
    let access_token: String
    let token_type: String
    let expires_in: Int
}

// MARK: - Data Extension

extension Data {
    /// Encodes data to base64url format (RFC 4648).
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
