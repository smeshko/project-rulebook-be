# Execution Tasks: OpenAPI/Swagger Documentation

**Branch Strategy:** `feature/openapi-documentation` → `staging` → `main`
**Complexity:** Medium
**Estimated Duration:** 10-15 hours
**Created:** 2025-11-28

---

## Overview

Integrate VaporToOpenAPI to automatically generate OpenAPI 3.0.1 specifications from existing Vapor routes and serve interactive Swagger UI for testing all 21 API endpoints across 5 modules.

**Deliverables:**
- OpenAPI 3.0.1 specification endpoint at `/openapi.json` with complete API documentation
- Interactive Swagger UI at `/docs` for browser-based API testing and exploration
- Concise, purposeful descriptions for all 21 endpoints focusing on use cases
- JWT authentication support in Swagger UI for testing protected endpoints
- Endpoints organized by module (Auth, User, Rules Generation, Cache Admin, Frontend)

---

## Quick Reference

- **Total Phases:** 1 (single cohesive PR)
- **Total Tasks:** 8 implementation tasks
- **Estimated Commits:** 8 commits
- **Parallel Opportunities:** Tasks 3-7 (module documentation can be done concurrently)
- **Critical Path:** TASK-001 → TASK-002 → (TASK-003 through TASK-007 in parallel) → TASK-008

---

## Phase 1: OpenAPI Documentation Implementation

**Goal:** Complete OpenAPI integration with Swagger UI for all API endpoints
**PR Title:** `feat(api): add OpenAPI documentation with Swagger UI`
**Deliverable:** Fully documented API with interactive testing interface

---

### Task T001: Add VaporToOpenAPI Dependency

**Source:** `TASK-001-add-dependency.md`
**Type:** IMPLEMENTATION
**Files:** `Package.swift`, `Sources/App/Entrypoint/configure.swift`

**Commits:**
- [x] T001: Add VaporToOpenAPI dependency and register /openapi.json endpoint
  - Add package dependency to Package.swift
  - Import VaporToOpenAPI in configure.swift
  - Register `/openapi.json` route with basic OpenAPI metadata
  - Build verification: ✅

**Checkpoint:**
✓ Build succeeds | ✓ `swift package resolve` completes | ✓ `/openapi.json` returns valid JSON

---

### Task T002: Configure OpenAPI Metadata and Security Schemes

**Source:** `TASK-002-configure-metadata.md`
**Type:** IMPLEMENTATION
**Files:** `Sources/App/Entrypoint/configure.swift`
**Depends On:** TASK-001

**Commits:**
- [x] T002: Configure comprehensive OpenAPI metadata with security schemes
  - Expand API description with feature overview
  - Add server URL configuration
  - Define bearerAuth security scheme for JWT
  - Add contact and license info
  - Build verification: ✅

**Checkpoint:**
✓ Build succeeds | ✓ OpenAPI spec includes security schemes | ✓ Full metadata present

---

### Task T003: Document Auth Module Endpoints

[P] **Parallelizable with T004, T005, T006, T007**
**Source:** `TASK-003-auth-module.md`
**Type:** IMPLEMENTATION
**Files:** `Sources/App/Modules/Auth/AuthRouter.swift`
**Depends On:** TASK-002

**Commits:**
- [x] T003: Add OpenAPI documentation to 6 Auth endpoints
  - Add "Auth" tag to route group
  - Document sign-in endpoint (credentials auth)
  - Document sign-up endpoint (account creation)
  - Document Apple auth endpoint (third-party auth)
  - Document refresh token endpoint (token renewal)
  - Document password reset endpoint (recovery)
  - Document logout endpoint (JWT required, session termination)
  - Build verification: ✅

**Checkpoint:**
✓ Build succeeds | ✓ 6 endpoints under "Auth" tag | ✓ Descriptions focus on "why"

---

### Task T004: Document User Module Endpoints

[P] **Parallelizable with T003, T005, T006, T007**
**Source:** `TASK-004-user-module.md`
**Type:** IMPLEMENTATION
**Files:** `Sources/App/Modules/User/UserRouter.swift`
**Depends On:** TASK-002

**Commits:**
- [x] T004: Add OpenAPI documentation to 4 User endpoints
  - Add "User" tag to route group
  - Document GET /me endpoint (profile retrieval)
  - Document PATCH /update endpoint (profile modification)
  - Document DELETE /delete endpoint (account deletion)
  - Document GET /list endpoint (admin-only user listing)
  - Add bearerAuth security to all endpoints
  - Build verification: ✅

