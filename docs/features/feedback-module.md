# Feedback Module

**Date:** 2026-03-19
**Related Files:** `Sources/App/Modules/Feedback/`, `Sources/App/Entities/Feedback/`, `Sources/App/Entities/Errors/FeedbackError.swift`, `Tests/AppTests/Tests/FeedbackTests/`, `Tests/AppTests/Tests/ControllerTests/FeedbackTests/`

## Overview

The Feedback module provides collecting and managing user feedback on generated game rules. It includes the `FeedbackModel` database entity with typed enums for feedback classification and status tracking, a repository with paginated queries, a public POST endpoint for submitting feedback with validation and rate limiting, admin endpoints for listing and managing feedback status, and full test infrastructure.

## What Was Built

- `FeedbackModel` database entity with `FeedbackType` and `FeedbackStatus` enums
- Database migration with PostgreSQL enum types and foreign key to `generated_rules`
- `FeedbackRepository` protocol and `DatabaseFeedbackRepository` with CRUD, status filtering, and pagination
- `Feedback` DTO namespace with `Submit`, `Detail`, and `List` request/response types
- `FeedbackModule`, `FeedbackRouter`, and `FeedbackController` following module pattern
- `POST /api/v1/feedback` submission endpoint with input validation and trimming
- `GET /api/v1/admin/feedback` admin list endpoint with status filtering and pagination
- `PATCH /api/v1/admin/feedback/:feedbackId` admin status update endpoint
- `FeedbackAdminController` and `FeedbackAdminRouter` with `EnsureAdminUserMiddleware`
- `Feedback.UpdateStatus` DTO namespace with `Request` and `Response` types
- `FeedbackError` enum with `AbortError` mapping for structured validation errors (including `feedbackNotFound` and `invalidFeedbackStatus`)
- Rate limiting: 5 requests/hour (production), 50 requests/hour (development)
- OpenAPI documentation on the route with request/response types and error status codes
- `TestFeedbackRepository` actor and `FeedbackModel+Mock` for testing
- Integration tests covering CRUD, filtering, pagination, count operations, and submission endpoint

## Technical Implementation

### Key Files

- `Sources/App/Modules/Feedback/Database/Models/FeedbackModel.swift`: Database entity with `@Enum` fields for `feedbackType` and `status`
- `Sources/App/Modules/Feedback/Database/Migrations/FeedbackMigrations.swift`: Creates PostgreSQL enums (`feedback_type`, `feedback_status`) and schema with foreign key
- `Sources/App/Modules/Feedback/Repositories/FeedbackRepository.swift`: Repository protocol and Fluent implementation with paginated queries
- `Sources/App/Entities/Feedback/Feedback.swift`: Public DTO types for API contract
- `Sources/App/Modules/Feedback/Models/Feedback+Model.swift`: Vapor `Content` conformance and model-to-DTO mapping
- `Sources/App/Modules/Feedback/Controllers/FeedbackController.swift`: Submit endpoint with validation logic
- `Sources/App/Modules/Feedback/Controllers/FeedbackAdminController.swift`: Admin list and status update endpoints
- `Sources/App/Modules/Feedback/FeedbackAdminRouter.swift`: Admin route definitions with `EnsureAdminUserMiddleware` and OpenAPI docs
- `Sources/App/Entities/Errors/FeedbackError.swift`: Validation error enum with identifiers and reasons
- `Sources/App/Errors/FeedbackError+AbortError.swift`: HTTP status mapping (validation errors → 400, not found → 404)

### Key Patterns

