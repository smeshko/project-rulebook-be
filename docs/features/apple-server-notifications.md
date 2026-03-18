# Apple App Store Server Notifications V2

**Date:** 2026-03-18
**Related Files:** `Sources/App/Modules/Receipts/Controllers/AppleNotificationsController.swift`, `Sources/App/Modules/Receipts/Services/AppleNotificationService.swift`, `Sources/App/Modules/Receipts/Database/Models/TransactionModel.swift`, `Sources/App/Modules/Receipts/Repositories/ReceiptsRepository.swift`

## Overview

The backend receives Apple App Store Server Notifications V2 via a webhook endpoint, enabling near-real-time detection of refunds, revocations, and other transaction lifecycle events. Incoming JWS-signed payloads are cryptographically verified against Apple's root CA certificate before processing.

## What Was Built

- `POST /api/v1/notifications/apple` webhook endpoint (unauthenticated — verification via JWS)
- `AppleNotificationService` for JWS signature verification and payload extraction
- Transaction status tracking with `TransactionStatus` enum (`valid`, `refunded`, `revoked`)
- `markRefunded` and `markRevoked` repository methods for transaction state updates
- Database migration v3 adding `status` and `refunded_at` columns to `transactions` table

## Technical Implementation

### Key Files

- `Sources/App/Modules/Receipts/Controllers/AppleNotificationsController.swift`: Webhook controller that receives Apple notifications, delegates verification to the service layer, and routes by notification type
- `Sources/App/Modules/Receipts/Services/AppleNotificationService.swift`: JWS verification using `SignedDataVerifier` from `AppStoreServerLibrary`, extracts notification type and transaction ID
- `Sources/App/Modules/Receipts/Database/Models/TransactionModel.swift`: `TransactionStatus` enum and `status`/`refundedAt` fields (v3 schema)
- `Sources/App/Modules/Receipts/Repositories/ReceiptsRepository.swift`: `markRefunded(transactionId:refundedAt:)` and `markRevoked(transactionId:)` methods

### Key Patterns

- **Always-return-200**: The endpoint returns HTTP 200 for all requests — valid, invalid, or errored — to prevent Apple from retrying notifications. Error handling is done via logging, not HTTP status codes.
- **Service-layer JWS verification**: The controller does not handle cryptography directly. `AppleNotificationService` encapsulates `SignedDataVerifier` creation and payload decoding, keeping the controller focused on routing logic.
- **Silent unknown-transaction handling**: If a REFUND or REVOKE references a transaction not in the database, the endpoint logs a warning and returns 200. This avoids errors from transactions created before the feature existed or from other apps.
- **String-based enum storage**: `TransactionStatus` is stored as `.string` type (not a PostgreSQL enum) for SQLite test compatibility. The migration uses separate `ALTER TABLE` statements since SQLite doesn't support multi-column `ALTER`.

### Code Examples

```swift
// Adding a new notification type handler in AppleNotificationsController:
case .consumptionRequest:
    req.logger.info("Received CONSUMPTION_REQUEST", metadata: [
        "originalTransactionId": .string(result.originalTransactionId ?? "none")
    ])
    // Add business logic here
```

```swift
// Using the repository to update transaction status:
let updated = try await req.repositories.receipts.markRefunded(
    transactionId: originalTransactionId,
    refundedAt: Date()
)
// `updated` is false if no matching transaction exists
```

## How to Use

1. **Apple sends a notification** to `POST /api/v1/notifications/apple` with a `signedPayload` JSON body
2. **Register the webhook URL** in App Store Connect under App Store Server Notifications (set to V2)
3. **Supported notification types**: REFUND (marks transaction refunded), REVOKE (marks transaction revoked), all others are logged and acknowledged
4. **To add a new notification type**: Add a case to the `switch` in `AppleNotificationsController.handleNotification`, using the `NotificationTypeV2` enum from `AppStoreServerLibrary`

## Configuration

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `APPLE_BUNDLE_ID` | String | — | iOS app bundle identifier |
| `APPLE_APP_APPLE_ID` | Int | — | App Apple ID from App Store Connect |
| `APPLE_ENVIRONMENT` | String | — | `production` or `sandbox` |

These are the same environment variables used by `AppStoreValidationService` — no additional configuration is required for notifications.

## Notes

- The endpoint has **no authentication middleware** — verification is done cryptographically via JWS against Apple's Root CA G3 certificate
- `@preconcurrency import AppStoreServerLibrary` is used to suppress Sendable conformance warnings from the library
- The `TransactionStatus` field defaults to `valid` for all existing rows via the migration's `DEFAULT` clause
- Future notification types (e.g., `DID_RENEW`, `SUBSCRIBED`) can be handled by extending the switch statement without schema changes
