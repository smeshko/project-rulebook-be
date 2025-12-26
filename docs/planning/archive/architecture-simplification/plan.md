# Implementation Plan: Architecture Simplification

---
**Date:** 2025-12-04
**Requirements:** `docs/planning/work/architecture-simplification/requirements.md`
**Research:** `docs/planning/work/architecture-simplification/research.md`
**Branch:** `refactoring/architecture-simplification`
**Status:** draft
---

## Summary

**What:** Remove Use Case layer (17 files) and ServiceRegistry infrastructure (11 files), replacing with simple `req.services.*` and `req.repositories.*` property accessors.

**Why:** Reduce architectural complexity from ~9,900 lines of indirection to ~200 lines of simple accessors. Single consistent access pattern across entire codebase.

**Who:** All developers working on the codebase; affects every controller and test file.

## Technical Context

**Stack:** Swift/Vapor (Server-Side Swift)
**Version:** Swift 5.9+, Vapor 4.x
**Build:** SPM

**Key Dependencies:**
- Vapor: Web framework, Request/Application types
- Fluent: Database access through repositories
- NIO: NIOLock for thread-safe storage

**Architecture:** Controller-based with property accessors
- Rationale: FrontendController already demonstrates this pattern successfully

**Files:**

| File | Action | Purpose |
|------|--------|---------|
| `Sources/App/Common/Extensions/Request+Services.swift` | create | `req.services.*`, `req.repositories.*` |
| `Sources/App/Common/Extensions/Application+Services.swift` | create | Service storage on Application |
| `Sources/App/Modules/Auth/Controllers/AuthController.swift` | modify | Inline 5 use cases |
| `Sources/App/Modules/User/Controllers/UserController.swift` | modify | Inline 4 use cases |
| `Sources/App/Modules/CacheAdmin/Controllers/CacheAdminController.swift` | modify | Inline 6 use cases |
| `Sources/App/Modules/RulesGeneration/Controllers/RulesGenerationController.swift` | modify | Inline 2 complex use cases |
| `Sources/App/Application-Setup.swift` | modify | Replace `setupServiceRegistry()` |
| `Tests/AppTests/Framework/IsolatedTestWorld.swift` | modify | Property-based injection |
| 17 Use Case files | delete | No longer needed |
| 11 ServiceRegistry files | delete | No longer needed |
| 3 Architecture files | delete | No longer needed |
| 12 Use Case test files | delete | Coverage moved to controller tests |

## Technical Decisions

1. **Property-based DI:** Settable properties on Application for test injection - simpler than factories
2. **Struct accessors:** Request extensions return lightweight structs for service access - zero allocation
3. **Keep all error types:** No changes to AuthenticationError, AIProcessingError, ContentError
4. **Preserve business logic exactly:** Move code, don't refactor it during migration

## Phase Breakdown

### Phase 0: Infrastructure Foundation
**Goal:** Create new accessor pattern that works alongside existing system

**Deliverables:**
- [ ] `Application+Services.swift` with service/repository storage
- [ ] `Request+Services.swift` with accessor structs
- [ ] Verification that new pattern works in one controller method
- [ ] Build passes with both patterns active

**Dependencies:** None
**Effort:** 2-4 hours

**Success Criteria:**
- New `req.services.llm` and `req.repositories.users` syntax compiles
- At least one controller method uses new pattern successfully
- All existing tests still pass

**Approach:** Create minimal infrastructure first. Add one service and one repository. Test in FrontendController (already similar pattern). Expand to full list only after verification.

---

### Phase 1: Auth Module Migration
**Goal:** Migrate all 5 auth use cases to AuthController, establish migration pattern

**Deliverables:**
- [ ] SignUpUseCase logic moved to AuthController
- [ ] SignInUseCase logic moved to AuthController
- [ ] LogoutUseCase logic moved to AuthController
- [ ] RefreshTokenUseCase logic moved to AuthController
- [ ] AppleSignInUseCase logic moved to AuthController
- [ ] All auth use case test scenarios migrated to AuthController tests
- [ ] Auth use case files deleted

