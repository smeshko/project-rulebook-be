# Execution Tasks: Waitlist Email Collection & Notification System

**Branch:** `feature/waitlist-email` → `staging` → `main`
**Complexity:** Medium
**Duration:** 8-12 hours
**Created:** 2025-12-03

---

## Overview

Create a waitlist management system to collect emails from a landing page, send confirmation emails via Brevo, and enable bulk launch notifications.

**Deliverables:**
- Public endpoint to subscribe to waitlist (`POST /api/waitlist`)
- Public endpoint to unsubscribe (`GET /api/waitlist/unsubscribe/:token`)
- Admin endpoint for statistics (`GET /api/waitlist/stats`)
- Admin endpoint for bulk notifications (`POST /api/waitlist/notify`)
- Email templates for confirmation and launch notification
- Rate limiting on public endpoints

---

## Quick Reference

- **Phases:** 2 | **Tasks:** 10 | **Commits:** ~10
- **Parallel:** T001+T005+T007, T004+T005 | **Critical Path:** T001 → T002 → T003 → T008 → T009

---

## Phase 1: Foundation & Core Infrastructure

**Goal:** Set up database model, repository, module, email templates, and rate limiting
**PR:** `feat(waitlist): add waitlist module foundation`
**Deliverable:** All infrastructure ready for endpoint implementation

---

### Task T001: Database Model & Migration
**Source:** `TASK-001-database-model.md`
**Type:** IMPLEMENTATION
**Files:** `Sources/App/Modules/Waitlist/Database/Models/WaitlistEntryModel.swift`, `Sources/App/Modules/Waitlist/Database/Migrations/WaitlistMigrations.swift`
[P] **Parallelizable with T005, T007**

**Implementation Steps:**
- [x] Create directory structure for Waitlist module
- [x] Create WaitlistEntryModel with fields (id, email, unsubscribeToken, createdAt, notifiedAt)
- [x] Add FieldKeys struct for versioned field names
- [x] Create WaitlistMigrations with v1 migration and unique constraints

**Checkpoint:** ✓ Build | ✓ Files compile

---

### Task T002: Repository Implementation
**Source:** `TASK-002-repository.md`
**Type:** IMPLEMENTATION
**Files:** `Sources/App/Modules/Waitlist/Repositories/WaitlistRepository.swift`
**Depends on:** T001

**Implementation Steps:**
- [x] Define WaitlistRepository protocol with all methods
- [x] Create DatabaseWaitlistRepository implementation
- [x] Implement: create, findByEmail, findByToken, delete, all, findUnnotified, update, count, countNotified

**Checkpoint:** ✓ Build | ✓ Protocol and impl compile

---

### Task T003: Module Setup & Registration
**Source:** `TASK-003-module-setup.md`
**Type:** IMPLEMENTATION
**Files:** `Sources/App/Modules/Waitlist/WaitlistModule.swift`, `Sources/App/Entrypoint/Application-Setup.swift`
**Depends on:** T001, T002

**Implementation Steps:**
- [x] Create WaitlistModule conforming to ModuleInterface
- [x] Create placeholder WaitlistRouter
- [x] Register module in Application-Setup.swift setupModules()
- [x] Add migration registration in boot()

**Checkpoint:** ✓ Build | ✓ App starts | ✓ Migration runs

---

### Task T004: Request/Response DTOs
**Source:** `TASK-004-dto-models.md`
**Type:** IMPLEMENTATION
**Files:** `Sources/App/Modules/Waitlist/Models/Waitlist+Model.swift`
[P] **Parallelizable with T005**
**Depends on:** T001

**Implementation Steps:**
- [x] Create Waitlist namespace enum
- [x] Create Subscribe.Request with email validation
- [x] Create Subscribe.Response, Unsubscribe.Response
- [x] Create Stats.Response, Notify.Response

**Checkpoint:** ✓ Build | ✓ DTOs conform to Content

---

### Task T005: Email Templates
**Source:** `TASK-005-email-templates.md`
**Type:** IMPLEMENTATION
**Files:** `Sources/App/Services/Email/Helpers/Templates.swift`
[P] **Parallelizable with T001, T004, T007**

**Implementation Steps:**
- [x] Add waitlistConfirmation() static method
- [x] Add waitlistLaunchNotification() static method
- [x] Include unsubscribe link in footer of both
- [x] Use existing HTML structure pattern

**Checkpoint:** ✓ Build | ✓ Templates compile

---

### Task T006: WaitlistNotifier Helper
**Source:** `TASK-006-waitlist-notifier.md`
**Type:** IMPLEMENTATION
**Files:** `Sources/App/Services/Email/Helpers/WaitlistNotifier.swift`
**Depends on:** T005

**Implementation Steps:**
- [x] Create WaitlistNotifier struct
- [x] Add sendConfirmation(to:) method
- [x] Add sendLaunchNotification(to:) method
- [x] Add Application and Request extensions

**Checkpoint:** ✓ Build | ✓ Uses EmailService correctly

---

### Task T007: Rate Limiting Configuration
**Source:** `TASK-007-rate-limiting.md`
**Type:** IMPLEMENTATION
**Files:** `Sources/App/Middlewares/Security/RateLimit/RateLimitTypes.swift`, `Sources/App/Middlewares/Security/RateLimit/RateLimitMiddleware.swift`
[P] **Parallelizable with T001, T005**

