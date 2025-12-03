# Implementation Plan: Waitlist Email Collection & Notification System

---
**Date:** 2025-12-03
**Requirements:** `docs/planning/work/waitlist-email/requirements.md`
**Research:** `docs/planning/work/waitlist-email/research.md`
**Branch:** `feature/waitlist-email`
**Status:** draft
---

## Summary

**What:** Create a waitlist management system to collect emails from a landing page, send confirmation emails via Brevo, and enable bulk launch notifications.
**Why:** Enable pre-launch user acquisition and direct communication channel with interested users.
**Who:** Landing page visitors (public), admin users (notifications).

## Technical Context

**Stack:** Swift 5.9+ / Vapor 4.110+
**Version:** macOS/Linux server deployment
**Build:** Swift Package Manager (SPM)

**Key Dependencies:**
- Fluent: Database ORM for waitlist model
- Brevo API: Email delivery (existing)
- VaporToOpenAPI: API documentation

**Architecture:** Modular with Repository Pattern
- Rationale: Consistent with existing User, Auth, Rules modules

**Files:**
| File | Action | Purpose |
|------|--------|---------|
| `Sources/App/Modules/Waitlist/WaitlistModule.swift` | create | Module registration |
| `Sources/App/Modules/Waitlist/WaitlistRouter.swift` | create | Route definitions |
| `Sources/App/Modules/Waitlist/WaitlistController.swift` | create | Business logic |
| `Sources/App/Modules/Waitlist/Repositories/WaitlistRepository.swift` | create | Data access |
| `Sources/App/Modules/Waitlist/Database/Models/WaitlistEntryModel.swift` | create | Database model |
| `Sources/App/Modules/Waitlist/Database/Migrations/WaitlistMigrations.swift` | create | Schema migration |
| `Sources/App/Modules/Waitlist/Models/Waitlist+Model.swift` | create | Request/Response DTOs |
| `Sources/App/Services/Email/Helpers/Templates.swift` | modify | Add waitlist templates |
| `Sources/App/Services/Email/Helpers/WaitlistNotifier.swift` | create | Email helper |
| `Sources/App/Entrypoint/Application-Setup.swift` | modify | Register module |
| `Sources/App/Middlewares/Security/RateLimit/RateLimitTypes.swift` | modify | Add waitlist type |
| `Sources/App/Middlewares/Security/RateLimit/RateLimitMiddleware.swift` | modify | Add waitlist path |

## Technical Decisions

1. **Database over file storage:** PostgreSQL via Fluent - Consistency with existing patterns, better querying
2. **Unhashed unsubscribe tokens:** UUID stored directly - Lower security requirement than auth tokens
3. **Dedicated rate limit type:** `waitlist` with 10 req/hour - Prevents spam while allowing legitimate use
4. **Batch notification:** Sequential with configurable batch size - Avoid Brevo rate limits

## Phase Breakdown

### Phase 0: Database Foundation
**Goal:** Create database model and migration for waitlist entries

**Deliverables:**
- [ ] `WaitlistEntryModel.swift` with fields: id, email, unsubscribeToken, createdAt, notifiedAt
- [ ] `WaitlistMigrations.swift` with v1 migration
- [ ] Unique constraint on email column

**Dependencies:** None
**Effort:** 1-2 hours

**Success Criteria:**
- Migration runs successfully
- Model can be created and queried in tests

**Approach:** Follow `UserAccountModel` pattern exactly. Use FieldKeys struct for versioned field names. Include unique constraint on email to prevent duplicates at database level.

---

### Phase 1: Repository & Module Setup
**Goal:** Create data access layer and module structure

**Deliverables:**
- [ ] `WaitlistRepository.swift` protocol and database implementation
- [ ] `WaitlistModule.swift` conforming to ModuleInterface
- [ ] Register module in `Application-Setup.swift`
- [ ] `Waitlist+Model.swift` with DTOs (Subscribe request/response)

**Dependencies:** Phase 0
**Effort:** 1-2 hours

**Success Criteria:**
- Module boots without errors
- Repository methods work (create, findByEmail, findByToken, delete, all)

**Approach:** Follow `UserRepository` pattern. Include methods for: create, findByEmail, findByToken, delete, all, findUnnotified. Register in setupModules() array.

---

### Phase 2: Email Templates & Notifier
**Goal:** Create email templates and helper for sending waitlist emails

**Deliverables:**
- [ ] Add `waitlistConfirmation(unsubscribeToken:baseURL:)` to `Templates.swift`
- [ ] Add `waitlistLaunchNotification(unsubscribeToken:baseURL:)` to `Templates.swift`
- [ ] Create `WaitlistNotifier.swift` helper (similar to EmailVerifier)

**Dependencies:** Phase 1
**Effort:** 1-2 hours

**Success Criteria:**
- Templates render valid HTML with unsubscribe links
- WaitlistNotifier can send both email types

**Approach:** Copy existing `verifyEmail` template structure. Include unsubscribe link in footer. Keep content simple/placeholder per user request. WaitlistNotifier follows EmailVerifier pattern.

---

### Phase 3: Rate Limiting
**Goal:** Add waitlist-specific rate limiting to prevent abuse

**Deliverables:**
- [ ] Add `waitlist` case to `RateLimitType` enum
- [ ] Add `waitlistLimit` and `waitlistWindow` to `RateLimitConfiguration`
- [ ] Add path detection for `/api/waitlist` in `RateLimitMiddleware`

