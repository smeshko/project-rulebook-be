# Execution Tasks: Architecture Simplification

**Branch:** `refactoring/architecture-simplification` → `staging` → `main`
**Complexity:** Complex
**Duration:** ~22-32 hours across 6 phases
**Created:** 2025-12-04

---

## Overview

Remove Use Case layer (17 files) and ServiceRegistry infrastructure (11 files), replacing with simple `req.services.*` and `req.repositories.*` property accessors. Eliminates ~9,900 lines of architectural overhead.

**Deliverables:**
- New accessor infrastructure (`Request+Services.swift`, `Application+Services.swift`)
- All 17 use cases migrated to controllers
- All 11 ServiceRegistry files deleted
- All 3 Architecture files deleted
- Test framework updated for property injection

---

## Quick Reference

- **Phases:** 6 | **Tasks:** 18 | **Commits:** ~18
- **Parallel:** T004-T006 (Auth migrations) | T012-T013 (RulesGen migrations)
- **Critical Path:** T001 → T002 → T003 → T007 → T011 → T014 → T017 → T018

---

## Phase 0: Infrastructure Foundation

**Goal:** Create new accessor pattern that works alongside existing system
**PR:** `refactor(arch): add service accessor infrastructure`
**Deliverable:** Working `req.services.*` and `req.repositories.*` syntax

---

### Task T001: Create Request+Services Infrastructure
**Source:** `TASK-001-request-services-infrastructure.md`
**Type:** IMPLEMENTATION
**Files:** `Sources/App/Common/Extensions/Application+Services.swift`, `Sources/App/Common/Extensions/Request+Services.swift`

**Implementation Steps:**
- [ ] Create Application+Services.swift with storage keys
- [ ] Create Request+Services.swift with accessor structs
- [ ] Add settable properties for all services and repositories
- [ ] Verify new syntax compiles

**Checkpoint:** ✓ Build succeeds

---

### Task T002: Initialize Services in Application Setup
**Source:** `TASK-002-initialize-services-in-setup.md`
**Type:** IMPLEMENTATION
**Files:** `Sources/App/Application-Setup.swift`

**Implementation Steps:**
- [ ] Add service initialization after existing setupServiceRegistry()
- [ ] Initialize all repositories with database connection
- [ ] Initialize all external and domain services
- [ ] Both patterns coexist temporarily

**Checkpoint:** ✓ Build succeeds | ✓ Tests pass

---

### Task T003: Verify New Pattern in Controller
**Source:** `TASK-003-verify-new-pattern.md`
**Type:** IMPLEMENTATION
**Files:** `Sources/App/Modules/Auth/Controllers/AuthController.swift`

**Implementation Steps:**
- [ ] Update logout endpoint to use new pattern
- [ ] Replace `req.useCases.auth.logout` with `req.repositories.refreshTokens`
- [ ] Verify endpoint works correctly

**Checkpoint:** ✓ Build succeeds | ✓ Auth tests pass

---

**Phase 0 Completion:**
- [ ] All 3 tasks complete
- [ ] Build succeeds
- [ ] Tests pass
- [ ] New pattern verified working

---

## Phase 1: Auth Module Migration

**Goal:** Migrate all 5 auth use cases to AuthController
**PR:** `refactor(auth): migrate use cases to controller`
**Deliverable:** All auth business logic in controller, use case files deleted

---

### Task T004: Migrate SignUpUseCase
[P] **Parallelizable with T005, T006**
**Source:** `TASK-004-migrate-auth-signup.md`
**Type:** REFACTOR
**Files:** `Sources/App/Modules/Auth/Controllers/AuthController.swift`

**Implementation Steps:**
- [ ] Copy execute() method body (lines 71-126)
- [ ] Copy sendEmailVerification() helper (lines 132-170)
- [ ] Preserve EXACT duplicate email detection (lines 88-101)
- [ ] Update to use req.repositories.* syntax

**Checkpoint:** ✓ Build succeeds | ✓ SignUp tests pass

---

### Task T005: Migrate SignInUseCase
[P] **Parallelizable with T004, T006**
**Source:** `TASK-005-migrate-auth-signin.md`
**Type:** REFACTOR
**Files:** `Sources/App/Modules/Auth/Controllers/AuthController.swift`

**Implementation Steps:**
- [ ] Copy execute() method body
- [ ] Preserve password verification logic
- [ ] Update to use req.repositories.* syntax

**Checkpoint:** ✓ Build succeeds | ✓ SignIn tests pass

---

