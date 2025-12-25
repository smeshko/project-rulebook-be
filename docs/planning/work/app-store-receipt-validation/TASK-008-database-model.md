## TASK-008: Create Receipt Database Model and Migration

---
**Status:** OPEN
**Branch:** feature/app-store-receipt-validation
**Type:** IMPLEMENTATION
**Phase:** 3
**Depends On:** TASK-007
---

### Overview

Create the database model for storing validated receipts with platform field, and the migration to create the table.

**Files:**
- `Sources/App/Modules/Purchases/Database/Models/ReceiptModel.swift` (create)
- `Sources/App/Modules/Purchases/Database/Migrations/ReceiptMigrations.swift` (create)

### Implementation Steps

**Commit 1: feat(purchases): add ReceiptModel and migrations**
- [ ] Create `Sources/App/Modules/Purchases/Database/Models/` directory structure
- [ ] Create ReceiptModel following RefreshTokenModel pattern
- [ ] Add @Parent relationship to UserAccountModel
- [ ] Add platform field for iOS/Android distinction
- [ ] Create V1 migration for receipts table
- [ ] Define proper field keys struct

### Code Example

```swift
// Sources/App/Modules/Purchases/Database/Models/ReceiptModel.swift
import Vapor
import Fluent

final class ReceiptModel: @unchecked Sendable, DatabaseModelInterface {
    static var schema: String { "receipts" }

    @ID(key: .id) var id: UUID?
    @Parent(key: FieldKeys.v1.userId) var user: UserAccountModel
    @Field(key: FieldKeys.v1.platform) var platform: String  // "ios" or "android"
    @Field(key: FieldKeys.v1.transactionId) var transactionId: String
    @Field(key: FieldKeys.v1.originalTransactionId) var originalTransactionId: String
    @Field(key: FieldKeys.v1.productId) var productId: String
    @Field(key: FieldKeys.v1.purchaseDate) var purchaseDate: Date
    @OptionalField(key: FieldKeys.v1.expiresDate) var expiresDate: Date?
    @OptionalField(key: FieldKeys.v1.revocationDate) var revocationDate: Date?
    @Field(key: FieldKeys.v1.environment) var environment: String
    @Timestamp(key: FieldKeys.v1.createdAt, on: .create) var createdAt: Date?
    @Timestamp(key: FieldKeys.v1.updatedAt, on: .update) var updatedAt: Date?

    struct FieldKeys {
        struct v1 {
            static let userId: FieldKey = "user_id"
            static let platform: FieldKey = "platform"
            static let transactionId: FieldKey = "transaction_id"
            static let originalTransactionId: FieldKey = "original_transaction_id"
            static let productId: FieldKey = "product_id"
            static let purchaseDate: FieldKey = "purchase_date"
            static let expiresDate: FieldKey = "expires_date"
            static let revocationDate: FieldKey = "revocation_date"
            static let environment: FieldKey = "environment"
            static let createdAt: FieldKey = "created_at"
            static let updatedAt: FieldKey = "updated_at"
        }
    }

    init() {}

    init(
        id: UUID? = nil,
        userID: UUID,
        platform: MobilePlatform,
        transactionId: String,
        originalTransactionId: String,
        productId: String,
        purchaseDate: Date,
        expiresDate: Date? = nil,
        revocationDate: Date? = nil,
        environment: String
    ) {
        self.id = id
        self.$user.id = userID
        self.platform = platform.rawValue
        self.transactionId = transactionId
        self.originalTransactionId = originalTransactionId
        self.productId = productId
        self.purchaseDate = purchaseDate
        self.expiresDate = expiresDate
        self.revocationDate = revocationDate
        self.environment = environment
    }
}

// Sources/App/Modules/Purchases/Database/Migrations/ReceiptMigrations.swift
import Fluent

enum ReceiptMigrations {
    struct V1: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database.schema(ReceiptModel.schema)
                .id()
                .field(ReceiptModel.FieldKeys.v1.userId, .uuid, .required,
                    .references(UserAccountModel.schema, "id", onDelete: .cascade))
                .field(ReceiptModel.FieldKeys.v1.platform, .string, .required)
                .field(ReceiptModel.FieldKeys.v1.transactionId, .string, .required)
                .field(ReceiptModel.FieldKeys.v1.originalTransactionId, .string, .required)
                .field(ReceiptModel.FieldKeys.v1.productId, .string, .required)
                .field(ReceiptModel.FieldKeys.v1.purchaseDate, .datetime, .required)
                .field(ReceiptModel.FieldKeys.v1.expiresDate, .datetime)
                .field(ReceiptModel.FieldKeys.v1.revocationDate, .datetime)
                .field(ReceiptModel.FieldKeys.v1.environment, .string, .required)
                .field(ReceiptModel.FieldKeys.v1.createdAt, .datetime)
                .field(ReceiptModel.FieldKeys.v1.updatedAt, .datetime)
                .unique(on: ReceiptModel.FieldKeys.v1.transactionId,
                        ReceiptModel.FieldKeys.v1.platform)
                .create()
        }

        func revert(on database: Database) async throws {
            try await database.schema(ReceiptModel.schema).delete()
        }
    }
}
```

### Success Criteria

- [ ] Build succeeds
- [ ] Migration compiles
- [ ] Unique constraint on (transactionId, platform)
- [ ] Platform field stored as string

### Verification

```bash
swift build
```

### Notes

Unique constraint includes platform because transaction IDs could theoretically overlap between iOS and Android (though unlikely).
Cascade delete on user ensures cleanup when user deleted.
