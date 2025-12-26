---
stepsCompleted: [1, 2, 3, 4]
workflowComplete: true
step1CompletedAt: '2025-12-26'
step2CompletedAt: '2025-12-26'
step3CompletedAt: '2025-12-26'
step4CompletedAt: '2025-12-26'
inputDocuments:
  - path: '_bmad-output/prd.md'
    type: 'prd'
    description: 'Backend PRD for project-rulebook-be'
  - path: '_bmad-output/architecture.md'
    type: 'architecture'
    description: 'Architecture Decision Document'
  - path: 'docs/architecture/architectural-vision.md'
    type: 'supplementary'
    description: 'Architectural principles and vision'
  - path: 'docs/architecture/technical-architecture.md'
    type: 'supplementary'
    description: 'Technical implementation patterns'
project_name: 'project-rulebook-be'
user_name: 'Ivo'
date: '2025-12-26'
---

# project-rulebook-be - Epic Breakdown

## Overview

This document provides the complete epic and story breakdown for project-rulebook-be, decomposing the requirements from the PRD and Architecture into implementable stories.

## Requirements Inventory

### Functional Requirements

**Core API Requirements (Implemented):**
- FR1: API accepts image uploads for game box analysis ✅
- FR2: API returns game identification with confidence score ✅
- FR3: API provides alternative title suggestions ✅
- FR4: API generates structured rules from game title ✅
- FR5: Rules include setup, first round, win condition, deep dive ✅
- FR6: API validates and sanitizes all input ✅
- FR7: API validates AI response structure before returning ✅

**Caching Requirements (Implemented):**
- FR8: Cache rules responses by normalized game title ✅
- FR9: Cache image analysis results by image hash ✅
- FR10: Provide cache statistics endpoint (admin) ✅
- FR11: Support cache invalidation (admin) ✅

**Rate Limiting Requirements (Implemented):**
- FR12: Limit image analysis to 3 requests/hour per IP ✅
- FR13: Limit rules generation to 10 requests/hour per IP ✅
- FR14: Return 429 with retry-after header when limited ✅

**AI Provider Requirements (Implemented):**
- FR15: Support OpenAI as primary AI provider ✅
- FR16: Support Google Gemini as fallback provider ✅
- FR17: Automatic failover when primary provider fails ✅
- FR18: Configurable provider selection per environment ✅

**Security Requirements (Implemented):**
- FR19: All endpoints served over HTTPS ✅
- FR20: Prompt injection prevention via sanitization ✅
- FR21: No sensitive data in logs ✅
- FR22: Security headers on all responses ✅

**Future Requirements (To Be Implemented):**
- FR23: Receipt validation for IAP verification [Priority: High]
- FR24: User feedback submission for incorrect rules [Priority: Medium]

**Out of Scope (Removed):**
- ~~User account creation and authentication~~ - Not implementing
- ~~Cloud sync of saved games library~~ - Not implementing
- ~~Usage analytics collection~~ - Handled by frontend apps

### Non-Functional Requirements

**Performance:**
- NFR1: Image analysis response time (P95) <30 seconds
- NFR2: Rules generation response time (P95) <15 seconds
- NFR3: Cached response time <100ms
- NFR4: Cold start time <5 seconds

**Reliability:**
- NFR5: Service availability 99.5% uptime
- NFR6: Graceful degradation on AI failure (fallback to secondary provider)
- NFR7: No data loss on restart (persistent cache in Redis)

**Scalability:**
- NFR8: Concurrent request handling - 100 simultaneous requests
- NFR9: Horizontal scaling support - stateless design
- NFR10: Database connection pooling - configured for production load

**Security:**
- NFR11: HTTPS-only communication
- NFR12: Input validation on all endpoints
- NFR13: Rate limiting to prevent abuse
- NFR14: No API keys in client-accessible responses

**Observability:**
- NFR15: Structured logging with correlation IDs
- NFR16: Error tracking with context
- NFR17: Performance metrics collection
- NFR18: Health check endpoints