### Task T006: Migrate RefreshToken and AppleSignIn
[P] **Parallelizable with T004, T005**
**Source:** `TASK-006-migrate-auth-refresh-apple.md`
**Type:** REFACTOR
**Files:** `Sources/App/Modules/Auth/Controllers/AuthController.swift`

**Implementation Steps:**
- [ ] Copy RefreshTokenUseCase.execute() logic
- [ ] Copy AppleSignInUseCase.execute() logic
- [ ] Preserve token rotation logic
- [ ] Update to use req.repositories.* syntax

**Checkpoint:** ✓ Build succeeds | ✓ Refresh/Apple tests pass

---

### Task T007: Delete Auth Use Cases
**Source:** `TASK-007-delete-auth-usecases.md`
**Type:** REFACTOR
**Depends On:** T004, T005, T006
**Files:** `Sources/App/Modules/Auth/UseCases/*` (delete)

**Implementation Steps:**
- [ ] Verify all auth controller tests pass
- [ ] Delete all 5 use case files
- [ ] Delete UseCases directory
- [ ] Update UseCaseAccessors.swift
- [ ] Delete auth use case test files

**Checkpoint:** ✓ Build succeeds | ✓ All auth tests pass | ✓ No UseCases dir

---

**Phase 1 Completion:**
- [ ] All 4 tasks complete
- [ ] Build succeeds
- [ ] Tests pass
- [ ] Auth/UseCases/ directory doesn't exist
- [ ] Create PR: `refactoring/architecture-simplification` → `staging`

---

## Phase 2: User Module Migration

**Goal:** Migrate all 4 user use cases to UserController
**PR:** Part of main PR (continue on same branch)
**Deliverable:** All user business logic in controller, use case files deleted

---

### Task T008: Migrate User Module Use Cases
**Source:** `TASK-008-migrate-user-module.md`
**Type:** REFACTOR
**Files:** `Sources/App/Modules/User/Controllers/UserController.swift`

**Implementation Steps:**
- [ ] Migrate GetCurrentUserUseCase (trivial)
- [ ] Migrate ListUsersUseCase
- [ ] Migrate UpdateUserProfileUseCase
- [ ] Migrate DeleteUserAccountUseCase (cascade logic)

**Checkpoint:** ✓ Build succeeds | ✓ User tests pass

---

### Task T009: Delete User Use Cases
**Source:** `TASK-009-delete-user-usecases.md`
**Type:** REFACTOR
**Depends On:** T008
**Files:** `Sources/App/Modules/User/UseCases/*` (delete)

**Implementation Steps:**
- [ ] Verify all user controller tests pass
- [ ] Delete all 4 use case files
- [ ] Delete UseCases directory
- [ ] Update UseCaseAccessors.swift

**Checkpoint:** ✓ Build succeeds | ✓ All user tests pass | ✓ No UseCases dir

---

**Phase 2 Completion:**
- [ ] All 2 tasks complete
- [ ] Build succeeds
- [ ] Tests pass
- [ ] User/UseCases/ directory doesn't exist

---

## Phase 3: CacheAdmin Module Migration

**Goal:** Migrate all 6 cache admin use cases to CacheAdminController
**PR:** Part of main PR (continue on same branch)
**Deliverable:** All cache admin business logic in controller, use case files deleted

---

### Task T010: Migrate CacheAdmin Module Use Cases
**Source:** `TASK-010-migrate-cacheadmin-module.md`
**Type:** REFACTOR
**Files:** `Sources/App/Modules/CacheAdmin/Controllers/CacheAdminController.swift`

**Implementation Steps:**
- [ ] Migrate GetCacheStatsUseCase
- [ ] Migrate ClearCacheUseCase
- [ ] Migrate GetCacheKeyUseCase
- [ ] Migrate DeleteCacheKeyUseCase
- [ ] Migrate ListCacheKeysUseCase
- [ ] Migrate RefreshCacheUseCase

**Checkpoint:** ✓ Build succeeds | ✓ CacheAdmin tests pass

---

### Task T011: Delete CacheAdmin Use Cases
**Source:** `TASK-011-delete-cacheadmin-usecases.md`
**Type:** REFACTOR
**Depends On:** T010
**Files:** `Sources/App/Modules/CacheAdmin/UseCases/*` (delete)

**Implementation Steps:**
- [ ] Verify all cache admin controller tests pass
- [ ] Delete all 6 use case files
- [ ] Delete UseCases directory
- [ ] Update UseCaseAccessors.swift

**Checkpoint:** ✓ Build succeeds | ✓ All cache tests pass | ✓ No UseCases dir

---

**Phase 3 Completion:**
- [ ] All 2 tasks complete
- [ ] Build succeeds
- [ ] Tests pass
- [ ] CacheAdmin/UseCases/ directory doesn't exist