**Implementation Steps:**
- [x] Add `waitlist` case to RateLimitType enum
- [x] Add path detection for `/api/waitlist` before `/api/` catch-all
- [x] Configure 10 requests/hour limit

**Checkpoint:** ✓ Build | ✓ No warnings

---

### Task T010: Repository Integration
**Source:** `TASK-010-repository-integration.md`
**Type:** INTEGRATION
**Files:** `Sources/App/Modules/Waitlist/Repositories/WaitlistRepository.swift`
**Depends on:** T002

**Implementation Steps:**
- [x] Add Request.Services.waitlist extension
- [x] Repository accessible via request.services.waitlist

**Checkpoint:** ✓ Build | ✓ Repository accessible via extensions

---

**Phase 1 Completion:**
- [x] All tasks T001-T007, T010 complete
- [x] Build succeeds: `swift build`
- [x] No warnings
- [x] Migration runs on app start
- [x] Create PR: `feature/waitlist-email` → `staging` (#23)

---

## Phase 2: API Endpoints

**Goal:** Implement public and admin API endpoints
**PR:** Continue on `feature/waitlist-email` branch (or separate PR if preferred)
**Deliverable:** Fully functional waitlist API

---

### Task T008: Public Endpoints (Subscribe & Unsubscribe)
**Source:** `TASK-008-public-endpoints.md`
**Type:** IMPLEMENTATION
**Files:** `Sources/App/Modules/Waitlist/WaitlistRouter.swift`, `Sources/App/Modules/Waitlist/WaitlistController.swift`
**Depends on:** T003, T004, T006, T007, T010

**Implementation Steps:**
- [x] Create WaitlistController with subscribe() method
- [x] Add unsubscribe() method to controller
- [x] Update WaitlistRouter with POST /api/waitlist route
- [x] Add GET /api/waitlist/unsubscribe/:token route
- [x] Add OpenAPI documentation
- [x] Handle duplicate emails gracefully (idempotent)

**Checkpoint:** ✓ Build | ✓ Endpoints respond | ✓ Email sent on subscribe

---

### Task T009: Admin Endpoints (Stats & Notify)
**Source:** `TASK-009-admin-endpoints.md`
**Type:** IMPLEMENTATION
**Files:** `Sources/App/Modules/Waitlist/WaitlistRouter.swift`, `Sources/App/Modules/Waitlist/WaitlistController.swift`
**Depends on:** T008

**Implementation Steps:**
- [x] Add stats() method to controller
- [x] Add notify() method with batch processing
- [x] Add admin route group with EnsureAdminUserMiddleware
- [x] Add GET /api/waitlist/stats route
- [x] Add POST /api/waitlist/notify route
- [x] Update notifiedAt after successful send
- [x] Add OpenAPI documentation with auth

**Checkpoint:** ✓ Build | ✓ Admin routes protected | ✓ Stats return correct counts

---

**Phase 2 Completion:**
- [x] All tasks T008-T009 complete
- [x] Build succeeds: `swift build`
- [ ] Manual test: subscribe works
- [ ] Manual test: unsubscribe works
- [ ] Manual test: admin stats works
- [x] Create/Update PR: `feature/waitlist-email` → `staging` (#23)

---

## Execution

**Commit Format:**
```
feat(waitlist): <description>

- Change 1
- Change 2

Task: T00X | Phase: N
```

**Build:** `swift build`
**Test:** `swift test`
**Run:** `swift run App serve`

---

## Task Reference

| ID | Phase | Type | Files | Depends On | Status |
|----|-------|------|-------|------------|--------|
| T001 | 1 | IMPL | WaitlistEntryModel, Migrations | - | OPEN |
| T002 | 1 | IMPL | WaitlistRepository | T001 | OPEN |
| T003 | 1 | IMPL | WaitlistModule, Application-Setup | T001, T002 | OPEN |
| T004 | 1 | IMPL | Waitlist+Model | T001 | OPEN |
| T005 | 1 | IMPL | Templates.swift | - | OPEN |
| T006 | 1 | IMPL | WaitlistNotifier | T005 | OPEN |
| T007 | 1 | IMPL | RateLimitTypes, RateLimitMiddleware | - | OPEN |
| T008 | 2 | IMPL | WaitlistRouter, WaitlistController | T003, T004, T006, T007, T010 | OPEN |
| T009 | 2 | IMPL | WaitlistRouter, WaitlistController | T008 | OPEN |
| T010 | 1 | INTEG | WaitlistRepository | T002 | OPEN |

---

## Parallel Execution Guide

**Maximum parallelism in Phase 1:**
- Start together: T001, T005, T007 (no dependencies)
- After T001: T002, T004
- After T002: T010
- After T005: T006
- After T002 + T010: T003

**Optimal execution order:**
1. T001 + T005 + T007 (parallel)
2. T002 + T004 (parallel, after T001)
3. T006 + T010 (parallel, after T005/T002)
4. T003 (after T001, T002)
5. T008 (after T003, T004, T006, T007, T010)
6. T009 (after T008)

---

## Notes

- Email templates use simple placeholder content - user will refine later
- Rate limiting set to 10 requests/hour - can be adjusted in configuration
- Admin endpoints follow UserRouter pattern (same module, middleware-protected)
- Notification sends sequentially to respect Brevo rate limits
- Failed email sends are logged but don't block the process
