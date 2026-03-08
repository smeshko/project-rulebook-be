# App Store Signed Transaction Validation

**Date:** 2026-03-08
**Related Files:** `Sources/App/Modules/Receipts/Services/AppStoreValidationService.swift`, `Sources/App/Services/Configuration/ConfigurationTypes.swift`

## Overview

Server-side verification of Apple App Store signed transactions (JWS) using Apple's `app-store-server-library-swift`. The service decodes and cryptographically validates JWS-encoded transaction data against Apple's root certificates, ensuring purchases are legitimate before crediting users.

## What Was Built

- `AppStoreValidationService` protocol for transaction verification
- `DefaultAppStoreValidationService` implementation using Apple's `SignedDataVerifier`
- `AppStoreValidationResult` struct capturing transaction details (ID, product, bundle, date, environment)
- `AppStoreValidationError` enum with specific failure cases
- `AppleConfig` configuration type with 6 environment variables
- `MockAppStoreValidationService` for use in controller tests (Story 2.4)

## Technical Implementation

### Key Files

- `Sources/App/Modules/Receipts/Services/AppStoreValidationService.swift`: Protocol, result type, error type, and default implementation
- `Sources/App/Services/Configuration/ConfigurationTypes.swift`: `AppleConfig` struct definition
- `Sources/App/Services/Configuration/ProductionConfiguration.swift`: Production env var loading with strict validation
- `Sources/App/Common/Extensions/Application+Services.swift`: Service registration in DI container
- `Sources/App/Common/Extensions/Request+Services.swift`: Request-scoped service accessor
- `Tests/AppTests/Services/Receipts/AppStoreValidationServiceTests.swift`: Unit tests with mock service

### Key Patterns

- **SignedDataVerifier Delegation**: Rather than manually parsing JWS tokens, the service delegates to Apple's `SignedDataVerifier` which handles signature verification, certificate chain validation, bundle ID matching, and environment checking. This ensures verification stays current with Apple's security requirements.

- **Embedded Root Certificate**: The Apple Root CA G3 certificate is embedded as a base64 string rather than loaded from a file. This avoids deployment path issues and matches the approach used in Apple's own test suite. The certificate is DER-encoded and decoded at runtime.

- **Error Mapping**: Apple's `VerificationError` cases are mapped to domain-specific `AppStoreValidationError` cases, keeping the App Store library as an implementation detail behind the protocol.

- **Environment-Aware Verification**: The `SignedDataVerifier` is initialized with the configured environment (sandbox/production), ensuring sandbox transactions are rejected in production and vice versa.

### Code Examples

**Verifying a signed transaction (in a controller):**
```swift
let result = try await req.services.appStoreValidation.verify(
    signedTransaction: requestBody.signedTransaction
)
// result.transactionId, result.productId, result.bundleId available
```

**Using the mock in tests:**
```swift
let mock = MockAppStoreValidationService()
mock.resultToReturn = AppStoreValidationResult(
    transactionId: "txn_123",
    productId: "com.app.credits.100",
    bundleId: "com.test.app",
    purchaseDate: Date(),
    environment: "Sandbox"
)
// Inject mock into test context
```

## How to Use

1. Set the required environment variables (see Configuration below)
2. The service is registered automatically in `Application-Setup.swift`
3. Access via `req.services.appStoreValidation` in any controller
4. Pass the client's signed transaction string to `verify(signedTransaction:)`
5. Handle `AppStoreValidationError` for invalid/tampered transactions

## Configuration

| Variable | Type | Required | Default (Dev) | Description |
|----------|------|----------|---------------|-------------|
| `APPLE_ISSUER_ID` | String | Production | `dev_issuer_id` | Issuer ID from App Store Connect |
| `APPLE_KEY_ID` | String | Production | `dev_key_id` | API key ID from App Store Connect |
| `APPLE_PRIVATE_KEY` | String | Production | `dev_private_key` | .p8 private key content |
| `APP_BUNDLE_ID` | String | Production | `com.dev.app` | iOS app bundle identifier |
| `APP_APPLE_ID` | Int64 | Production | `123456789` | Numeric App ID from App Store Connect |
| `APPLE_ENVIRONMENT` | String | No | `sandbox` (dev) / `production` (prod) | Must be "sandbox" or "production" |

## Notes

- Uses `app-store-server-library-swift` v2.x (not v4.0.0) due to jwt-kit 4.x compatibility — the project uses jwt v4.x, and library v4.0.0 requires jwt-kit 5.x
- The `MockAppStoreValidationService` in the test file is designed for reuse in Story 2.4 controller tests
- Bundle ID and environment validation are handled internally by `SignedDataVerifier` — no need for manual checks
- The service is initialized eagerly at app startup; configuration errors surface immediately