---

## Phase 4: RulesGeneration Module Migration (HIGHEST RISK)

**Goal:** Carefully migrate complex AI logic to RulesGenerationController
**PR:** Part of main PR (continue on same branch)
**Deliverable:** Complex AI orchestration preserved in controller, use case files deleted

---

### Task T012: Migrate GenerateRulesUseCase (HIGHEST RISK)
[P] **Parallelizable with T013**
**Source:** `TASK-012-migrate-generate-rules.md`
**Type:** REFACTOR
**Files:** `Sources/App/Modules/RulesGeneration/Controllers/RulesGenerationController.swift`

**Implementation Steps:**
- [ ] Copy entire execute() method (515 lines, 9-step orchestration)
- [ ] Copy makeRulesSummary() helper
- [ ] Copy persistGeneratedSummary() helper (upsert pattern)
- [ ] Preserve ALL validation, caching, logging exactly
- [ ] Update to use req.services.* syntax

**Checkpoint:** ✓ Build succeeds | ✓ Rules generation tests pass

---

### Task T013: Migrate AnalyzeGameBoxUseCase
[P] **Parallelizable with T012**
**Source:** `TASK-013-migrate-analyze-gamebox.md`
**Type:** REFACTOR
**Files:** `Sources/App/Modules/RulesGeneration/Controllers/RulesGenerationController.swift`

**Implementation Steps:**
- [ ] Copy execute() method with all helpers
- [ ] Preserve EXACT binary header detection (JPEG, PNG, GIF, WebP)
- [ ] Preserve image validation sequence
- [ ] Update to use req.services.* syntax

**Checkpoint:** ✓ Build succeeds | ✓ Game box analysis tests pass

---

### Task T014: Delete RulesGeneration Use Cases
**Source:** `TASK-014-delete-rulesgen-usecases.md`
**Type:** REFACTOR
**Depends On:** T012, T013
**Files:** `Sources/App/Modules/RulesGeneration/UseCases/*` (delete)

**Implementation Steps:**
- [ ] Run full test suite - verify comprehensive
- [ ] Delete GenerateRulesUseCase.swift
- [ ] Delete AnalyzeGameBoxUseCase.swift
- [ ] Delete UseCases directory
- [ ] Update UseCaseAccessors.swift

**Checkpoint:** ✓ Build succeeds | ✓ All RulesGen tests pass | ✓ No UseCases dir

---

**Phase 4 Completion:**
- [ ] All 3 tasks complete
- [ ] Build succeeds
- [ ] Tests pass
- [ ] RulesGeneration/UseCases/ directory doesn't exist
- [ ] All 17 use cases now deleted

---

## Phase 5: Infrastructure Cleanup

**Goal:** Delete all old infrastructure, update test framework
**PR:** Part of main PR (continue on same branch)
**Deliverable:** ServiceRegistry and Architecture files deleted, tests using property injection

---

### Task T015: Delete ServiceRegistry Infrastructure
**Source:** `TASK-015-delete-service-registry.md`
**Type:** REFACTOR
**Files:** `Sources/App/Common/ServiceRegistry/*` (delete - 11 files)

**Implementation Steps:**
- [ ] Remove setupServiceRegistry() call from Application-Setup
- [ ] Delete all 11 ServiceRegistry files (~2,500 lines)
- [ ] Delete ServiceRegistry directory
- [ ] Delete ServiceRegistry tests
- [ ] Remove all serviceRegistry references

**Checkpoint:** ✓ Build succeeds | ✓ No ServiceRegistry references

---

### Task T016: Delete Architecture Files
**Source:** `TASK-016-delete-architecture-usecases.md`
**Type:** REFACTOR
**Depends On:** T015
**Files:** `Sources/App/Common/Architecture/*` (delete - 3 files)

**Implementation Steps:**
- [ ] Check if RequestContext is used elsewhere (relocate if needed)
- [ ] Delete UseCaseAccessors.swift
- [ ] Delete UseCase.swift
- [ ] Delete Architecture directory

**Checkpoint:** ✓ Build succeeds | ✓ No Architecture references

---

### Task T017: Update Test Framework
**Source:** `TASK-017-update-test-framework.md`
**Type:** REFACTOR
**Depends On:** T015, T016
**Files:** `Tests/AppTests/Framework/IsolatedTestWorld.swift`, `Tests/AppTests/Framework/TestWorld.swift`

**Implementation Steps:**
- [ ] Remove ServiceRegistry registration calls
- [ ] Use direct property assignment on Application
- [ ] Remove setupServiceRegistry() calls from tests
- [ ] Verify all tests pass with new injection

