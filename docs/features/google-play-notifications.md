# Google Play Real-Time Developer Notifications

**Date:** 2026-03-19
**Related Files:** `Sources/App/Modules/Receipts/Controllers/GoogleNotificationsController.swift`, `Sources/App/Modules/Receipts/Services/GoogleNotificationService.swift`, `Sources/App/Services/Configuration/ConfigurationTypes.swift`

## Overview

The backend receives Google Play Real-Time Developer Notifications (RTDN) via a Cloud Pub/Sub push subscription endpoint, enabling near-real-time detection of Android refunds and voided purchases. Incoming messages are verified via a shared secret token in the query parameter, then decoded from the Pub/Sub base64 envelope to extract the developer notification payload.

## What Was Built

- `POST /api/v1/notifications/google` webhook endpoint for Cloud Pub/Sub push messages
- `GoogleNotificationService` for Pub/Sub message decoding and Voided Purchases API verification
- Token-based push subscription verification via `?token=` query parameter
- OAuth2 service account authentication with NIOLock-based token caching for the Voided Purchases API
- Pub/Sub message DTO types: `PubSubPushMessage`, `PubSubMessage`, `GoogleDeveloperNotification`, `OneTimeProductNotification`

## Technical Implementation

### Key Files

- `Sources/App/Modules/Receipts/Controllers/GoogleNotificationsController.swift`: Webhook controller that verifies the Pub/Sub token, delegates message decoding to the service, and routes by notification type (refund/canceled → mark refunded, unknown → log and acknowledge)
- `Sources/App/Modules/Receipts/Services/GoogleNotificationService.swift`: Protocol + implementation for base64 Pub/Sub message decoding, notification type mapping, and Voided Purchases API verification with OAuth2 token exchange
- `Sources/App/Services/Configuration/ConfigurationTypes.swift`: `GooglePlayConfig` extended with `pubsubVerificationToken` field

### Key Patterns

- **Token-based Pub/Sub verification**: Unlike Apple's JWS cryptographic verification, Google Pub/Sub push subscriptions use a shared secret token passed as a `?token=` query parameter. The controller compares this against `GOOGLE_PUBSUB_VERIFICATION_TOKEN` and returns HTTP 403 on mismatch — this is the only case where a non-200 response is returned.
- **Always-return-200 (except auth failure)**: Like the Apple endpoint, this endpoint returns HTTP 200 for all processing outcomes (success, decode errors, unknown transactions) to prevent Pub/Sub from retrying. Only token verification failure returns 403.
- **Base64-encoded Pub/Sub envelope**: Google wraps the RTDN payload in a Pub/Sub push message. The `data` field contains a base64-encoded JSON `DeveloperNotification`. The service handles the double-decode (base64 → JSON → typed struct).
- **Independent OAuth2 token cache**: The service maintains its own `NIOLock`-protected token cache (same pattern as `PlayStoreValidationService`) rather than sharing a token with the validation service. This avoids coupling and allows independent token lifetimes. Token cache is invalidated on 401 responses.
- **Voided Purchases API lookup**: For refund/canceled notifications, the service calls the Google Play Voided Purchases API to get the `orderId` (which maps to the `transactionId` in the database), then delegates to `markRefunded(transactionId:refundedAt:)`.

### Code Examples

```swift
// Adding a new notification type handler in GoogleNotificationsController:
case .oneTimeProductPurchased:
    req.logger.info("Received purchase notification", metadata: [
        "productId": .string(result.productId ?? "unknown")
    ])
    // Add business logic here
```

```swift
// Decoding a Pub/Sub message in tests or other services:
let result = try service.decodeNotification(base64Message: pushMessage.message.data)
switch result.notificationType {
case .oneTimeProductRefunded:
    // Handle refund
case .oneTimeProductCanceled:
    // Handle cancellation
default:
    // Log and acknowledge
}
```

## How to Use

1. **Configure Pub/Sub subscription** in Google Cloud Console to push to `POST /api/v1/notifications/google?token=<your-secret>`
2. **Register the topic** in Google Play Console under Monetization Setup → Real-time developer notifications
3. **Set the verification token** as `GOOGLE_PUBSUB_VERIFICATION_TOKEN` environment variable (must match the `?token=` parameter configured in the Pub/Sub subscription)
4. **Supported notification types**: `ONE_TIME_PRODUCT_CANCELED` (type 2) and `ONE_TIME_PRODUCT_REFUNDED` (type 3) mark the matching transaction as refunded; all others are logged and acknowledged
5. **To add a new notification type**: Add a case to the `switch` in `GoogleNotificationsController.handleNotification` using the `GoogleNotificationType` enum

## Configuration

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `GOOGLE_PUBSUB_VERIFICATION_TOKEN` | String | — | Shared secret for Pub/Sub push subscription verification |
| `GOOGLE_SERVICE_ACCOUNT_EMAIL` | String | — | Google service account email (shared with Play Store validation) |
| `GOOGLE_PRIVATE_KEY` | String | — | Google service account private key (shared with Play Store validation) |
| `GOOGLE_PACKAGE_NAME` | String | — | Android app package name (shared with Play Store validation) |

The last three environment variables are shared with `PlayStoreValidationService` — only `GOOGLE_PUBSUB_VERIFICATION_TOKEN` is new for this feature.

## Notes

- The endpoint uses **query parameter token verification** rather than cryptographic signature verification (unlike the Apple endpoint which uses JWS). This is the standard approach for Google Cloud Pub/Sub push subscriptions.
- The `GoogleNotificationType` enum maps integer notification types to typed cases. Only types 1-3 (purchased, canceled, refunded) are defined; all others map to `.unknown(Int)`.
- Reuses the `GoogleServiceAccountClaims` JWT struct from `PlayStoreValidationService` for OAuth2 token exchange, but maintains a separate token cache instance.
- The Voided Purchases API returns all voided purchases for the app; the service filters by `purchaseToken` to find the matching entry and extract its `orderId`.
- Mirrors the Apple notification controller structure exactly: verify → decode → dispatch by type → always return 200.
