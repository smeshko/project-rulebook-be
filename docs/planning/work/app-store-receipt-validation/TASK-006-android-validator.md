## TASK-006: Implement Android Google Play Validator

---
**Status:** OPEN
**Branch:** feature/app-store-receipt-validation
**Type:** IMPLEMENTATION
**Phase:** 2
**Depends On:** TASK-004
---

### Overview

Implement the Android Google Play receipt validator using Google Play Developer API with service account OAuth authentication.

**Files:**
- `Sources/App/Services/Purchases/GooglePlayValidator.swift` (create)

### Implementation Steps

**Commit 1: feat(purchases): implement GooglePlayValidator with OAuth flow**
- [ ] Create `GooglePlayValidator` struct
- [ ] Implement service account JWT generation
- [ ] Implement OAuth token exchange and caching
- [ ] Implement `validateAndroid` method using Google Play API
- [ ] Parse and validate API response
- [ ] Handle errors appropriately

### Code Example

```swift
// Sources/App/Services/Purchases/GooglePlayValidator.swift
import Vapor
import JWT

struct GooglePlayValidator: Sendable {
    private let config: GooglePlayConfig
    private let httpClient: Client
    private let logger: Logger

    // Service account JSON structure
    struct ServiceAccount: Codable {
        let client_email: String
        let private_key: String
        let token_uri: String
    }

    // Google OAuth token response
    struct TokenResponse: Content {
        let access_token: String
        let expires_in: Int
        let token_type: String
    }

    // Google Play purchase response
    struct ProductPurchase: Content {
        let kind: String?
        let purchaseTimeMillis: String
        let purchaseState: Int
        let consumptionState: Int?
        let orderId: String?
        let purchaseToken: String?
        let productId: String?
        let acknowledged: Bool?
    }

    init(config: GooglePlayConfig, httpClient: Client, logger: Logger) {
        self.config = config
        self.httpClient = httpClient
        self.logger = logger
    }

    func validate(productId: String, purchaseToken: String) async throws -> PurchaseValidationResult {
        logger.info("Validating Android Google Play purchase",
            metadata: ["productId": "\(productId)"])

        // Get OAuth access token
        let accessToken = try await getAccessToken()

        // Call Google Play Developer API
        let url = "https://androidpublisher.googleapis.com/androidpublisher/v3/applications/\(config.packageName)/purchases/products/\(productId)/tokens/\(purchaseToken)"

        let response = try await httpClient.get(URI(string: url)) { req in
            req.headers.bearerAuthorization = BearerAuthorization(token: accessToken)
        }

        guard response.status == .ok else {
            logger.warning("Google Play API error",
                metadata: ["status": "\(response.status.code)"])
            throw PurchaseValidationError.invalidToken
        }

        let purchase = try response.content.decode(ProductPurchase.self)

        // purchaseState: 0 = Purchased, 1 = Canceled, 2 = Pending
        guard purchase.purchaseState == 0 else {
            logger.warning("Purchase not in purchased state",
                metadata: ["state": "\(purchase.purchaseState)"])
            throw PurchaseValidationError.invalidTransaction
        }

        let purchaseTime = Date(timeIntervalSince1970:
            (Double(purchase.purchaseTimeMillis) ?? 0) / 1000.0)

        return PurchaseValidationResult(
            verified: true,
            platform: .android,
            transactionId: purchase.orderId ?? purchaseToken,
            originalTransactionId: purchase.orderId ?? purchaseToken,
            productId: productId,
            purchaseDate: purchaseTime,
            expiresDate: nil,  // Products don't expire; subscriptions need different endpoint
            revocationDate: nil,
            environment: "production"  // Google doesn't distinguish in same way
        )
    }

    private func getAccessToken() async throws -> String {
        // Parse service account JSON
        let serviceAccount = try JSONDecoder().decode(
            ServiceAccount.self,
            from: Data(config.serviceAccountJson.utf8)
        )

        // Create JWT for Google OAuth
        let now = Date()
        let claims = GoogleClaims(
            iss: serviceAccount.client_email,
            scope: "https://www.googleapis.com/auth/androidpublisher",
            aud: serviceAccount.token_uri,
            iat: now,
            exp: now.addingTimeInterval(3600)
        )

        // Sign JWT with service account private key
        let signer = try JWTSigner.rs256(key: .private(pem: serviceAccount.private_key))
        let jwt = try signer.sign(claims)

        // Exchange JWT for access token
        let response = try await httpClient.post(URI(string: serviceAccount.token_uri)) { req in
            try req.content.encode([
                "grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer",
                "assertion": jwt
            ], as: .urlEncodedForm)
        }

        guard response.status == .ok else {
            logger.error("Failed to get Google OAuth token",
                metadata: ["status": "\(response.status.code)"])
            throw PurchaseValidationError.networkError
        }

        let tokenResponse = try response.content.decode(TokenResponse.self)
        return tokenResponse.access_token
    }
}

struct GoogleClaims: JWTPayload {
    let iss: String
    let scope: String
    let aud: String
    let iat: Date
    let exp: Date

    func verify(using signer: JWTSigner) throws {
        // Validation handled by Google
    }
}
```

### Success Criteria

- [ ] Build succeeds
- [ ] OAuth token generation works
- [ ] Google Play API calls succeed
- [ ] Purchase state validation works
- [ ] Errors properly categorized

### Verification

```bash
swift build
```

### Notes

For production, consider:
- Token caching to avoid repeated OAuth calls
- Retry logic for transient failures
- Subscription endpoint for recurring purchases

Google Play API purchase states:
- 0 = Purchased
- 1 = Canceled
- 2 = Pending