**Checkpoint:** ✓ Build succeeds | ✓ All tests pass | ✓ No serviceRegistry in tests

---

**Phase 5 Completion:**
- [ ] All 3 tasks complete
- [ ] Build succeeds
- [ ] Tests pass
- [ ] ServiceRegistry/ directory doesn't exist
- [ ] Architecture/ directory doesn't exist (or only RequestContext)

---

## Phase 6: Final Verification

**Goal:** Verify migration complete, prepare PR
**PR:** Final verification before merge
**Deliverable:** Clean build, all tests passing, PR ready

---

### Task T018: Final Verification and Cleanup
**Source:** `TASK-018-final-verification.md`
**Type:** INTEGRATION
**Depends On:** T017

**Implementation Steps:**
- [ ] Run full test suite multiple times
- [ ] Verify no warnings in build
- [ ] Count lines removed (~6,000+ expected)
- [ ] Check for orphaned imports
- [ ] Prepare comprehensive PR description

**Checkpoint:** ✓ Build succeeds | ✓ All tests pass | ✓ No warnings | ✓ ~6,000+ lines removed

---

**Phase 6 Completion:**
- [ ] Task complete
- [ ] Build succeeds with no warnings
- [ ] All tests pass
- [ ] PR ready for review

---

## Execution

**Commit Format:**
```
refactor(module): description

- Change 1
- Change 2

Task: TXXX | Phase: N
```

**Build:** `swift build`
**Test:** `swift test`

---

## Task Reference

| ID | Phase | Task | Type | Files | Status |
|----|-------|------|------|-------|--------|
| T001 | 0 | Create Request+Services Infrastructure | IMPL | 2 new | OPEN |
| T002 | 0 | Initialize Services in Setup | IMPL | 1 modify | OPEN |
| T003 | 0 | Verify New Pattern | IMPL | 1 modify | OPEN |
| T004 | 1 | Migrate SignUpUseCase | REFACTOR | 1 modify | OPEN |
| T005 | 1 | Migrate SignInUseCase | REFACTOR | 1 modify | OPEN |
| T006 | 1 | Migrate RefreshToken/AppleSignIn | REFACTOR | 1 modify | OPEN |
| T007 | 1 | Delete Auth Use Cases | REFACTOR | 5+ delete | OPEN |
| T008 | 2 | Migrate User Module | REFACTOR | 1 modify | OPEN |
| T009 | 2 | Delete User Use Cases | REFACTOR | 4+ delete | OPEN |
| T010 | 3 | Migrate CacheAdmin Module | REFACTOR | 1 modify | OPEN |
| T011 | 3 | Delete CacheAdmin Use Cases | REFACTOR | 6+ delete | OPEN |
| T012 | 4 | Migrate GenerateRulesUseCase | REFACTOR | 1 modify | OPEN |
| T013 | 4 | Migrate AnalyzeGameBoxUseCase | REFACTOR | 1 modify | OPEN |
| T014 | 4 | Delete RulesGeneration Use Cases | REFACTOR | 2+ delete | OPEN |
| T015 | 5 | Delete ServiceRegistry | REFACTOR | 11 delete | OPEN |
| T016 | 5 | Delete Architecture Files | REFACTOR | 3 delete | OPEN |
| T017 | 5 | Update Test Framework | REFACTOR | 2 modify | OPEN |
| T018 | 6 | Final Verification | INTEGRATION | cleanup | OPEN |

---

## Timeline Estimate

| Phase | Tasks | Effort | Cumulative |
|-------|-------|--------|------------|
| Phase 0 | 3 | 2-4 hours | 2-4 hours |
| Phase 1 | 4 | 4-6 hours | 6-10 hours |
| Phase 2 | 2 | 3-4 hours | 9-14 hours |
| Phase 3 | 2 | 3-4 hours | 12-18 hours |
| Phase 4 | 3 | 6-8 hours | 18-26 hours |
| Phase 5 | 3 | 3-4 hours | 21-30 hours |
| Phase 6 | 1 | 1-2 hours | 22-32 hours |

---

## Notes

- **Critical:** GenerateRulesUseCase (T012) is highest risk - 515 lines of orchestration
- **Critical:** AnalyzeGameBoxUseCase (T013) has binary format detection - preserve exact bytes
- **Parallel:** T004-T006 can be worked simultaneously
- **Parallel:** T012-T013 can be worked simultaneously
- **All phases:** Single PR strategy - all changes go to same branch
- **Testing:** Verify build and tests after EVERY task