### Additional Requirements

**From Architecture Document:**
- AR1: API Versioning - URL prefix versioning (`/api/v1/`) for all endpoints
- AR2: Receipt Validation Module - New module `Modules/Receipts/` with App Store and Play Store validation services
- AR3: Module Structure Pattern - All new modules follow established vertical slice structure
- AR4: Service Protocol-First Design - All services use protocol-based design for testability
- AR5: Error Handling Pattern - All errors conform to `AppError` enum
- AR6: Naming Conventions - Database tables (snake_case, plural), API endpoints (kebab-case), Swift types (PascalCase)

**From Architectural Vision (docs/architecture):**
- AV1: Elegant Simplicity - "Build less, but build it better"
- AV2: Contextual Cohesion - Everything related to a feature lives together within its module boundary
- AV3: Progressive Disclosure - Reveal complexity only when necessary
- AV4: Framework Harmony - Work with Vapor conventions, not against them
- AV5: Three-Strike Rule - Don't create abstractions until the third occurrence
- AV6: Standard Library First - Check Swift/Vapor before creating custom utilities

### FR Coverage Map

| Requirement | Epic | Story | Description |
|-------------|------|-------|-------------|
| AR1 | Epic 1 | 1.1 | API versioning with `/v1/` prefix |
| - | Epic 1 | 1.2 | Remote Config endpoint |
| FR23 | Epic 2 | 2.1-2.4 | Receipt validation for IAP |
| AR2 | Epic 2 | 2.1 | Receipt module structure |
| FR24 | Epic 3 | 3.1-3.3 | User feedback submission |
| NFR1-4 | Epic 4 | 4.3-4.5 | Performance improvements |
| NFR15-18 | Epic 4 | 4.1-4.2 | Observability improvements |
| - | Epic 4 | 4.6 | App Attest security verification |

## Epic List

### Epic 1: API Versioning & Stability
Establish versioned API endpoints and foundational services to enable safe, backward-compatible evolution of the API. Mobile apps can pin to specific API versions and receive remote configuration.

**Covers:** AR1 (API Versioning), Remote Config

---

### Epic 2: In-App Purchase Verification
Enable server-side validation of App Store and Play Store purchases to secure the credit-based monetization system. Users can purchase credits with confidence that their transactions are securely verified.

**Covers:** FR23, AR2

---

### Epic 3: Rules Feedback System
Allow users to report incorrect or incomplete game rules, enabling continuous improvement of AI-generated content. Users can contribute to improving rule quality, making the service better over time.

**Covers:** FR24

---

### Epic 4: Platform Reliability & Performance
Improve system observability, response times, operational resilience, and security. Faster responses, better uptime, improved debugging capabilities, and API protection.

**Covers (Phase 2 Improvements):**
- Response Time Optimization (High)
- Cache Warming (Medium)
- Enhanced Fallback Logic (Medium)
- Structured Logging with Correlation IDs (Medium)
- Health Check Endpoints (Medium)
- App Attest Verification (Security)

---

## Epic 1: API Versioning & Stability

Establish versioned API endpoints to enable safe, backward-compatible evolution of the API. Mobile apps can pin to specific API versions, ensuring stability during updates.

