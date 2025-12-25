## TASK-009: Create Receipt Repository

---
**Status:** OPEN
**Branch:** feature/app-store-receipt-validation
**Type:** IMPLEMENTATION
**Phase:** 3
**Depends On:** TASK-008
---

### Overview

Create the repository protocol and implementation for receipt data access following existing repository patterns.

**Files:**
- `Sources/App/Modules/Purchases/Repositories/ReceiptRepository.swift` (create)
- `Sources/App/Common/Extensions/Request+Repositories.swift` (modify)

### Implementation Steps

**Commit 1: feat(purchases): add ReceiptRepository**
- [ ] Create ReceiptRepository protocol following UserRepository pattern
- [ ] Create DatabaseReceiptRepository implementation
- [ ] Add methods: save, findByTransactionId, findByUser, upsert
- [ ] Register repository in Request+Repositories

### Code Example

```swift
// Sources/App/Modules/Purchases/Repositories/ReceiptRepository.swift
import Vapor
import Fluent

protocol ReceiptRepository: Repository {
    func save(_ receipt: ReceiptModel) async throws
    func findByTransactionId(_ transactionId: String, platform: MobilePlatform) async throws -> ReceiptModel?
    func findByUser(userId: UUID) async throws -> [ReceiptModel]
    func findByUser(userId: UUID, platform: MobilePlatform) async throws -> [ReceiptModel]
    func upsert(_ receipt: ReceiptModel) async throws -> ReceiptModel
}

struct DatabaseReceiptRepository: ReceiptRepository {
    let database: Database

    func save(_ receipt: ReceiptModel) async throws {
        try await receipt.save(on: database)
    }

    func findByTransactionId(_ transactionId: String, platform: MobilePlatform) async throws -> ReceiptModel? {
        try await ReceiptModel.query(on: database)
            .filter(\.$transactionId == transactionId)
            .filter(\.$platform == platform.rawValue)
            .first()
    }

    func findByUser(userId: UUID) async throws -> [ReceiptModel] {
        try await ReceiptModel.query(on: database)
            .filter(\.$user.$id == userId)
            .sort(\.$purchaseDate, .descending)
            .all()
    }

    func findByUser(userId: UUID, platform: MobilePlatform) async throws -> [ReceiptModel] {
        try await ReceiptModel.query(on: database)
            .filter(\.$user.$id == userId)
            .filter(\.$platform == platform.rawValue)
            .sort(\.$purchaseDate, .descending)
            .all()
    }

    func upsert(_ receipt: ReceiptModel) async throws -> ReceiptModel {
        guard let platform = MobilePlatform(rawValue: receipt.platform) else {
            try await receipt.save(on: database)
            return receipt
        }

        if let existing = try await findByTransactionId(receipt.transactionId, platform: platform) {
            // Update mutable fields
            existing.expiresDate = receipt.expiresDate
            existing.revocationDate = receipt.revocationDate
            try await existing.update(on: database)
            return existing
        } else {
            try await receipt.save(on: database)
            return receipt
        }
    }
}

// Request+Repositories.swift - Add to RequestRepositories struct:
var receipts: ReceiptRepository {
    DatabaseReceiptRepository(database: req.db)
}
```

### Success Criteria

- [ ] Build succeeds
- [ ] Repository accessible via req.repositories.receipts
- [ ] Upsert handles duplicate transactions
- [ ] Platform filtering works

### Verification

```bash
swift build
```

### Notes

Upsert method handles re-validation of same transaction (updates expiration/revocation dates).
Platform is included in lookups because transaction IDs are unique per platform.
