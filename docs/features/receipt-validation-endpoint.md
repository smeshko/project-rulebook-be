# Receipt Validation Endpoint

**Date:** 2026-03-15
**Related Files:** `Sources/App/Modules/Receipts/Controllers/ReceiptsController.swift`, `Sources/App/Modules/Receipts/ReceiptsRouter.swift`, `Sources/App/Entities/Receipts/Receipts.swift`, `Sources/App/Modules/Receipts/Models/Receipts+Model.swift`

## Overview

A unified `POST /api/v1/receipts/validate` endpoint that validates in-app purchase receipts for both iOS (App Store) and Android (Play Store) platforms. The controller delegates to platform-specific validation services, enforces idempotency via duplicate transaction detection, maps products to credit amounts, and returns a consistent response shape across all outcomes.

## What Was Built

- `Receipts.Validate.Request` and `Receipts.Validate.Response` DTOs with `Content` conformance
- `ReceiptsController.validate` action with platform branching, error handling, and transaction storage
- `POST /api/v1/receipts/validate` route with OpenAPI documentation
- Static product-to-credits mapping (`credits_1` → 1, `credits_3` → 3, `credits_10` → 10)
- Product ID cross-validation against store receipt responses
- 11 integration/unit tests covering all acceptance criteria

## Technical Implementation

### Key Files

- `Sources/App/Entities/Receipts/Receipts.swift`: Defines `Receipts.Validate.Request` and `Receipts.Validate.Response` using the project's enum-based DTO pattern
- `Sources/App/Modules/Receipts/Models/Receipts+Model.swift`: `Content` conformance for DTOs and `creditAmount(for:)` static helper
- `Sources/App/Modules/Receipts/Controllers/ReceiptsController.swift`: Main validation logic with platform branching and error mapping
- `Sources/App/Modules/Receipts/ReceiptsRouter.swift`: Route registration under `/api/v1/receipts` with OpenAPI metadata

### Key Patterns

- **Platform-Switching Controller**: The `validate` action branches on `platform.lowercased()` to dispatch to the correct validation service (`appStoreValidation` or `playStoreValidation`). Each branch validates platform-specific required fields (`receiptData` for iOS, `purchaseToken` for Android) before calling the service.

- **Custom HTTP Status with Response Body**: Since Vapor's `Content` protocol returns HTTP 200 by default, the controller returns `Response` (not `Content`) and uses `body.encodeResponse(status:for:)` to set custom status codes (403 for invalid receipts, 200 for success/duplicate). This pattern is necessary when the same response DTO must be returned with different HTTP statuses.

- **Error-Type-Specific Catch Blocks**: Platform validation errors are caught by their concrete types (`AppStoreValidationError`, `PlayStoreValidationError`) and mapped to a `{ success: false, status: "invalid", error: "..." }` response with HTTP 403. Unexpected errors propagate as standard Abort errors.

- **Product ID Cross-Validation**: After store validation succeeds, the controller verifies that the `productId` returned by the store matches the `productId` in the request. A mismatch returns 403 with a generic error to prevent product spoofing.

### Code Examples

**Calling the validation endpoint:**
```json
// iOS request
POST /api/v1/receipts/validate
{
  "platform": "ios",
  "receiptData": "<signed-transaction-JWS>",
  "productId": "credits_10"
}

// Android request
POST /api/v1/receipts/validate
{
  "platform": "android",
  "purchaseToken": "<purchase-token>",
  "productId": "credits_3"
}
```

**Response shapes:**
```json
// Success (200)
{ "success": true, "status": "valid", "transactionId": "1000000123456789" }

// Duplicate (200)
{ "success": true, "status": "already_processed", "transactionId": "1000000123456789" }

// Invalid receipt (403)
{ "success": false, "status": "invalid", "error": "invalidSignature" }
```

**Adding a new product tier:**
```swift
// In Receipts+Model.swift
static let productCreditAmounts: [String: Int] = [
    "credits_1": 1,
    "credits_3": 3,
    "credits_10": 10,
    "credits_25": 25,  // Add new tier here
]
```

## How to Use

1. Send a `POST` request to `/api/v1/receipts/validate` with platform, receipt data, and product ID
2. The endpoint validates the receipt with the platform-specific service
3. On success, the transaction is stored in the database with mapped credit amount
4. Duplicate submissions return `already_processed` (idempotent, HTTP 200)
5. Invalid receipts return HTTP 403 with error details

## Configuration

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `productCreditAmounts` | `[String: Int]` | 3 tiers | Maps product IDs to credit amounts; add new entries for new tiers |
| Platform services | Service | Required | `appStoreValidation` and `playStoreValidation` must be registered on `Application` |

## Notes

- The response shape `{ success, status, transactionId?, error? }` is designed to support future `"status": "pending"` for async validation (Story 2.9)
- Platform comparison is case-insensitive via `.lowercased()`
- The `encodeResponse(status:for:)` pattern must be used (not returning `Content` directly) to support the 403 status for invalid receipts
- Product-to-credits mapping is a static dictionary; for dynamic pricing, this would need to move to configuration or database