### Story 1.1: Add API Version Prefix to All Public Routes
**Linear:** [RULE-130](https://linear.app/project-rulebook/issue/RULE-130)

**As a** mobile app developer,
**I want** all API endpoints to use the `/api/v1/` prefix,
**So that** I can pin my app to a specific API version for stability.

**Acceptance Criteria:**

**Given** the RulesGeneration module routes
**When** a client calls `/api/v1/rules-generation/game-box-analysis`
**Then** the endpoint responds correctly
**And** the old `/api/rules-generation/game-box-analysis` route no longer exists

**Given** the Auth module routes
**When** a client calls `/api/v1/auth/sign-in`, `/api/v1/auth/sign-up`, `/api/v1/auth/refresh-token`
**Then** all auth endpoints respond correctly under the new prefix

**Given** the User module routes
**When** a client calls `/api/v1/users/profile`
**Then** user endpoints respond correctly under the new prefix

**Given** the Waitlist module routes
**When** a client calls `/api/v1/waitlist/subscribe`
**Then** waitlist endpoints respond correctly under the new prefix

**Given** any request to unversioned `/api/` routes
**When** a client calls the old paths
**Then** the server returns 404 Not Found

---

### Story 1.2: Implement Remote Config Endpoint
**Linear:** [RULE-123](https://linear.app/project-rulebook/issue/RULE-123)

**As a** mobile app,
**I want** to fetch feature flags and configuration from the backend,
**So that** app behavior can be controlled remotely without app updates.

**Acceptance Criteria:**

**Given** a GET request to `/api/v1/config`
**When** the request is made
**Then** response returns a JSON dictionary of configuration values:
```json
{
  "featureFlags": {
    "enableNewScanner": true,
    "showPromotion": false
  },
  "settings": {
    "maxRetries": 3,
    "cacheTimeoutSeconds": 300
  },
  "version": "1.0.0"
}
```

**Given** the config endpoint
**When** it is called
**Then** it does NOT require authentication (public endpoint)

**Given** configuration data
**When** stored in the system
**Then** it is persisted in PostgreSQL with Redis caching (5 min TTL)

**Given** configuration values
**When** defining them
**Then** they support typed values: boolean, integer, string, JSON object

**Given** an admin endpoint `/api/v1/admin/config`
**When** an authenticated admin updates configuration
**Then** the cache is invalidated and new values take effect immediately

**Given** a cache miss
**When** Redis cache expires
**Then** configuration is re-fetched from PostgreSQL and cached

---

## Epic 2: In-App Purchase Verification

Enable server-side validation of App Store and Play Store purchases to secure the credit-based monetization system. Users can purchase credits with confidence that their transactions are securely verified.

### Story 2.1: Create Receipts Module Foundation
**Linear:** [RULE-136](https://linear.app/project-rulebook/issue/RULE-136)

**As a** backend developer,
**I want** a Receipts module with database model and repository,
**So that** I can store validated transaction records.

**Acceptance Criteria:**

**Given** the project structure
**When** the Receipts module is created
**Then** it follows the established module pattern with:
- `ReceiptsModule.swift` for registration
- `ReceiptsRouter.swift` for route definitions
- `Controller/ReceiptsController.swift`
- `Models/Receipts+Model.swift` for request/response DTOs
- `Database/Models/TransactionModel.swift`
- `Database/Migrations/ReceiptsMigrations.swift`
- `Repositories/ReceiptsRepository.swift`

**Given** the TransactionModel
**When** a transaction is stored
**Then** it captures: `id`, `transactionId` (from store), `platform` (ios/android), `productId`, `creditAmount` (1, 3, or 10), `createdAt`

**Given** the repository
**When** checking for duplicate transactions
**Then** it can query by `transactionId` to enforce idempotency

---

### Story 2.2: Implement App Store Receipt Validation
**Linear:** [RULE-128](https://linear.app/project-rulebook/issue/RULE-128)

**As a** iOS app user,
**I want** my App Store purchases validated server-side,
**So that** my credits are securely verified.

**Acceptance Criteria:**

**Given** a valid App Store receipt
**When** the `AppStoreValidationService` validates it
**Then** it calls Apple's App Store Server API
**And** returns success with the product ID and transaction ID

**Given** an invalid or tampered receipt
**When** validation is attempted
**Then** the service returns failure with appropriate error

**Given** a previously validated transaction ID
**When** the same receipt is submitted again
**Then** validation succeeds but is marked as duplicate (idempotent)

**Given** the service configuration
**When** the service is initialized
**Then** it uses environment variables for Apple API credentials

---

### Story 2.3: Implement Play Store Receipt Validation
**Linear:** [RULE-129](https://linear.app/project-rulebook/issue/RULE-129)

**As an** Android app user,
**I want** my Play Store purchases validated server-side,
**So that** my credits are securely verified.

**Acceptance Criteria:**

**Given** a valid Play Store purchase token
**When** the `PlayStoreValidationService` validates it
**Then** it calls Google Play Developer API
**And** returns success with the product ID and transaction ID

**Given** an invalid or tampered purchase token
**When** validation is attempted
**Then** the service returns failure with appropriate error

**Given** a previously validated transaction ID
**When** the same purchase is submitted again
**Then** validation succeeds but is marked as duplicate (idempotent)

**Given** the service configuration
**When** the service is initialized
**Then** it uses environment variables for Google API credentials

---

### Story 2.4: Create Receipt Validation Endpoint
**Linear:** [RULE-137](https://linear.app/project-rulebook/issue/RULE-137)

**As a** mobile app,
**I want** a single endpoint to validate purchases,
**So that** I can verify transactions regardless of platform.

**Acceptance Criteria:**

**Given** a POST request to `/api/v1/receipts/validate`
**When** the request contains `{ "platform": "ios", "receiptData": "...", "productId": "..." }`
**Then** the App Store validation service is called
**And** success response `{ "success": true, "transactionId": "..." }` is returned

**Given** a POST request to `/api/v1/receipts/validate`
**When** the request contains `{ "platform": "android", "purchaseToken": "...", "productId": "..." }`
**Then** the Play Store validation service is called
**And** success response `{ "success": true, "transactionId": "..." }` is returned

**Given** a validation failure
**When** the receipt/token is invalid
**Then** response `{ "success": false, "error": "..." }` is returned with appropriate HTTP status

**Given** a successful validation
**When** the transaction is new (not duplicate)
**Then** the transaction is stored in the database

**Given** a valid product ID
**When** validating a purchase
**Then** the product maps to credit amounts: `credits_1` → 1, `credits_3` → 3, `credits_10` → 10

---

## Epic 3: Rules Feedback System

Allow users to report incorrect or incomplete game rules, enabling continuous improvement of AI-generated content. Users can contribute to improving rule quality, making the service better over time.

### Story 3.1: Create Feedback Module Foundation
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

### Story 3.2: Create Feedback Submission Endpoint
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

### Story 3.3: Create Admin Feedback Endpoints
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

## Epic 4: Platform Reliability & Performance

Improve system observability, response times, and operational resilience. Faster responses, better uptime, and improved debugging capabilities.

### Story 4.1: Add Health Check Endpoint
**Linear:** [RULE-141](https://linear.app/project-rulebook/issue/RULE-141)

**As a** DevOps engineer,
**I want** a health check endpoint,
**So that** Railway/Kubernetes can monitor service availability.

**Acceptance Criteria:**

**Given** a GET request to `/health`
**When** the service is running and healthy
**Then** response returns 200 OK with:
```json
{
  "status": "healthy",
  "timestamp": "2025-12-26T10:00:00Z",
  "checks": {
    "database": "ok",
    "redis": "ok"
  }
}
```

**Given** a database connection failure
**When** the health check runs
**Then** response returns 503 Service Unavailable with `"database": "error"`

**Given** a Redis connection failure
**When** the health check runs
**Then** response returns 503 Service Unavailable with `"redis": "error"`

**Given** the health endpoint
**When** it is called
**Then** it does NOT require authentication

---

### Story 4.2: Implement Structured Logging with Correlation IDs
**Linear:** [RULE-142](https://linear.app/project-rulebook/issue/RULE-142)

**As a** backend developer,
**I want** correlation IDs in all log entries,
**So that** I can trace requests across the entire lifecycle.

**Acceptance Criteria:**

**Given** an incoming request
**When** the request is processed
**Then** a unique `correlationId` is generated (or extracted from `X-Correlation-ID` header)
**And** the ID is attached to all log entries for that request

**Given** log output
**When** viewing logs
**Then** each entry includes: `timestamp`, `level`, `correlationId`, `message`, `context`

**Given** a request that calls external services (OpenAI, Gemini)
**When** logging external API calls
**Then** the correlation ID is included in those log entries

**Given** an error occurring during request processing
**When** the error is logged
**Then** it includes the correlation ID for easy debugging

**Given** the response headers
**When** a response is sent
**Then** the `X-Correlation-ID` header is included in the response

---

### Story 4.3: Optimize AI Prompt Engineering
**Linear:** [RULE-143](https://linear.app/project-rulebook/issue/RULE-143)

**As a** mobile app user,
**I want** faster AI responses,
**So that** I get game rules more quickly.

**Acceptance Criteria:**

**Given** the current prompts for game box analysis
**When** optimized prompts are deployed
**Then** average response time decreases by at least 20%

**Given** the current prompts for rules generation
**When** optimized prompts are deployed
**Then** average response time decreases by at least 20%

**Given** optimized prompts
**When** generating rules
**Then** output quality remains consistent (same structure, completeness)

**Given** the prompt optimization
**When** implemented
**Then** prompts are extracted to configurable templates for easy iteration

---

### Story 4.4: Implement Cache Warming for Popular Games
**Linear:** [RULE-144](https://linear.app/project-rulebook/issue/RULE-144)

**As a** mobile app user,
**I want** popular games to load instantly,
**So that** I don't wait for AI generation on common requests.

**Acceptance Criteria:**

**Given** the cache warming system
**When** it runs (on startup or scheduled)
**Then** it queries historical request data to identify top 50 most requested games

**Given** identified popular games
**When** cache warming executes
**Then** rules summaries are pre-generated and cached for each game

**Given** a cached popular game
**When** a user requests rules for that game
**Then** response time is <100ms (cache hit)

**Given** the warming process
**When** it runs
**Then** it respects rate limits and runs in background without impacting live traffic

**Given** an admin endpoint `/api/v1/admin/cache/warm`
**When** an admin triggers manual warming
**Then** the warming process starts immediately

---

### Story 4.5: Implement Low Confidence Fallback to Secondary Model
**Linear:** [RULE-145](https://linear.app/project-rulebook/issue/RULE-145)

**As a** mobile app user,
**I want** accurate game recognition,
**So that** I get correct rules even when the primary AI is uncertain.

**Acceptance Criteria:**

**Given** a game box analysis request
**When** the primary model (OpenAI) returns confidence < 70%
**Then** the request is automatically retried with secondary model (Gemini)

**Given** a rules generation request
**When** the primary model returns confidence < 70%
**Then** the request is automatically retried with secondary model

**Given** the secondary model returns higher confidence
**When** comparing results
**Then** the higher confidence result is returned to the user

**Given** both models return low confidence
**When** no clear winner exists
**Then** the primary model result is returned with a flag indicating low confidence

**Given** the fallback behavior
**When** it triggers
**Then** the event is logged with correlation ID for monitoring

---

### Story 4.6: Implement App Attest Verification for iOS
**Linear:** [RULE-126](https://linear.app/project-rulebook/issue/RULE-126)

**As a** backend operator,
**I want** API requests verified using Apple App Attest,
**So that** only legitimate iOS app instances can access protected endpoints.

**Acceptance Criteria:**

**Given** an iOS app with App Attest enabled
**When** the app makes its first API request
**Then** it sends an attestation object to `/api/v1/attest/verify`
**And** the backend validates it against Apple's servers
**And** returns a session token for subsequent requests

**Given** a valid attestation
**When** the backend verifies it
**Then** it checks: app ID matches, device is not jailbroken, attestation is fresh

**Given** an invalid or tampered attestation
**When** verification is attempted
**Then** response returns 403 Forbidden with appropriate error

**Given** protected API endpoints (rules-generation, receipts)
**When** a request is made without valid attestation token
**Then** response returns 401 Unauthorized

**Given** the attestation system
**When** configured
**Then** it can be disabled via environment variable for development/testing

**Given** attestation verification
**When** it succeeds or fails
**Then** the event is logged with device fingerprint for fraud detection
