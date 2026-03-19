# Store API Graceful Degradation

**Date:** 2026-03-19
**Related Files:** `Sources/App/Modules/Receipts/Jobs/PendingValidationJob.swift`, `Sources/App/Modules/Receipts/Controllers/ReceiptsController.swift`, `Sources/App/Modules/Receipts/Database/Migrations/ReceiptsMigrations.swift`, `Sources/App/Modules/Receipts/Repositories/ReceiptsRepository.swift`

## Overview

When Apple App Store or Google Play Store APIs are unreachable (5xx errors, timeouts, connection failures), the receipt validation endpoint stores the transaction in a `pending_validation` state and returns `202 Accepted` instead of failing. A background job retries validation with exponential backoff, ensuring no valid purchases are lost during upstream outages.

## What Was Built

- **Graceful degradation in ReceiptsController**: Catches transient upstream errors and stores pending transactions instead of returning errors to the client
- **PendingValidationJob**: Background task that retries pending validations every 5 minutes with exponential backoff
- **Idempotent pending responses**: Duplicate requests with the same receipt hash return the existing pending transaction ID
- **v4 database migration**: Adds `receipt_data`, `retry_count`, and `last_retry_at` fields to `TransactionModel`
- **New transaction statuses**: `pending_validation` and `validation_failed` enum cases

## Technical Implementation

### Key Files

- `Sources/App/Modules/Receipts/Jobs/PendingValidationJob.swift`: Background job that processes pending validations with retry logic and exponential backoff
- `Sources/App/Modules/Receipts/Controllers/ReceiptsController.swift`: Modified to catch transient errors and store pending transactions
- `Sources/App/Modules/Receipts/Database/Models/TransactionModel.swift`: Extended with `receiptData`, `retryCount`, `lastRetryAt` fields and new status enum cases
- `Sources/App/Modules/Receipts/Repositories/ReceiptsRepository.swift`: Added `findPendingValidations()`, `findPendingByReceiptHash()`, and `updateStatus()` queries

### Key Patterns

- **Transient vs. Definitive Error Classification**: Generic/untyped errors (e.g., `URLError(.timedOut)`) and Play Store 5xx `apiError` codes are treated as transient (retry-worthy). Typed validation errors (`invalidSignature`, `invalidToken`, `configurationError`, Play Store 4xx) are definitive failures — no retry. This distinction prevents wasting retries on permanently invalid receipts.

- **Background Job with Swift Concurrency**: Uses `Task` + `Task.sleep(for:)` instead of Vapor's Queues package. The job is started via `Application.setupBackgroundJobs()` and shut down via Vapor's `LifecycleHandler`. This avoids adding an external dependency (Redis-backed queues) for a single periodic task.

- **Exponential Backoff Schedule**: Retry intervals are `[300, 1200, 3600]` seconds (5min, 20min, 60min). Eligibility is checked by comparing `Date().timeIntervalSince(lastRetryAt)` against the interval for the current `retryCount`. After 3 failed attempts, the transaction is marked `validation_failed` with `.critical` logging.

- **Idempotent Pending Storage**: Before creating a new pending transaction, the controller checks `findPendingByReceiptHash()`. If a pending record already exists for the same receipt, it returns the existing transaction ID — preventing duplicate pending records from concurrent or retried client requests.

### Code Examples

**Catching transient errors in the controller (iOS path):**

```swift
// In ReceiptsController — iOS validation catch block
} catch let appStoreError as AppStoreValidationError {
    // Typed validation errors are definitive — return 403
    throw Abort(.forbidden)
} catch {
    // Generic/untyped errors (timeout, connection) are transient — store as pending
    return try await storePendingTransaction(...)
}
```

**Registering the background job:**

```swift
// In Application-Setup.swift
func setupBackgroundJobs() {
    let job = PendingValidationJob(app: self)
    job.start()
    lifecycle.use(PendingValidationJobLifecycleHandler(job: job))
}
```

## How to Use

1. **No action needed for normal operation** — the graceful degradation is automatic. When store APIs are down, clients receive `202 Accepted` with `"status": "pending"` instead of errors.

2. **Monitor for `validation_failed`** — transactions that exhaust all retries are logged at `.critical` level. Set up alerting on this log level to trigger manual review.

3. **To add a new background job**, follow the `PendingValidationJob` pattern:
   - Create a class with `start()` / `shutdown()` methods using `Task`
   - Create a `LifecycleHandler` struct for clean shutdown
   - Register in `Application.setupBackgroundJobs()`

## Configuration

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `PendingValidationJob.backoffIntervals` | `[TimeInterval]` | `[300, 1200, 3600]` | Seconds between retry attempts (5min, 20min, 60min) |
| `PendingValidationJob.maxRetries` | `Int` | `3` | Maximum retry attempts before marking as `validation_failed` |
| `PendingValidationJob.jobInterval` | `UInt64` | `300` | Seconds between job runs (5 minutes) |

These are compile-time constants. To make them runtime-configurable, extract to environment variables or `RemoteConfig`.

## Notes

- The v4 migration uses separate `ALTER TABLE` statements per column for SQLite compatibility (SQLite doesn't support adding multiple columns in a single `ALTER TABLE`)
- `receiptData` is cleared (set to `nil`) after successful retry validation to avoid retaining raw receipt payloads longer than necessary
- The job skips transactions in test environments — `setupBackgroundJobs()` is only called when `app.environment != .testing`
- On successful retry, if a duplicate transaction with the real store transaction ID already exists, the pending record is deleted rather than updated (dedup)