**Dependencies:** None (can be parallel with Phase 1-2)
**Effort:** 30 minutes

**Success Criteria:**
- Requests to `/api/waitlist` use waitlist-specific limits
- 429 returned when limit exceeded

**Approach:** Add new case to RateLimitType. Configure moderate limits (10 requests/hour). Add path check in determineRateLimit() before general API catch-all.

---

### Phase 4: Public Endpoints (Subscribe & Unsubscribe)
**Goal:** Implement public-facing API endpoints

**Deliverables:**
- [ ] `WaitlistRouter.swift` with route definitions
- [ ] `WaitlistController.swift` with subscribe() and unsubscribe() methods
- [ ] `POST /api/waitlist` - Add email to waitlist
- [ ] `GET /api/waitlist/unsubscribe/:token` - Remove from waitlist
- [ ] OpenAPI documentation for both endpoints

**Dependencies:** Phase 1, Phase 2, Phase 3
**Effort:** 2-3 hours

**Success Criteria:**
- Subscribe returns 200 and sends confirmation email
- Duplicate email returns 200 (idempotent) without duplicate entry
- Invalid email returns 400
- Valid unsubscribe token removes entry, returns 200
- Invalid token returns 404

**Approach:** Controller validates email format, checks for existing entry (return success if exists), creates new entry with UUID token, sends confirmation email async. Unsubscribe looks up by token, deletes if found.

---

### Phase 5: Admin Notification Endpoint
**Goal:** Implement admin-only bulk notification capability within WaitlistModule

**Deliverables:**
- [ ] `POST /api/waitlist/notify` - Send launch notification to all (admin only)
- [ ] `GET /api/waitlist/stats` - Get waitlist statistics (admin only)
- [ ] Batch processing for bulk email sending
- [ ] Update notifiedAt timestamp after sending

**Dependencies:** Phase 4
**Effort:** 2-3 hours

**Success Criteria:**
- Only admins can access endpoints (401 for non-admin)
- Notification sends to all un-notified entries
- Each entry's notifiedAt is updated after successful send
- Stats endpoint returns total count, notified count, pending count

**Approach:** Add admin-protected routes in WaitlistRouter using `EnsureAdminUserMiddleware()` (same pattern as UserRouter.swift:48-55). Keep all endpoints under `/api/waitlist` path. Query findUnnotified(), iterate in batches, send email, update notifiedAt. Handle failures gracefully (log, continue).

---

### Phase 6: Testing & Documentation
**Goal:** Ensure quality and document the feature

**Deliverables:**
- [ ] Unit tests for WaitlistRepository
- [ ] Integration tests for endpoints
- [ ] OpenAPI documentation complete
- [ ] Update API documentation if needed

**Dependencies:** Phase 5
**Effort:** 2-3 hours

**Success Criteria:**
- All tests pass
- OpenAPI spec includes all waitlist endpoints
- Manual testing confirms email delivery

**Approach:** Follow existing test patterns in `Tests/AppTests/`. Create `WaitlistTests.swift`. Test happy paths and edge cases (duplicate, invalid email, rate limit).

---

## Implementation Strategy

**State Management:** Database via Fluent ORM
- Waitlist entries stored in PostgreSQL
- notifiedAt tracks notification status

**Data Flow:**
1. User submits email → Rate limit check → Validate → Store → Send confirmation
2. User clicks unsubscribe → Lookup token → Delete entry → Confirm
3. Admin triggers notify → Query un-notified → Batch send → Update timestamps

**Error Handling:** Vapor Abort pattern
- 400: Invalid email format
- 404: Unsubscribe token not found
- 429: Rate limit exceeded
- 500: Email service failure (logged, but don't fail request)

**Performance:**
- Unique index on email for fast duplicate check
- Index on unsubscribeToken for fast lookup
- Batch processing for bulk notifications (50 per batch)

## Dependencies & Risks

**Internal:**
- Phase 1 depends on Phase 0 (model must exist)
- Phase 4 depends on Phases 1, 2, 3
- Phase 5 depends on Phase 4

**External:**
- Brevo API: Must be operational for email sending

**Risks:**
| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Brevo rate limits | Low | Medium | Batch with delays, log failures |
| Spam abuse | Medium | Low | Rate limiting + email validation |
| Duplicate handling race condition | Low | Low | Database unique constraint |

**Assumptions:**
- Brevo service is configured and working
- Landing page will call the API correctly
- Simple email content is acceptable initially

## Acceptance Mapping

| Criterion | Phase | Verification |
|-----------|-------|--------------|
| Valid email stored, confirmation sent | Phase 4 | Integration test |
| Invalid email returns 400 | Phase 4 | Unit test |
| Duplicate handled gracefully | Phase 4 | Integration test |
| Rate limit returns 429 | Phase 3 | Integration test |
| Unsubscribe removes entry | Phase 4 | Integration test |
| Admin can bulk notify | Phase 5 | Manual test |
| Emails include unsubscribe link | Phase 2 | Template inspection |

## Next Steps

1. Review this plan
2. Run `/tasks` to generate detailed task breakdown
3. Begin Phase 0 implementation

**Unknowns:**
- None remaining - all clarified in research phase

---
**Status:** draft
**Total Estimated Effort:** 10-15 hours across 6 phases
