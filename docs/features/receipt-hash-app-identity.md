# Receipt Hash Storage and App Identity Validation

**Date:** 2026-03-15
**Related Files:** `Sources/App/Modules/Receipts/Controllers/ReceiptsController.swift`, `Sources/App/Modules/Receipts/Database/Models/TransactionModel.swift`, `Sources/App/Modules/Receipts/Database/Migrations/ReceiptsMigrations.swift`, `Sources/App/Modules/Receipts/Services/AppStoreValidationService.swift`, `Sources/App/Entities/Receipts/Receipts.swift`

## Overview

Adds SHA-256 receipt hash computation and storage on `TransactionModel`, plus app identity validation (bundle ID for iOS, package name for Android) to reject tampered or misrouted receipts before processing. These security measures protect against receipt replay across apps and enable receipt-based rate limiting in Story 2.6.

## What Was Built

- SHA-256 receipt hash computation from receipt payload, stored as `receiptHash` on `TransactionModel`
- Database migration (v2) adding `receiptHash` column with default empty string for existing rows
- Android `packageName` validation in `ReceiptsController` before calling Play Store API
- iOS `bundleId` defense-in-depth check in `AppStoreValidationService.extractResult(from:)`
- Consistent `"invalid_app_identity"` error response for both platforms (HTTP 403)
- 7 new tests covering hash storage, determinism, and identity validation

## Technical Implementation

### Key Files

- `Sources/App/Modules/Receipts/Controllers/ReceiptsController.swift`: Receipt hash computation via `computeReceiptHash(_:)`, Android packageName validation against `GooglePlayConfig.packageName`, and iOS `bundleIdMismatch` error mapping to `"invalid_app_identity"`
- `Sources/App/Modules/Receipts/Database/Models/TransactionModel.swift`: Added `receiptHash` field under `FieldKeys.v2` namespace
- `Sources/App/Modules/Receipts/Database/Migrations/ReceiptsMigrations.swift`: v2 migration adding `receipt_hash` column with `.sql(.default(""))` for existing rows
- `Sources/App/Modules/Receipts/Services/AppStoreValidationService.swift`: Explicit bundleId check in `extractResult(from:)` comparing decoded JWS bundleId against `AppleConfig.bundleId`
- `Sources/App/Entities/Receipts/Receipts.swift`: Added optional `packageName` field to `Receipts.Validate.Request`

### Key Patterns

- **Defense-in-Depth Bundle ID Check**: Apple's `SignedDataVerifier` already validates the bundle ID during JWS verification. An additional explicit check in `extractResult(from:)` throws `AppStoreValidationError.bundleIdMismatch` if the decoded bundleId doesn't match the configured value. This guards against library behavior changes or configuration mismatches.

- **Pre-API Identity Validation**: Android packageName validation occurs *before* calling the Play Store API, avoiding unnecessary API calls for misrouted requests. iOS bundleId validation happens *after* JWS decoding because the bundleId is embedded in the signed payload and cannot be checked before decoding.

- **Consistent Error Surface**: Both platforms return the same error structure: `{ success: false, status: "invalid", error: "invalid_app_identity" }` with HTTP 403. The iOS `bundleIdMismatch` error is mapped to this string in the controller's catch block.

- **Receipt Hash for Traceability**: The SHA-256 hash uses the existing `SHA256.hash(_:) -> String` extension (64-character lowercase hex). iOS hashes `receiptData`, Android hashes `purchaseToken`. The hash is deterministic, enabling receipt-based rate limiting in Story 2.6.

### Code Examples

**Android request with packageName:**
```json
POST /api/v1/receipts/validate
{
  "platform": "android",
  "purchaseToken": "<token>",
  "productId": "credits_3",
  "packageName": "com.yourapp.package"
}
```

**Receipt hash computation (internal):**
```swift
private func computeReceiptHash(_ payload: String) -> String {
    SHA256.hash(payload) // Returns 64-char hex string
}
```

## How to Use

1. Android clients must include `packageName` in the validation request; omitting it returns 403
2. iOS clients need no changes — bundle ID is extracted from the JWS payload automatically
3. The `receiptHash` is stored automatically on successful transactions
4. Query `TransactionModel` by `receiptHash` for traceability or rate limiting

## Configuration

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `APP_BUNDLE_ID` | String | `com.dev.app` (dev) | iOS bundle identifier checked against decoded JWS |
| `APP_PACKAGE_NAME` | String | `com.dev.app` (dev) | Android package name checked against request field |

## Notes

- The v2 migration uses `.sql(.default(""))` so existing rows get an empty string rather than failing the NOT NULL constraint
- `receiptHash` enables receipt-based rate limiting planned for Story 2.6
- Android packageName is validated in the controller (sent in request); iOS bundleId is validated in the service (extracted from JWS) — this asymmetry is inherent to how each platform provides app identity
- Missing `packageName` on Android is treated the same as a mismatch (returns `invalid_app_identity`)