**Checkpoint:**
✓ Build succeeds | ✓ 4 endpoints under "User" tag | ✓ All show JWT requirement

---

### Task T005: Document RulesGeneration Module Endpoints

[P] **Parallelizable with T003, T004, T006, T007**
**Source:** `TASK-005-rules-module.md`
**Type:** IMPLEMENTATION
**Files:** `Sources/App/Modules/RulesGeneration/RulesGenerationRouter.swift`
**Depends On:** TASK-002

**Commits:**
- [x] T005: Add OpenAPI documentation to 2 AI endpoints
  - Add "Rules Generation" tag to route group
  - Document POST /game-box-analysis endpoint (image upload, streaming)
  - Configure multipart/form-data content type for image endpoint
  - Document POST /rules-summary endpoint (AI-generated summary)
  - Note rate limiting in descriptions
  - Build verification: ✅

**Checkpoint:**
✓ Build succeeds | ✓ 2 endpoints under "Rules Generation" tag | ✓ Image content types specified

---

### Task T006: Document CacheAdmin Module Endpoints

[P] **Parallelizable with T003, T004, T005, T007**
**Source:** `TASK-006-cache-module.md`
**Type:** IMPLEMENTATION
**Files:** `Sources/App/Modules/CacheAdmin/CacheAdminRouter.swift`
**Depends On:** TASK-002

**Commits:**
- [x] T006: Add OpenAPI documentation to 6 Cache Admin endpoints
  - Add "Cache Admin" tag to route group
  - Document GET /stats endpoint (cache statistics)
  - Document GET /health endpoint (cache health check)
  - Document GET /entries endpoint (cache entry listing)
  - Document GET /redis/health endpoint (Redis-specific health)
  - Document DELETE / endpoint (clear all cache)
  - Document POST /cleanup endpoint (manual cleanup)
  - Add bearerAuth security and admin notes to all endpoints
  - Build verification: ✅

**Checkpoint:**
✓ Build succeeds | ✓ 6 endpoints under "Cache Admin" tag | ✓ Nested path works

---

### Task T007: Document Frontend Module Endpoints

[P] **Parallelizable with T003, T004, T005, T006**
**Source:** `TASK-007-frontend-module.md`
**Type:** IMPLEMENTATION
**Files:** `Sources/App/Modules/Frontend/FrontendRouter.swift`
**Depends On:** TASK-002

**Commits:**
- [x] T007: Add OpenAPI documentation to 3 Frontend HTML endpoints
  - Add "Frontend" tag to route group
  - Document GET /verify-email endpoint (email verification page)
  - Document GET /reset-password endpoint (password reset form)
  - Document POST /reset-password endpoint (form submission)
  - Note HTML response type and query parameters
  - Build verification: ✅

**Checkpoint:**
✓ Build succeeds | ✓ 3 endpoints under "Frontend" tag | ✓ HTML content type noted

---

### Task T008: Integrate Swagger UI

**Source:** `TASK-008-swagger-ui.md`
**Type:** INTEGRATION
**Files:** `Sources/App/Entrypoint/configure.swift`, `Sources/App/Common/OpenAPI/swagger-ui.html` (new)
**Depends On:** TASK-003, TASK-004, TASK-005, TASK-006, TASK-007

**Commits:**
- [x] T008: Add Swagger UI at /docs endpoint
  - Create Sources/App/Common/OpenAPI/ directory
  - Create swagger-ui.html with CDN resources
  - Configure Swagger UI to load /openapi.json
  - Enable JWT bearer token authentication
  - Register /docs route in configure.swift
  - Add /swagger redirect to /docs
  - Build verification: ✅
  - UI verification: ✅ (manual browser test)

**Checkpoint:**
✓ Build succeeds | ✓ /docs serves Swagger UI | ✓ All 21 endpoints visible | ✓ "Authorize" button works

---

**Phase 1 Completion Checklist:**
- [x] All 8 tasks completed
- [x] Build succeeds with no errors
- [x] All 21 endpoints documented and visible in /openapi.json
- [x] Swagger UI accessible at /docs
- [x] No placeholder descriptions remain
- [x] JWT authentication testable via Swagger UI
- [x] All 5 module tags present (Auth, User, Rules Generation, Cache Admin, Frontend)
- [ ] Create PR: `feature/openapi-documentation` → `staging`

