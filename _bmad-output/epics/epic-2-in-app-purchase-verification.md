# Epic 2: In-App Purchase Verification

**Linear:** [RULE-147](https://linear.app/tsonev-inc/issue/RULE-147)

Enable server-side validation of App Store and Play Store purchases to secure the credit-based monetization system. Users can purchase credits with confidence that their transactions are securely verified.

## Story 2.1: Create Receipts Module Foundation
**Linear:** [RULE-136](https://linear.app/tsonev-inc/issue/RULE-136)

**As a** backend developer,
**I want** a Receipts module with database model and repository,
**So that** I can store validated transaction records.

**Acceptance Criteria:**

**Given** the project structure
**When** the Receipts module is created
**Then** it follows the established module pattern with:
- `ReceiptsModule.swift` for registration
- `ReceiptsRouter.swift` for route definitions
- `Controllers/ReceiptsController.swift`
- `Models/Receipts+Model.swift` for request/response DTOs
- `Database/Models/TransactionModel.swift`
- `Database/Migrations/ReceiptsMigrations.swift`
- `Repositories/ReceiptsRepository.swift`

**Given** the TransactionModel
**When** a transaction is stored
**Then** it captures: `id`, `transactionId` (from store), `platform` (ios/android), `productId`, `creditAmount` (1, 3, or 10), `createdAt`

**Given** the repository
**When** checking for duplicate transactions
**Then** it can query by `transactionId` to enforce idempotency

**Technical Notes:**
- Follow the existing module pattern from `UserModule` / `AuthModule`
- Register `ReceiptsModule` in the modules array in `Application-Setup.swift`
- Register `DatabaseReceiptsRepository` in `Application+Services.swift`
- `TransactionModel` uses Fluent `@ID`, `@Field`, `@Timestamp` property wrappers
- Migration follows `AsyncMigration` pattern with `prepare`/`revert`

**Files to Create:**
- `Sources/App/Modules/Receipts/ReceiptsModule.swift`
- `Sources/App/Modules/Receipts/ReceiptsRouter.swift`
- `Sources/App/Modules/Receipts/Controllers/ReceiptsController.swift`
- `Sources/App/Modules/Receipts/Models/Receipts+Model.swift`
- `Sources/App/Modules/Receipts/Database/Models/TransactionModel.swift`
- `Sources/App/Modules/Receipts/Database/Migrations/ReceiptsMigrations.swift`
- `Sources/App/Modules/Receipts/Repositories/ReceiptsRepository.swift`

**Files to Modify:**
- `Sources/App/Entrypoint/Application-Setup.swift` — Add `ReceiptsModule()` to modules array
- `Sources/App/Common/Extensions/Application+Services.swift` — Register `ReceiptsRepository`

---

## Story 2.2: Implement App Store Receipt Validation
**Linear:** [RULE-252](https://linear.app/tsonev-inc/issue/RULE-252)

**As a** iOS app user,
**I want** my App Store purchases validated server-side,
**So that** my credits are securely verified.

**Acceptance Criteria:**

**Given** a valid App Store receipt
**When** the `AppStoreValidationService` validates it
**Then** it calls Apple's App Store Server API
**And** returns success with the product ID and transaction ID

**Given** an invalid or tampered receipt
**When** validation is attempted
**Then** the service returns failure with appropriate error

**Given** a previously validated transaction ID
**When** the same receipt is submitted again
**Then** validation succeeds but is marked as duplicate (idempotent)

**Given** the service configuration
**When** the service is initialized
**Then** it uses environment variables for Apple API credentials

**Technical Notes:**
- Apple App Store Server API v2 — verify signed transactions (JWS)
- Use `JWT` package (already in `Package.swift`) for JWS decoding and signature verification
- Apple credentials needed: issuer ID, key ID, private key, bundle ID — all from env vars
- Service should be registered in `Application+Services.swift` for injection
- Consider using Apple's `x5c` certificate chain for JWS verification

**Files to Create:**
- `Sources/App/Modules/Receipts/Services/AppStoreValidationService.swift`

**Files to Modify:**
- `Sources/App/Common/Extensions/Application+Services.swift` — Register service

---

## Story 2.3: Implement Play Store Receipt Validation
**Linear:** [RULE-253](https://linear.app/tsonev-inc/issue/RULE-253)

**As an** Android app user,
**I want** my Play Store purchases validated server-side,
**So that** my credits are securely verified.

**Acceptance Criteria:**

**Given** a valid Play Store purchase token
**When** the `PlayStoreValidationService` validates it
**Then** it calls Google Play Developer API
**And** returns success with the product ID and transaction ID

**Given** an invalid or tampered purchase token
**When** validation is attempted
**Then** the service returns failure with appropriate error

**Given** a previously validated transaction ID
**When** the same purchase is submitted again
**Then** validation succeeds but is marked as duplicate (idempotent)

**Given** the service configuration
**When** the service is initialized
**Then** it uses environment variables for Google API credentials

**Technical Notes:**
- Google Play Developer API `purchases.products.get` for one-time product verification
- Requires Google service account credentials (JSON key) — path from env var
- Service account must have "View financial data" permission in Google Play Console
- Use Vapor's `AsyncHTTPClient` for Google API calls with OAuth2 service account token
- Token refresh should be handled automatically (cache token, refresh on 401)

**Files to Create:**
- `Sources/App/Modules/Receipts/Services/PlayStoreValidationService.swift`

**Files to Modify:**
- `Sources/App/Common/Extensions/Application+Services.swift` — Register service

---

## Story 2.4: Create Receipt Validation Endpoint
**Linear:** [RULE-137](https://linear.app/tsonev-inc/issue/RULE-137)

**As a** mobile app,
**I want** a single endpoint to validate purchases,
**So that** I can verify transactions regardless of platform.

**Acceptance Criteria:**

**Given** a POST request to `/api/v1/receipts/validate`
**When** the request contains `{ "platform": "ios", "receiptData": "...", "productId": "..." }`
**Then** the App Store validation service is called
**And** success response `{ "success": true, "status": "valid", "transactionId": "..." }` is returned

**Given** a POST request to `/api/v1/receipts/validate`
**When** the request contains `{ "platform": "android", "purchaseToken": "...", "productId": "..." }`
**Then** the Play Store validation service is called
**And** success response `{ "success": true, "status": "valid", "transactionId": "..." }` is returned

**Given** a duplicate transaction ID
**When** the same receipt is submitted again
**Then** response `{ "success": true, "status": "already_processed", "transactionId": "..." }` is returned (idempotent, 200)

**Given** a validation failure
**When** the receipt/token is invalid
**Then** response `{ "success": false, "status": "invalid", "error": "..." }` is returned with 403

**Given** a successful validation
**When** the transaction is new (not duplicate)
**Then** the transaction is stored in the database

**Given** a valid product ID
**When** validating a purchase
**Then** the product maps to credit amounts: `credits_1` → 1, `credits_3` → 3, `credits_10` → 10

**Technical Notes:**
- Controller delegates to platform-specific service based on `platform` field
- Use `Content` protocol for request/response DTO decoding
- Product-to-credits mapping should be in a shared constant or configuration
- Route registered in `ReceiptsRouter` under grouped `/api/v1/receipts`
- All responses use a consistent shape: `{ "success": bool, "status": string, "transactionId?": string, "error?": string }` — this allows Story 2.9 to add `"status": "pending"` without changing the contract
- Return 400 for malformed requests, 403 for invalid receipts, 200 for success/duplicate

**Files to Modify:**
- `Sources/App/Modules/Receipts/Controllers/ReceiptsController.swift` — Implement validate action
- `Sources/App/Modules/Receipts/ReceiptsRouter.swift` — Register POST route
- `Sources/App/Modules/Receipts/Models/Receipts+Model.swift` — Define request/response DTOs

**Dependencies:** Stories 2.1 (module foundation), 2.2 (Apple service), 2.3 (Google service)

---

## Story 2.5: Add Receipt Hash Storage and Bundle ID Validation
**Linear:** [RULE-247](https://linear.app/tsonev-inc/issue/RULE-247)

**As a** backend developer,
**I want** to store receipt hashes and validate bundle/package IDs before processing,
**So that** tampered or misrouted receipts are rejected and receipt data is traceable.

**Acceptance Criteria:**

**Given** a receipt validation request
**When** the receipt data is received
**Then** a SHA-256 hash of the receipt/token payload is computed and stored on the TransactionModel as `receiptHash`

**Given** an Android purchase token
**When** validation is attempted
**Then** the controller verifies the `packageName` request field matches the configured app package name before calling Google's API

**Given** an iOS receipt
**When** validation is attempted
**Then** the `AppStoreValidationService` verifies the `bundleId` inside the decoded JWS matches the configured app bundle ID as part of its verification flow

**Given** a mismatched bundle ID or package name
**When** validation is attempted
**Then** the request is rejected with 403 and error `"invalid_app_identity"`

**Technical Notes:**
- Add `receiptHash` (`String`) field to `TransactionModel` — requires a new migration (`ReceiptsMigrations.v2`)
- SHA-256 via Swift `Crypto` framework (already available in Vapor)
- Bundle ID and package name configured via environment variables: `APP_BUNDLE_ID`, `APP_PACKAGE_NAME`
- Android `packageName` check happens in the controller (sent as a request field)
- iOS `bundleId` check happens inside `AppStoreValidationService` (extracted from JWS payload during decoding — cannot be checked before decoding)
- `receiptHash` enables receipt-based rate limiting in Story 2.6

**Files to Modify:**
- `Sources/App/Modules/Receipts/Database/Models/TransactionModel.swift` — Add `receiptHash` field
- `Sources/App/Modules/Receipts/Database/Migrations/ReceiptsMigrations.swift` — Add v2 migration
- `Sources/App/Modules/Receipts/Controllers/ReceiptsController.swift` — Add hash computation + Android `packageName` check
- `Sources/App/Modules/Receipts/Services/AppStoreValidationService.swift` — Add iOS `bundleId` check during JWS decoding

**Dependencies:** Story 2.1 (TransactionModel), 2.2 (AppStoreValidationService must exist to add bundleId check)

**PRD Reference:** FR1.5, NFR Security (bundle ID validation)

---

## Story 2.6: Implement Rate Limiting for Validation Endpoint
**Linear:** [RULE-248](https://linear.app/tsonev-inc/issue/RULE-248)

**As a** backend developer,
**I want** rate limiting on the receipt validation endpoint,
**So that** abuse and brute-force attempts are throttled.

**Acceptance Criteria:**

**Given** a receipt validation request
**When** the same receipt hash has been submitted more than 10 times in the past hour
**Then** the request is rejected with 429 and a `Retry-After` header

**Given** a receipt validation request
**When** the originating IP address has submitted more than 30 requests in the past hour
**Then** the request is rejected with 429 and a `Retry-After` header

**Given** rate limit state
**When** tracking request counts
**Then** counts are stored in-memory with automatic TTL expiry

**Given** a rate-limited response
**When** the client receives 429
**Then** the response body includes `{ "error": "rate_limited", "retryAfter": <seconds> }`

**Technical Notes:**
- Existing `RateLimitMiddleware` at `Middlewares/Security/RateLimit/` already supports operation-specific limits — extend it with a new `receipt` operation type
- IP-based limiting uses the existing middleware infrastructure
- Receipt-hash-based limiting is a secondary check inside the controller (hash is computed from request body, not available at middleware level)
- Add `receipt` case to `RateLimitConfiguration` with 10 req/hr per hash, 30 req/hr per IP
- `Retry-After` header value = seconds until the oldest request in the window expires

**Files to Modify:**
- `Sources/App/Middlewares/Security/RateLimit/RateLimitConfiguration.swift` — Add `receipt` operation type
- `Sources/App/Modules/Receipts/ReceiptsRouter.swift` — Apply rate limit middleware to validation route
- `Sources/App/Modules/Receipts/Controllers/ReceiptsController.swift` — Add receipt-hash-based rate check

**Dependencies:** Story 2.5 (receipt hash computation)

**PRD Reference:** FR2.1–FR2.3

---

## Story 2.7: Register for App Store Server Notifications V2
**Linear:** [RULE-249](https://linear.app/tsonev-inc/issue/RULE-249)

**As a** backend developer,
**I want** to receive Apple's server-to-server notifications,
**So that** refunds and other transaction lifecycle events are detected in near-real-time.

**Acceptance Criteria:**

**Given** the backend deployment
**When** configured for production
**Then** a `POST /api/v1/notifications/apple` endpoint exists to receive App Store Server Notifications V2

**Given** an incoming Apple notification
**When** the signed payload is received
**Then** the backend verifies the JWS signature against Apple's root certificate before processing

**Given** a `REFUND` notification type
**When** the notification is verified
**Then** the matching transaction is marked as `refunded` in the database with a `refundedAt` timestamp

**Given** a `REVOKE` notification type
**When** the notification is verified
**Then** the matching transaction is marked as `revoked` in the database

**Given** an unknown or unsupported notification type
**When** received
**Then** the payload is logged and acknowledged with 200 (no error)

**Technical Notes:**
- Apple sends signed JWS payloads — verify using Apple's root CA certificate (download and bundle with app, or fetch from Apple's PKI)
- Decode `signedPayload` → extract `notificationType` and `subtype`
- Handle types: `REFUND`, `REVOKE`, `CONSUMPTION_REQUEST` (log only for now)
- Add `status` enum field to `TransactionModel`: `valid`, `refunded`, `revoked` — requires migration v3
- Add `refundedAt` optional `Date` field to `TransactionModel`
- Endpoint must always return 200 to Apple (even on processing errors) to prevent retries
- Register notification URL in App Store Connect under "App Store Server Notifications"

**Files to Create:**
- `Sources/App/Modules/Receipts/Controllers/AppleNotificationsController.swift`

**Files to Modify:**
- `Sources/App/Modules/Receipts/ReceiptsRouter.swift` — Add notification route
- `Sources/App/Modules/Receipts/Database/Models/TransactionModel.swift` — Add `status`, `refundedAt` fields
- `Sources/App/Modules/Receipts/Database/Migrations/ReceiptsMigrations.swift` — Add v3 migration
- `Sources/App/Modules/Receipts/Repositories/ReceiptsRepository.swift` — Add `markRefunded(transactionId:)` method

**Dependencies:** Stories 2.1 (TransactionModel, repository), 2.5 (must run after v2 migration)

**PRD Reference:** FR4.1–FR4.3

---

## Story 2.8: Register for Google Play Real-Time Developer Notifications
**Linear:** [RULE-250](https://linear.app/tsonev-inc/issue/RULE-250)

**As a** backend developer,
**I want** to receive Google Play RTDN push notifications,
**So that** Android refunds and voided purchases are detected.

**Acceptance Criteria:**

**Given** the backend deployment
**When** configured for production
**Then** a `POST /api/v1/notifications/google` endpoint exists to receive Google Cloud Pub/Sub push messages

**Given** an incoming RTDN message
**When** the Pub/Sub message is received
**Then** the backend verifies the message authenticity via the Pub/Sub push subscription token

**Given** a voided purchase notification
**When** the voided purchase is verified via Google Play Voided Purchases API
**Then** the matching transaction is marked as `refunded` in the database with a `refundedAt` timestamp

**Given** an unknown or unsupported notification type
**When** received
**Then** the payload is logged and acknowledged with 200

**Technical Notes:**
- Google sends RTDN via Cloud Pub/Sub push subscriptions — the endpoint receives a wrapped JSON message
- Pub/Sub message body is base64-encoded; decode to get `DeveloperNotification` with `oneTimeProductNotification`
- Verify push subscription by checking the `?token=` query parameter against a configured secret
- On receiving a `ONE_TIME_PRODUCT_CANCELED` or `ONE_TIME_PRODUCT_REFUNDED` notification, call Voided Purchases API to confirm, then mark transaction
- Reuses the same `status` / `refundedAt` fields from Story 2.7 migration
- Register Pub/Sub subscription in Google Play Console → Monetization setup

**Files to Create:**
- `Sources/App/Modules/Receipts/Controllers/GoogleNotificationsController.swift`

**Files to Modify:**
- `Sources/App/Modules/Receipts/ReceiptsRouter.swift` — Add Google notification route
- `Sources/App/Modules/Receipts/Repositories/ReceiptsRepository.swift` — Reuse `markRefunded(transactionId:)` from 2.7

**Dependencies:** Story 2.7 (shared `status`/`refundedAt` migration and repository method)

**PRD Reference:** FR4.1–FR4.3 (Android parity)

---

## Story 2.9: Handle Store API Downtime Gracefully
**Linear:** [RULE-251](https://linear.app/tsonev-inc/issue/RULE-251)

**As a** backend developer,
**I want** the validation endpoint to handle Apple/Google API outages,
**So that** no valid purchases are lost when upstream services are temporarily unavailable.

**Acceptance Criteria:**

**Given** a receipt validation request
**When** the Apple or Google API returns a 5xx error or times out
**Then** the transaction is stored in a `pending_validation` state in the database

**Given** pending validations exist
**When** a scheduled job runs (every 5 minutes)
**Then** it retries validation for all pending transactions with exponential backoff (max 3 retries)

**Given** a pending validation
**When** retry succeeds
**Then** the transaction status is updated to `valid` or `invalid` based on the store's response

**Given** a pending validation
**When** all 3 retries are exhausted
**Then** the transaction is marked as `validation_failed` and an alert is logged for manual review

**Given** the validation response to the client
**When** the store API is unreachable
**Then** the endpoint returns 202 Accepted with `{ "success": true, "status": "pending", "transactionId": "..." }`

**Technical Notes:**
- Extend `TransactionModel.status` enum: add `pending_validation`, `validation_failed` states
- Store the raw receipt/token payload in a new `receiptData` text field so it can be retried (migration v4)
- Scheduled job uses Vapor's `LifecycleHandler` or Queues package for background task execution
- Backoff: 5min, 20min, 60min (3 attempts)
- On `validation_failed`, log at `.critical` level for ops alerting
- Client receives 202 with a `transactionId` they can poll later (or rely on iOS/Android client retry from Stories 3.10/3.5)
- Add `retryCount` and `lastRetryAt` fields to `TransactionModel` for tracking

**Files to Create:**
- `Sources/App/Modules/Receipts/Jobs/PendingValidationJob.swift`

**Files to Modify:**
- `Sources/App/Modules/Receipts/Database/Models/TransactionModel.swift` — Add `receiptData`, `retryCount`, `lastRetryAt` fields; extend status enum
- `Sources/App/Modules/Receipts/Database/Migrations/ReceiptsMigrations.swift` — Add v4 migration
- `Sources/App/Modules/Receipts/Controllers/ReceiptsController.swift` — Return 202 on upstream failure
- `Sources/App/Modules/Receipts/Repositories/ReceiptsRepository.swift` — Add `findPendingValidations()` query
- `Sources/App/Entrypoint/Application-Setup.swift` — Register scheduled job

**Dependencies:** Stories 2.2/2.3 (validation services), 2.7 (status field on TransactionModel, must run after v3 migration)

**Migration ordering:** v1 (2.1) → v2 (2.5) → v3 (2.7) → v4 (2.9) — stories must be implemented in this order to avoid migration conflicts

**PRD Reference:** NFR Reliability

---
