# Play Store Purchase Validation

**Date:** 2026-03-14
**Related Files:** `Sources/App/Modules/Receipts/Services/PlayStoreValidationService.swift`, `Sources/App/Services/Configuration/ConfigurationTypes.swift`

## Overview

Server-side verification of Google Play Store one-time purchases using the Google Play Developer API. The service authenticates via OAuth2 service account JWT flow, exchanges the JWT for an access token, then calls `purchases.products.get` to validate purchase tokens submitted by Android clients.

## What Was Built

- `PlayStoreValidationService` protocol for purchase verification
- `DefaultPlayStoreValidationService` implementation with OAuth2 JWT authentication
- `PlayStoreValidationResult` struct capturing transaction details (order ID, product ID, purchase date)
- `PlayStoreValidationError` enum with specific failure cases (invalidToken, purchaseNotFound, configurationError, verificationFailed, apiError)
- `GooglePlayConfig` configuration type with 3 environment variables
- `MockPlayStoreValidationService` for use in controller tests (Story 2.4)
- OAuth2 access token caching with thread-safe `NIOLock` and 5-minute expiry safety margin

## Technical Implementation

### Key Files

- `Sources/App/Modules/Receipts/Services/PlayStoreValidationService.swift`: Protocol, result/error types, JWT claims, Google API response types, and default implementation
- `Sources/App/Services/Configuration/ConfigurationTypes.swift`: `GooglePlayConfig` struct definition
- `Sources/App/Services/Configuration/ProductionConfiguration.swift`: Production env var loading
- `Sources/App/Common/Extensions/Application+Services.swift`: Service registration in DI container
- `Sources/App/Entrypoint/Application-Setup.swift`: Service initialization at startup
- `Tests/AppTests/Services/Receipts/PlayStoreValidationServiceTests.swift`: Unit tests with mock service

### Key Patterns

- **OAuth2 Service Account JWT Flow**: The service generates a JWT signed with RS256 using the service account private key, exchanges it at Google's token endpoint for an access token, then uses that token as a Bearer header for API calls. This is the standard Google service account authentication pattern — no user interaction required.

- **Token Caching with Safety Margin**: Access tokens are cached with `NIOLock` for thread safety. The cached token's expiry is set to `expiresIn - 300` seconds (5-minute safety margin) to prevent using tokens that are about to expire during in-flight requests.

- **PEM Key Newline Normalization**: Environment variables often store PEM keys with literal `\n` instead of actual newlines. The service normalizes `\\n` → `\n` before parsing, which is critical for keys loaded from `.env` files or container orchestration secrets.

- **Purchase State Validation**: The Google Play API response includes a `purchaseState` field (0=Purchased, 1=Canceled, 2=Pending). The service explicitly validates that `purchaseState == 0` before accepting a purchase, rejecting canceled or pending purchases.

- **URL Encoding for API Path Parameters**: Product IDs and purchase tokens are percent-encoded before being interpolated into the API URL path to prevent injection and handle special characters.

### Code Examples

**Verifying a Play Store purchase (in a controller):**
```swift
let result = try await req.application.playStoreValidationService.verify(
    productId: requestBody.productId,
    purchaseToken: requestBody.purchaseToken
)
// result.transactionId = Google Play order ID
// result.productId = SKU
// result.purchaseDate = purchase timestamp
```

**Using the mock in tests:**
```swift
let mock = MockPlayStoreValidationService()
mock.resultToReturn = PlayStoreValidationResult(
    transactionId: "GPA.1234-5678",
    productId: "com.app.credits.100",
    purchaseDate: Date()
)
// Inject mock into test context
```

## How to Use

1. Set the required environment variables (see Configuration below)
2. The service is registered automatically in `Application-Setup.swift`
3. Access via `req.application.playStoreValidationService` in any controller
4. Pass the client's product ID and purchase token to `verify(productId:purchaseToken:)`
5. Handle `PlayStoreValidationError` for invalid/tampered purchases

## Configuration

| Variable | Type | Required | Default (Dev) | Description |
|----------|------|----------|---------------|-------------|
| `GOOGLE_SERVICE_ACCOUNT_EMAIL` | String | Production | `test@project.iam.gserviceaccount.com` | Service account email from Google Cloud Console |
| `GOOGLE_PRIVATE_KEY` | String | Production | Test RSA key | PEM-format private key from service account JSON |
| `GOOGLE_PACKAGE_NAME` | String | Production | `com.test.app` | Android application package name |

## Notes

- Uses `JWTKit` (already a project dependency via Vapor's JWT package) for RS256 JWT signing — no new dependencies required
- The service account must have "View financial data" permission in Google Play Console
- Token cache invalidation happens automatically on 401 responses, triggering re-authentication on the next call
- The `MockPlayStoreValidationService` in the test file is designed for reuse in Story 2.4 controller tests
- Mirrors the `AppStoreValidationService` pattern for consistency across platforms
- `TransactionPlatform.android` already exists in the database model from the Receipts module foundation (Story 2.1)