---

## Execution Notes

### Commit Message Format

```
feat(api): add VaporToOpenAPI dependency

- Add VaporToOpenAPI 4.8.1 to Package.swift
- Register /openapi.json endpoint in configure.swift
- Configure basic OpenAPI metadata

Task: T001 | Phase: 1
```

### Build Verification

```bash
# After each commit
swift build

# Verify no warnings
swift build 2>&1 | grep -i warning
```

### OpenAPI Spec Verification

```bash
# Start server
swift run &
sleep 5

# Check spec structure
curl -s http://localhost:8080/openapi.json | jq '.info'

# Count documented endpoints
curl -s http://localhost:8080/openapi.json | jq '.paths | length'

# List all tags
curl -s http://localhost:8080/openapi.json | jq '[.paths[][].tags[]] | unique'

# Stop server
pkill -f "swift run"
```

### Swagger UI Testing

```bash
# Start server
swift run

# Open in browser
open http://localhost:8080/docs

# Test authentication flow:
# 1. Try POST /api/auth/sign-in with test credentials
# 2. Copy accessToken from response
# 3. Click "Authorize" button
# 4. Paste token in bearerAuth field
# 5. Try protected endpoint (e.g., GET /api/user/me)
# 6. Verify 200 response
```

---

## Task Reference

| Task ID | Phase | Type | Files | Status |
|---------|-------|------|-------|--------|
| T001 | 1 | IMPLEMENTATION | Package.swift, configure.swift | OPEN |
| T002 | 1 | IMPLEMENTATION | configure.swift | OPEN |
| T003 | 1 | IMPLEMENTATION | AuthRouter.swift | OPEN |
| T004 | 1 | IMPLEMENTATION | UserRouter.swift | OPEN |
| T005 | 1 | IMPLEMENTATION | RulesGenerationRouter.swift | OPEN |
| T006 | 1 | IMPLEMENTATION | CacheAdminRouter.swift | OPEN |
| T007 | 1 | IMPLEMENTATION | FrontendRouter.swift | OPEN |
| T008 | 1 | INTEGRATION | configure.swift, swagger-ui.html | OPEN |

---

## Timeline Estimate

| Phase | Tasks | Duration | PR |
|-------|-------|----------|-----|
| Phase 1 | T001-T008 | 10-15 hours | #1: feature/openapi-documentation → staging |

**Breakdown:**
- T001: 1 hour (dependency setup)
- T002: 1 hour (metadata configuration)
- T003: 2 hours (Auth module - 6 endpoints, proof of concept)
- T004: 1.5 hours (User module - 4 endpoints)
- T005: 1.5 hours (Rules module - 2 endpoints, streaming handling)
- T006: 2 hours (Cache module - 6 endpoints, nested paths)
- T007: 1 hour (Frontend module - 3 endpoints, HTML docs)
- T008: 2.5 hours (Swagger UI integration and testing)

**Parallel Work Opportunities:**
- After T002 completes, T003-T007 can be worked on simultaneously (different files)
- Estimated 5-6 hours if parallelized, vs 8 hours sequential
- T008 must wait for all module documentation to complete

---

## Notes

**Single Phase Rationale:**
- All work contributes to one feature: "OpenAPI documentation"
- No natural breaking point for multiple PRs
- Swagger UI is only valuable once endpoints are documented
- Solo developer benefits from one cohesive PR review

**Testing Strategy:**
- Build verification after each commit ensures no regressions
- Manual Swagger UI testing happens during T008
- No separate testing tasks - testing integrated into implementation

**Documentation Quality:**
- Focus on "why" and "when" in descriptions, not "what" (technical details auto-generated)
- Example: ✅ "Authenticate user with email and password. Returns JWT tokens for subsequent API requests."
- Example: ❌ "POST endpoint that accepts email and password in request body."

**Rate Limiting Notes:**
- Production limits documented in endpoint descriptions:
  - Image analysis: 3 requests/hour
  - Rules summary: 10 requests/hour
  - API endpoints: 50-1000 requests/hour
  - Admin endpoints: 10-200 requests/5 minutes

**Security Considerations:**
- All User endpoints require JWT (bearerAuth)
- All CacheAdmin endpoints require JWT + admin role
- Auth endpoints mix public (sign-up, sign-in) and protected (logout)
- RulesGeneration endpoints are public with rate limiting
- Frontend endpoints are public (token validation in controller logic)