- **Database Enum Fields**: Uses Fluent `@Enum` property wrapper with `db.enum(...).case(...).create()` in migration. The enum must be created and read back before use in schema builder. Revert must delete enums after deleting schema.
- **Safe Pagination**: `findPaginated` clamps inputs (`page >= 1`, `1 <= limit <= 100`) and uses offset-based pagination with `range(offset..<offset+limit)`. Returns `(items, total)` tuple for client-side page calculation.
- **Optional Status Filtering**: Query methods accept `FeedbackStatus?` — when `nil`, no filter is applied, returning all records.
- **Foreign Key with `.setNull`**: The `rulesSummaryId` foreign key uses `.setNull` on delete so feedback survives if the referenced rule summary is removed.
- **Input Trimming and Normalization**: Controller trims whitespace from `gameTitle`, `description`, and `userContact` before validation. Empty/whitespace-only `userContact` is normalized to `nil`.
- **Structured Validation Errors**: `FeedbackError` conforms to `IdentifiableError` with `identifier` (snake_case key) and `reason` (human message), plus `AbortError` for HTTP status mapping.
- **Admin Controller Pattern**: `FeedbackAdminController` follows the `CacheAdminController` pattern — a separate controller and router with `EnsureAdminUserMiddleware` for admin-only routes. Status updates validate against `FeedbackStatus` raw values and return 400 for invalid values or 404 for missing feedback.
- **Pagination Clamping in Controller**: The admin list endpoint clamps `page` and `limit` in the controller (`max(1, ...)`, `max(1, min(..., 100))`) to match the repository's safe bounds, preventing out-of-range values before they reach the database layer.

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

```swift
// Submit endpoint request body (POST /api/v1/feedback)
{
    "rulesSummaryId": "uuid-string",
    "gameTitle": "Catan",
    "feedbackType": "incorrect",  // incorrect | incomplete | other
    "description": "The setup instructions are missing...",
    "userContact": "user@example.com"  // optional
}
// Response: { "success": true, "feedbackId": "uuid-string" }
```

## How to Use

1. **Submit feedback via API**: `POST /api/v1/feedback` with JSON body containing `rulesSummaryId`, `gameTitle`, `feedbackType`, `description`, and optional `userContact`
2. **List feedback as admin**: `GET /api/v1/admin/feedback?status=pending&page=1&limit=20` (requires admin JWT)
3. **Update feedback status as admin**: `PATCH /api/v1/admin/feedback/{id}` with `{ "status": "reviewed" }` (requires admin JWT)
4. Access the repository via `req.repositories.feedback` in controllers or `app.repositories.feedback` at the application level
5. Create feedback programmatically by constructing a `FeedbackModel` and calling `repository.create(_:)`
6. Query by status with `findByStatus(_:)` or paginate with `findPaginated(status:page:limit:)`
7. Map models to DTOs using `Feedback.Detail.Response(from: model)`

## Configuration

The module registers automatically via `setupModules()` and `setupServices()` in `Application-Setup.swift`. Rate limiting is configured in `RateLimitConfiguration`.

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| Pagination limit | Int | Clamped 1-100 | Maximum items per page |
| Default status | FeedbackStatus | `.pending` | Initial status for new feedback |
| feedbackLimit | Int | 5 (prod) / 50 (dev) | Max feedback submissions per window per IP |
| feedbackWindow | Int | 3600 | Rate limit window in seconds (1 hour) |
| gameTitle max length | Int | 500 | Maximum characters for game title |
| description max length | Int | 5000 | Maximum characters for description |

## Validation Rules

| Field | Rule | Error |
|-------|------|-------|
| `gameTitle` | Required, non-empty after trim, max 500 chars | `game_title_required` / `game_title_too_long` |
| `description` | Required, non-empty after trim, max 5000 chars | `description_required` / `description_too_long` |
| `feedbackType` | Must be `incorrect`, `incomplete`, or `other` | `invalid_feedback_type` |
| `userContact` | Optional; trimmed, empty → `nil` | — |

## Notes

- `rulesSummaryId` is `Optional<UUID>` with `.setNull` on delete, allowing feedback to persist independently
- The `TestFeedbackRepository` is an `actor` providing thread-safe in-memory storage for unit tests
- Admin endpoints require `EnsureAdminUserMiddleware` — non-admin users receive 401 Unauthorized
- Valid feedback statuses: `pending`, `reviewed`, `resolved` — any other value returns 400 Bad Request
