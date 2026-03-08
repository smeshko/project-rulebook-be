# Receipts Module Foundation

**Date:** 2026-03-08
**Related Files:** `Sources/App/Modules/Receipts/`, `Sources/App/Entities/Receipts/`

## Overview

The Receipts module provides the foundation for storing validated in-app purchase transaction records. It implements a `TransactionModel` with platform-aware storage (iOS/Android), idempotency enforcement via unique `transactionId` constraints, and a repository layer for querying existing transactions before processing duplicates.

## What Was Built

- `TransactionModel` database model with platform enum, product ID, and credit amount fields
- PostgreSQL migration with `transaction_platform` enum type and unique constraint on `transactionId`
- `ReceiptsRepository` protocol and `DatabaseReceiptsRepository` implementation with idempotency query
- Module, router, and controller stubs for future endpoint implementation (Story 2.4)
- Entity namespace (`Receipts`) for future request/response DTOs

## Technical Implementation

### Key Files

- `Sources/App/Modules/Receipts/Database/Models/TransactionModel.swift`: Fluent model with `@Enum` for platform and `@Timestamp` for creation tracking
- `Sources/App/Modules/Receipts/Database/Migrations/ReceiptsMigrations.swift`: Creates `transaction_platform` enum type and `transactions` table with unique constraint
- `Sources/App/Modules/Receipts/Repositories/ReceiptsRepository.swift`: Repository with `find(transactionId:)` for idempotency checks
- `Sources/App/Modules/Receipts/ReceiptsModule.swift`: Registers migration and boots router
- `Sources/App/Common/Extensions/Application+Services.swift`: Service storage registration
- `Sources/App/Entrypoint/Application-Setup.swift`: Module registration in boot sequence

### Key Patterns

- **Idempotency via Unique Constraint**: The `transactionId` field has a database-level unique constraint, preventing duplicate transaction records even under concurrent requests. The repository provides `find(transactionId:)` for application-level checks before attempting inserts.

- **PostgreSQL Enum Type**: The `TransactionPlatform` enum (ios/android) is stored as a PostgreSQL enum type rather than a raw string. The migration creates the enum type first, then references it in the table schema:
  ```swift
  try await db.enum("transaction_platform")
      .case("ios")
      .case("android")
      .create()

  let platformEnum = try await db.enum("transaction_platform").read()

  try await db.schema(TransactionModel.schema)
      .field(TransactionModel.FieldKeys.v1.platform, platformEnum, .required)
      // ...
  ```

- **Versioned Field Keys**: Field keys are namespaced under `FieldKeys.v1` to support future schema evolution without conflicts.

### Code Examples

**Creating a transaction record:**
```swift
let transaction = TransactionModel(
    transactionId: "1000000123456789",
    platform: .ios,
    productId: "com.app.credits.10",
    creditAmount: 10
)
try await req.repositories.receipts.create(transaction)
```

**Checking for duplicate transactions (idempotency):**
```swift
if let existing = try await req.repositories.receipts.find(transactionId: storeTransactionId) {
    // Transaction already processed — return existing result
    return existing
}
// Proceed with new transaction processing
```

## How to Use

1. The module is registered in `Application-Setup.swift` and boots automatically
2. The repository is available via `req.repositories.receipts` in any controller
3. Use `find(transactionId:)` before creating records to enforce idempotency
4. Controller endpoints will be added in Story 2.4 (Receipt Verification Endpoint)

## Configuration

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| Credit amounts | Int | 1, 3, or 10 | Valid credit amounts per product tier |
| Platforms | Enum | ios, android | Supported store platforms |

These values are enforced at the application level (future Story 2.4), not in the database schema.

## Notes

- The controller, router, and model extension files are intentional stubs — endpoint logic will be implemented in Story 2.4
- The `Receipts` entity namespace at `Entities/Receipts/Receipts.swift` is a placeholder for future DTOs
- Migration supports both SQLite (tests) and PostgreSQL (production)
- The unique constraint on `transactionId` provides database-level protection against duplicate processing
