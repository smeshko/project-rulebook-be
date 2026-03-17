# Receipt Validation Rate Limiting

**Date:** 2026-03-17
**Related Files:** `Sources/App/Middlewares/Security/RateLimit/`, `Sources/App/Modules/Receipts/Controllers/ReceiptsController.swift`

## Overview

Two-layer rate limiting for the receipt validation endpoint (`/api/v1/receipts/validate`) that throttles abuse and brute-force attempts against the in-app purchase verification system. Layer 1 is IP-based (middleware), layer 2 is receipt-hash-based (controller).

## What Was Built

- **IP-based rate limiting** via `RateLimitMiddleware` — 30 requests/hour per IP in production (300 in development)
- **Receipt-hash-based rate limiting** in `ReceiptsController` — 10 requests/hour per unique receipt hash
- **Accurate Retry-After headers** computed from the oldest request timestamp in the sliding window
- **Standardized JSON 429 response body** `{ "error": "rate_limited", "retryAfter": <seconds> }` applied globally to all rate-limited responses

## Technical Implementation

### Key Files

- `Sources/App/Middlewares/Security/RateLimit/RateLimitTypes.swift`: Defines `RateLimitType.receipt` case
- `Sources/App/Middlewares/Security/RateLimit/RateLimitConfiguration.swift`: Configures `receiptLimit` / `receiptWindow` per environment
- `Sources/App/Middlewares/Security/RateLimit/RateLimitMiddleware.swift`: Routes `/api/v1/receipts/validate` to receipt rate limits, returns JSON 429 body
- `Sources/App/Middlewares/Security/RateLimit/RateLimitStorage.swift`: Provides `getOldestTimestamp(for:since:)` for accurate Retry-After computation
- `Sources/App/Modules/Receipts/Controllers/ReceiptsController.swift`: Implements hash-based rate limiting before external validation calls

### Key Patterns

- **Dual-layer rate limiting**: IP-based limiting runs at the middleware level (available for all routes). Hash-based limiting runs at the controller level because the hash is derived from the request body, which isn't available in middleware. This pattern applies whenever you need to rate-limit based on request content rather than just the client IP.

- **Accurate Retry-After computation**: Instead of returning the full window duration, the system finds the oldest request timestamp within the window and computes exactly when it will expire: `oldestTimestamp + windowSeconds - now`. This gives clients a precise retry time.

- **Pre-validation rate check**: The hash-based rate limit check happens *after* computing the receipt hash but *before* calling expensive external validation services (App Store / Play Store APIs). This prevents wasting external API calls on rate-limited requests.

### Code Examples

Adding a new operation type to the rate limiter:

```swift
// 1. Add case to RateLimitTypes.swift
case myNewOperation = "my_new_operation"

// 2. Add limit/window to RateLimitConfiguration.swift
let myNewOperationLimit: Int
let myNewOperationWindow: Int
// Update default, production(), and development() configs

// 3. Add path match in RateLimitMiddleware.determineRateLimit(for:)
if path.contains("/api/v1/my-endpoint") {
    return RateLimitInfo(
        type: .myNewOperation,
        maxRequests: configuration.myNewOperationLimit,
        windowSeconds: configuration.myNewOperationWindow
    )
}
```

Controller-level content-aware rate limiting:

```swift
// Use RateLimitStorage.shared directly in the controller
let operationKey = "my_prefix_\(contentDerivedKey)"
let cutoffTime = Date().addingTimeInterval(-windowSeconds)
let count = await RateLimitStorage.shared.getCount(for: operationKey, since: cutoffTime)

if count >= maxRequests {
    // Build 429 response with RateLimitErrorResponse
}

await RateLimitStorage.shared.record(operationKey: operationKey, at: Date())
```

## How to Use

1. IP-based limiting is automatic — applied by middleware to all requests hitting `/api/v1/receipts/validate`
2. Hash-based limiting is automatic — applied in `ReceiptsController.validate(_:)` after hash computation
3. To adjust limits, modify `RateLimitConfiguration` (separate values for default, production, and development)
4. Clients receiving 429 should read the `Retry-After` header and wait that many seconds before retrying

## Configuration

| Option | Type | Default | Production | Development | Description |
|--------|------|---------|------------|-------------|-------------|
| `receiptLimit` | Int | 30 | 30 | 300 | Max IP-based requests per window |
| `receiptWindow` | Int | 3600 | 3600 | 3600 | Window duration in seconds (1 hour) |
| Hash limit | Int | 10 | 10 | 10 | Max requests per unique receipt hash (hardcoded in controller) |
| Hash window | TimeInterval | 3600 | 3600 | 3600 | Hash rate window in seconds (hardcoded in controller) |

## Notes

- The hash-based limit (10/hr) is intentionally stricter than the IP-based limit (30/hr) because replaying the exact same receipt is a stronger signal of abuse than multiple different receipts from one IP
- `RateLimitStorage` is an actor-based singleton — all rate limit state is in-memory with automatic TTL expiry via `cleanup(olderThan:)`
- The `RateLimitErrorResponse` Codable struct is shared between middleware and controller to ensure consistent 429 response format
- In tests, the remote address is `nil` (VaporTesting), so IP falls back to `"unknown"` — tests use `.development()` config limits
