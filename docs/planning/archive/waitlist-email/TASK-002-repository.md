## TASK-002: Create WaitlistRepository

---
**Status:** OPEN
**Branch:** feature/waitlist-email
**Type:** IMPLEMENTATION
**Phase:** 1
**Depends On:** TASK-001
---

### Overview

Create the repository protocol and database implementation for waitlist data access. This provides the data layer abstraction used by the controller.

**Files:**
- `Sources/App/Modules/Waitlist/Repositories/WaitlistRepository.swift` (create)

### Implementation Steps

**Commit 1: Create WaitlistRepository protocol and implementation**
- [ ] Create directory: `Sources/App/Modules/Waitlist/Repositories/`
- [ ] Define `WaitlistRepository` protocol with methods: create, findByEmail, findByToken, delete, all, findUnnotified, update
- [ ] Create `DatabaseWaitlistRepository` struct conforming to protocol
- [ ] Implement all repository methods using Fluent queries
- [ ] Add `Application.Repositories` extension for `waitlist` accessor
- [ ] Add `Request.Services` extension for request-scoped access

### Code Example

```swift
// Pattern from UserRepository.swift
// Sources/App/Modules/User/Repositories/UserRepository.swift:1-50

import Fluent
import Vapor

protocol WaitlistRepository: Repository {
    func find(id: UUID) async throws -> WaitlistEntryModel?
    func find(email: String) async throws -> WaitlistEntryModel?
    func find(token: String) async throws -> WaitlistEntryModel?
    func create(_ model: WaitlistEntryModel) async throws
    func delete(_ model: WaitlistEntryModel) async throws
    func all() async throws -> [WaitlistEntryModel]
    func findUnnotified() async throws -> [WaitlistEntryModel]
    func update(_ model: WaitlistEntryModel) async throws
    func count() async throws -> Int
    func countNotified() async throws -> Int
}

struct DatabaseWaitlistRepository: WaitlistRepository, DatabaseRepository {
    typealias Model = WaitlistEntryModel
    let database: Database

    func find(id: UUID) async throws -> WaitlistEntryModel? {
        try await WaitlistEntryModel.query(on: database)
            .filter(\.$id == id)
            .first()
    }

    func find(email: String) async throws -> WaitlistEntryModel? {
        try await WaitlistEntryModel.query(on: database)
            .filter(\.$email == email)
            .first()
    }

    func find(token: String) async throws -> WaitlistEntryModel? {
        try await WaitlistEntryModel.query(on: database)
            .filter(\.$unsubscribeToken == token)
            .first()
    }

    func create(_ model: WaitlistEntryModel) async throws {
        try await model.create(on: database)
    }

    func delete(_ model: WaitlistEntryModel) async throws {
        try await model.delete(on: database)
    }

    func all() async throws -> [WaitlistEntryModel] {
        try await WaitlistEntryModel.query(on: database).all()
    }

    func findUnnotified() async throws -> [WaitlistEntryModel] {
        try await WaitlistEntryModel.query(on: database)
            .filter(\.$notifiedAt == nil)
            .all()
    }

    func update(_ model: WaitlistEntryModel) async throws {
        try await model.update(on: database)
    }

    func count() async throws -> Int {
        try await WaitlistEntryModel.query(on: database).count()
    }

    func countNotified() async throws -> Int {
        try await WaitlistEntryModel.query(on: database)
            .filter(\.$notifiedAt != nil)
            .count()
    }
}
```

### Success Criteria

- [ ] Build succeeds
- [ ] Protocol defines all needed methods
- [ ] Database implementation compiles
- [ ] Extensions for Application and Request added

### Verification

```bash
swift build
```

### Notes

- `findUnnotified()` filters where notifiedAt is nil - used for bulk notifications
- `countNotified()` and `count()` used for stats endpoint
- Follow UserRepository pattern for consistency with codebase
