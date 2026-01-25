# Epic 3: Rules Feedback System

Allow users to report incorrect or incomplete game rules, enabling continuous improvement of AI-generated content. Users can contribute to improving rule quality, making the service better over time.

## Story 3.1: Create Feedback Module Foundation
**Linear:** [RULE-138](https://linear.app/project-rulebook/issue/RULE-138)

**As a** backend developer,
**I want** a Feedback module with database model and repository,
**So that** I can store and retrieve user feedback on rules.

**Acceptance Criteria:**

**Given** the project structure
**When** the Feedback module is created
**Then** it follows the established module pattern with:
- `FeedbackModule.swift` for registration
- `FeedbackRouter.swift` for route definitions
- `Controller/FeedbackController.swift`
- `Models/Feedback+Model.swift` for request/response DTOs
- `Database/Models/FeedbackModel.swift`
- `Database/Migrations/FeedbackMigrations.swift`
- `Repositories/FeedbackRepository.swift`

**Given** the FeedbackModel
**When** feedback is stored
**Then** it captures: `id`, `rulesSummaryId` (foreign key to rules summary), `gameTitle`, `feedbackType` (incorrect/incomplete/other), `description`, `userContact` (optional), `status` (pending/reviewed/resolved), `createdAt`

**Given** the repository
**When** querying feedback
**Then** it supports filtering by status and pagination

---

## Story 3.2: Create Feedback Submission Endpoint
**Linear:** [RULE-139](https://linear.app/project-rulebook/issue/RULE-139)

**As a** mobile app user,
**I want** to submit feedback about incorrect or incomplete rules,
**So that** I can help improve the service.

**Acceptance Criteria:**

**Given** a POST request to `/api/v1/feedback`
**When** the request contains valid feedback data:
```json
{
  "rulesSummaryId": "uuid",
  "gameTitle": "Wingspan",
  "feedbackType": "incorrect",
  "description": "The setup step about food tokens is wrong",
  "userContact": "user@example.com"
}
```
**Then** the feedback is stored in the database
**And** response `{ "success": true, "feedbackId": "..." }` is returned

**Given** a request with missing required fields
**When** `rulesSummaryId`, `gameTitle`, `feedbackType`, or `description` is missing
**Then** response returns 400 Bad Request with validation errors

**Given** a request with invalid `feedbackType`
**When** the type is not one of: `incorrect`, `incomplete`, `other`
**Then** response returns 400 Bad Request

**Given** rate limiting configuration
**When** a user submits more than 5 feedback items per hour per IP
**Then** response returns 429 Too Many Requests

---

## Story 3.3: Create Admin Feedback Endpoints
**Linear:** [RULE-140](https://linear.app/project-rulebook/issue/RULE-140)

**As an** admin,
**I want** to view and manage submitted feedback,
**So that** I can review and act on user reports.

**Acceptance Criteria:**

**Given** a GET request to `/api/v1/admin/feedback`
**When** an authenticated admin makes the request
**Then** a paginated list of feedback is returned with:
- `id`, `rulesSummaryId`, `gameTitle`, `feedbackType`, `description`, `userContact`, `status`, `createdAt`

**Given** query parameters `?status=pending&page=1&limit=20`
**When** filtering feedback
**Then** only feedback matching the status is returned with proper pagination

**Given** a PATCH request to `/api/v1/admin/feedback/{id}`
**When** an authenticated admin updates status:
```json
{ "status": "reviewed" }
```
**Then** the feedback status is updated
**And** response returns the updated feedback object

**Given** an unauthenticated request to admin endpoints
**When** no valid JWT is provided
**Then** response returns 401 Unauthorized

---
