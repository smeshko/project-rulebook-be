# Receipts Module Foundation

**Date:** 2026-01-26
**Related Files:** Sources/App/Modules/Receipts/

## Overview

The Receipts module provides the foundation for in-app purchase (IAP) receipt validation. It stores validated transaction records with built-in idempotency enforcement to prevent duplicate credit grants from replayed or retried purchase receipts.

## What Was Built

- **TransactionModel**: Database entity for storing validated purchase records
- **ReceiptsRepository**: Data access layer with idempotency checking capability
- **ReceiptsMigrations**: Database schema with unique constraint on transaction IDs
- **Module scaffolding**: Controller, router, and DTOs ready for endpoint implementation

## Technical Implementation

### Key Files

- `Database/Models/TransactionModel.swift`: Fluent model storing transaction records with fields for transactionId, platform, productId, creditAmount, and createdAt
- `Database/Migrations/ReceiptsMigrations.swift`: Creates transactions table with UNIQUE constraint on transaction_id column
- `Repositories/ReceiptsRepository.swift`: Protocol and implementation with `find(transactionId:)` for idempotency checks
- `ReceiptsModule.swift`: Module registration following project pattern

### Key Patterns

- **Idempotency via Unique Constraint**: The `transaction_id` column has a database-level UNIQUE constraint, ensuring no duplicate transactions can be stored even under concurrent requests
- **Idempotency Lookup**: Use `find(transactionId:)` to check if a transaction was already processed before granting credits
- **Platform Enumeration**: Platform field stores "ios" or "android" as strings for flexibility
- **Credit Amount Values**: Valid values are 1, 3, or 10 credits (enforced at application level)

### Code Examples

```swift
// Check for duplicate before processing
let repository = req.application.repositories.receipts
if let existing = try await repository.find(transactionId: appleTransactionId) {
    // Transaction already processed - return existing result
    return existing
}

// Store new validated transaction
let transaction = TransactionModel(
    transactionId: appleTransactionId,
    platform: "ios",
    productId: "com.app.credits.10",
    creditAmount: 10
)
try await repository.create(transaction)
```

## How to Use

1. **Check for duplicates first**: Before processing any receipt, call `find(transactionId:)` with the store-provided transaction ID
2. **If found**: Return success without granting additional credits (idempotent response)
3. **If not found**: Validate the receipt with Apple/Google, then store the transaction
4. **Store transaction**: Create a TransactionModel with the validated data

## Configuration

| Field | Type | Description |
|-------|------|-------------|
| transactionId | String | Unique identifier from App Store/Play Store |
| platform | String | "ios" or "android" |
| productId | String | Store product identifier |
| creditAmount | Int | Credits granted (1, 3, or 10) |

## Notes

- This module provides the foundation only; actual receipt validation endpoints will be added in Story 2.4
- The unique constraint on transaction_id is the primary defense against duplicate credit grants
- Platform-specific receipt validation (App Store Server API, Google Play Developer API) will be implemented in subsequent stories
- The controller, router, and DTO files are placeholders ready for expansion
