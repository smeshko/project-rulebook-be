# Feedback Module Foundation

**Date:** 2026-03-19
**Related Files:** `Sources/App/Modules/Feedback/`, `Sources/App/Entities/Feedback/`, `Tests/AppTests/Tests/FeedbackTests/`

## Overview

The Feedback module provides the foundation for collecting and managing user feedback on generated game rules. It introduces the `FeedbackModel` database entity with typed enums for feedback classification and status tracking, a repository with paginated queries, and full test infrastructure. This is the foundation layer — endpoints will be added in Stories 3.2 and 3.3.

## What Was Built

- `FeedbackModel` database entity with `FeedbackType` and `FeedbackStatus` enums
- Database migration with PostgreSQL enum types and foreign key to `generated_rules`
- `FeedbackRepository` protocol and `DatabaseFeedbackRepository` with CRUD, status filtering, and pagination
- `Feedback` DTO namespace with `Submit`, `Detail`, and `List` request/response types
- `FeedbackModule`, `FeedbackRouter`, and `FeedbackController` (stub) following module pattern
- `TestFeedbackRepository` actor and `FeedbackModel+Mock` for testing
- Integration tests covering CRUD, filtering, pagination, and count operations

## Technical Implementation

### Key Files

- `Sources/App/Modules/Feedback/Database/Models/FeedbackModel.swift`: Database entity with `@Enum` fields for `feedbackType` and `status`
- `Sources/App/Modules/Feedback/Database/Migrations/FeedbackMigrations.swift`: Creates PostgreSQL enums (`feedback_type`, `feedback_status`) and schema with foreign key
- `Sources/App/Modules/Feedback/Repositories/FeedbackRepository.swift`: Repository protocol and Fluent implementation with paginated queries
- `Sources/App/Entities/Feedback/Feedback.swift`: Public DTO types for API contract
- `Sources/App/Modules/Feedback/Models/Feedback+Model.swift`: Vapor `Content` conformance and model-to-DTO mapping

### Key Patterns

- **Database Enum Fields**: Uses Fluent `@Enum` property wrapper with `db.enum(...).case(...).create()` in migration. The enum must be created and read back before use in schema builder. Revert must delete enums after deleting schema.
- **Safe Pagination**: `findPaginated` clamps inputs (`page >= 1`, `1 <= limit <= 100`) and uses offset-based pagination with `range(offset..<offset+limit)`. Returns `(items, total)` tuple for client-side page calculation.
- **Optional Status Filtering**: Query methods accept `FeedbackStatus?` — when `nil`, no filter is applied, returning all records.
- **Foreign Key with `.setNull`**: The `rulesSummaryId` foreign key uses `.setNull` on delete so feedback survives if the referenced rule summary is removed.

### Code Examples

```swift
// Paginated query with optional status filter
let result = try await repository.findPaginated(
    status: .pending,  // or nil for all
    page: 1,
    limit: 20
)
// result.items: [FeedbackModel], result.total: Int
```

```swift
// Creating a feedback record
let feedback = FeedbackModel(
    rulesSummaryId: summaryId,
    gameTitle: "Catan",
    feedbackType: .incorrect,
    description: "Setup instructions are wrong",
    userContact: "user@example.com",
    status: .pending
)
try await repository.create(feedback)
```

## How to Use

1. Access the repository via `req.services.feedback` in controllers or `app.repositories.feedback` at the application level
2. Create feedback by constructing a `FeedbackModel` and calling `repository.create(_:)`
3. Query by status with `findByStatus(_:)` or paginate with `findPaginated(status:page:limit:)`
4. Map models to DTOs using `Feedback.Detail.Response(from: model)`

## Configuration

No additional configuration required. The module registers automatically via `setupModules()` and `setupServices()` in `Application-Setup.swift`.

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| Pagination limit | Int | Clamped 1-100 | Maximum items per page |
| Default status | FeedbackStatus | `.pending` | Initial status for new feedback |

## Notes

- The `FeedbackController` is an empty stub — endpoints will be implemented in Story 3.2 (submit endpoint) and Story 3.3 (admin list/status endpoints)
- `rulesSummaryId` is `Optional<UUID>` with `.setNull` on delete, allowing feedback to persist independently
- The `TestFeedbackRepository` is an `actor` providing thread-safe in-memory storage for unit tests