**Dependencies:** Phase 0
**Effort:** 4-6 hours

**Success Criteria:**
- All Auth endpoints return identical responses
- All auth test scenarios pass in controller tests
- No files remain in `Auth/UseCases/`
- Build passes, all tests pass

**Approach:** Start with simplest use case (LogoutUseCase - just deletes tokens). Copy logic exactly, verify tests pass, then delete use case. Repeat for each. SignUpUseCase last (has duplicate email detection complexity).

---

### Phase 2: User Module Migration
**Goal:** Migrate all 4 user use cases to UserController

**Deliverables:**
- [ ] GetCurrentUserUseCase logic moved to UserController
- [ ] ListUsersUseCase logic moved to UserController
- [ ] UpdateUserProfileUseCase logic moved to UserController
- [ ] DeleteUserAccountUseCase logic moved to UserController
- [ ] All user use case test scenarios migrated
- [ ] User use case files deleted

**Dependencies:** Phase 1
**Effort:** 3-4 hours

**Success Criteria:**
- All User endpoints return identical responses
- All user test scenarios pass
- No files remain in `User/UseCases/`
- Build passes, all tests pass

**Approach:** Simple use cases - mostly repository calls. GetCurrentUserUseCase is trivial (returns authenticated user). DeleteUserAccountUseCase has cascade logic to preserve.

---

### Phase 3: CacheAdmin Module Migration
**Goal:** Migrate all 6 cache admin use cases to CacheAdminController

**Deliverables:**
- [ ] GetCacheStatsUseCase logic moved
- [ ] ClearCacheUseCase logic moved
- [ ] GetCacheKeyUseCase logic moved
- [ ] DeleteCacheKeyUseCase logic moved
- [ ] ListCacheKeysUseCase logic moved
- [ ] RefreshCacheUseCase logic moved
- [ ] All cache admin test scenarios migrated
- [ ] CacheAdmin use case files deleted

**Dependencies:** Phase 2
**Effort:** 3-4 hours

**Success Criteria:**
- All CacheAdmin endpoints return identical responses
- All cache test scenarios pass
- No files remain in `CacheAdmin/UseCases/`
- Build passes, all tests pass

**Approach:** These are admin operations with straightforward cache service calls. Low risk.

---

### Phase 4: RulesGeneration Module Migration (HIGHEST RISK)
**Goal:** Carefully migrate complex AI logic to RulesGenerationController

**Deliverables:**
- [ ] GenerateRulesUseCase logic moved (515 lines, 9-step orchestration)
- [ ] AnalyzeGameBoxUseCase logic moved (287 lines, binary format detection)
- [ ] All RulesGeneration test scenarios migrated with enhanced coverage
- [ ] RulesGeneration use case files deleted

**Dependencies:** Phase 3
**Effort:** 6-8 hours

**Success Criteria:**
- Rules generation returns identical responses for same inputs
- Game box analysis handles all 4 image formats correctly
- Cache/DB fallback behavior unchanged
- All prompt injection patterns still detected
- All test scenarios pass
- No files remain in `RulesGeneration/UseCases/`

**Approach:**
1. Copy GenerateRulesUseCase.execute() body EXACTLY to controller
2. Run all tests - they should pass with no logic changes
3. Refactor only the dependency access (use `req.services.*` instead of injected deps)
4. Verify again
5. Repeat for AnalyzeGameBoxUseCase
6. Delete use case files only after all tests pass

---

### Phase 5: Infrastructure Cleanup
**Goal:** Delete all old infrastructure, finalize test framework

**Deliverables:**
- [ ] All 11 ServiceRegistry files deleted
- [ ] All 3 Architecture files deleted
- [ ] `Application-Setup.swift` simplified (remove `setupServiceRegistry()`)
- [ ] TestWorld/IsolatedTestWorld updated to use property injection
- [ ] ServiceRegistry test file deleted
- [ ] All remaining use case test files deleted

**Dependencies:** Phase 4
**Effort:** 3-4 hours

