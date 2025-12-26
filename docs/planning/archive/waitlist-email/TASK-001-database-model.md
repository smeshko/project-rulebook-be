## TASK-001: Create WaitlistEntry Database Model & Migration

---
**Status:** OPEN
**Branch:** feature/waitlist-email
**Type:** IMPLEMENTATION
**Phase:** 1
**Depends On:** None
---

### Overview

Create the Fluent database model and migration for storing waitlist email entries. This is the foundation for all waitlist functionality.

**Files:**
- `Sources/App/Modules/Waitlist/Database/Models/WaitlistEntryModel.swift` (create)
- `Sources/App/Modules/Waitlist/Database/Migrations/WaitlistMigrations.swift` (create)

### Implementation Steps

**Commit 1: Create WaitlistEntryModel and Migration**
- [ ] Create directory structure: `Sources/App/Modules/Waitlist/Database/Models/` and `Sources/App/Modules/Waitlist/Database/Migrations/`
- [ ] Create `WaitlistEntryModel.swift` with fields: id (UUID), email (String), unsubscribeToken (String), createdAt (Date), notifiedAt (Date?)
- [ ] Add FieldKeys struct with v1 nested struct for versioned field names
- [ ] Conform to `DatabaseModelInterface` and `@unchecked Sendable`
- [ ] Create `WaitlistMigrations.swift` with v1 AsyncMigration
- [ ] Add unique constraint on email column
- [ ] Add index on unsubscribeToken for fast lookup

### Code Example

```swift
// Pattern from UserAccountModel.swift
// Sources/App/Modules/User/Database/Models/UserAccountModel.swift:1-66

final class WaitlistEntryModel: @unchecked Sendable, DatabaseModelInterface {
    typealias Module = WaitlistModule
    static var schema: String { "waitlist_entries" }

    @ID() var id: UUID?
    @Field(key: FieldKeys.v1.email) var email: String
    @Field(key: FieldKeys.v1.unsubscribeToken) var unsubscribeToken: String
    @Timestamp(key: FieldKeys.v1.createdAt, on: .create) var createdAt: Date?
    @OptionalField(key: FieldKeys.v1.notifiedAt) var notifiedAt: Date?

    init() { }

    init(id: UUID? = nil, email: String, unsubscribeToken: String = UUID().uuidString) {
        self.id = id
        self.email = email
        self.unsubscribeToken = unsubscribeToken
    }
}

extension WaitlistEntryModel {
    struct FieldKeys {
        struct v1 {
            static var email: FieldKey { "email" }
            static var unsubscribeToken: FieldKey { "unsubscribe_token" }
            static var createdAt: FieldKey { "created_at" }
            static var notifiedAt: FieldKey { "notified_at" }
        }
    }
}
```

```swift
// Migration pattern from UserMigrations.swift
// Sources/App/Modules/User/Database/Migrations/UserMigrations.swift:4-29

enum WaitlistMigrations {
    struct v1: AsyncMigration {
        func prepare(on db: Database) async throws {
            try await db.schema(WaitlistEntryModel.schema)
                .id()
                .field(WaitlistEntryModel.FieldKeys.v1.email, .string, .required)
                .field(WaitlistEntryModel.FieldKeys.v1.unsubscribeToken, .string, .required)
                .field(WaitlistEntryModel.FieldKeys.v1.createdAt, .datetime)
                .field(WaitlistEntryModel.FieldKeys.v1.notifiedAt, .datetime)
                .unique(on: WaitlistEntryModel.FieldKeys.v1.email)
                .unique(on: WaitlistEntryModel.FieldKeys.v1.unsubscribeToken)
                .create()
        }

        func revert(on db: Database) async throws {
            try await db.schema(WaitlistEntryModel.schema).delete()
        }
    }
}
```

### Success Criteria

- [ ] Build succeeds
- [ ] Model file compiles without errors
- [ ] Migration file compiles without errors
- [ ] Schema includes unique constraint on email

### Verification

```bash
swift build
```

### Notes

- Use `@OptionalField` for `notifiedAt` since it's null until notification is sent
- The `unsubscribeToken` is auto-generated as UUID in the initializer
- Follow exact pattern from UserAccountModel for consistency