**Success Criteria:**
- No files remain in `Common/ServiceRegistry/`
- No files remain in `Common/Architecture/`
- No files remain in `Tests/AppTests/UseCases/`
- Build passes with no warnings
- All tests pass
- `grep -r "serviceRegistry" Sources/` returns no results
- `grep -r "UseCases" Sources/` returns no results (except module folders)

**Approach:**
1. Update test framework first (IsolatedTestWorld)
2. Verify all tests pass with new injection
3. Remove ServiceRegistry imports from Application-Setup
4. Simplify setup to direct property assignment
5. Delete infrastructure files
6. Final build and test verification

---

### Phase 6: Verification & Documentation
**Goal:** Final verification and code quality checks

**Deliverables:**
- [ ] Full test suite passes
- [ ] Build passes with no warnings
- [ ] Line count verification (~6,000+ lines removed)
- [ ] PR description with migration summary

**Dependencies:** Phase 5
**Effort:** 1-2 hours

**Success Criteria:**
- `swift build` succeeds with no warnings
- `swift test` passes all tests
- Net code reduction of 6,000+ lines
- Single access pattern: `req.services.*`, `req.repositories.*`

**Approach:** Run full test suite multiple times. Verify line counts. Prepare PR with detailed description of all changes.

---

## Implementation Strategy

**State Management:** Services stored on Application, accessed through Request extensions
```swift
extension Application {
    var llmService: LLMService {
        get { storage[LLMServiceKey.self]! }
        set { storage[LLMServiceKey.self] = newValue }
    }
}

extension Request {
    var services: Services { Services(app: application) }
}

struct Services {
    let app: Application
    var llm: LLMService { app.llmService }
}
```

**Data Flow:** HTTP Request → Controller Method → req.services/repositories → Response

**Error Handling:** No changes
- Validation errors: `Abort(.badRequest, reason:)`
- Domain errors: `AuthenticationError`, `AIProcessingError`, `ContentError`
- All error-to-HTTP mapping handled by existing middleware

**Performance:** No degradation expected
- Property access is synchronous (no async resolution)
- Same underlying service instances
- Fewer function calls (no use case indirection)

## Dependencies & Risks

**Internal:**
- Phase 0 → All other phases
- Phase 1-4 can partially parallelize if needed
- Phase 5 requires all migrations complete

**External:** None (no API changes, no new dependencies)

**Risks:**

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| RulesGeneration logic regression | Medium | High | Copy exact code, run tests after each change |
| Test coverage gaps | Low | Medium | Map use case tests to controller tests first |
| Binary format detection breaks | Low | High | Add explicit tests for each format |
| Prompt injection bypass | Low | Critical | Preserve all 27+ validation patterns |
| Build failures | Low | Medium | Incremental changes, verify build each phase |

**Assumptions:**
- Property-based injection sufficient for tests (verified in research)
- Controllers can handle increased complexity (already proven in FrontendController)
- Integration tests provide adequate coverage (replacing use case unit tests)

## Acceptance Mapping

| Criterion (from requirements.md) | Phase | Verification |
|----------------------------------|-------|--------------|
| All use cases deleted (17 files) | Phase 1-4 | `find Sources -name "*UseCase.swift" -type f` returns empty |
| All ServiceRegistry deleted (11 files) | Phase 5 | `ls Sources/App/Common/ServiceRegistry/` fails |
| All Architecture deleted (3 files) | Phase 5 | `ls Sources/App/Common/Architecture/` fails |
| New accessor pattern works | Phase 0 | Compile + run one endpoint |
| All business logic preserved | Phase 1-4 | All tests pass |
| All test scenarios migrated | Phase 1-4 | No files in `Tests/AppTests/UseCases/` |
| Build passes with no warnings | Phase 6 | `swift build` clean |
| All tests pass | Phase 6 | `swift test` green |
| Net code reduction ~6,000+ lines | Phase 6 | `cloc` before/after comparison |

## Next Steps

1. Review plan
2. Clarify any remaining unknowns
3. Generate tasks: `/tasks`
4. Begin Phase 0 implementation

**Unknowns:** None - all clarifications resolved in research phase

---
**Status:** draft
