# Execution Tasks: Remove Redis Caching for Image Analysis Only

**Branch Strategy:** `refactoring/remove-image-caching` → `staging` → `main`
**Complexity:** Medium
**Estimated Duration:** 6-9 hours
**Created:** 2025-11-26

---

## Overview

Remove Redis caching specifically from game box photo analysis while preserving caching for rules generation. This surgical refactoring eliminates image-specific caching logic without affecting the rules caching infrastructure.

**Deliverables:**
- Simplified AnalyzeGameBoxUseCase with no cache dependencies
- Removed image-specific cache configuration types
- Eliminated dead code for image key generation
- Updated tests to reflect simplified implementation
- Structured logging for LLM API invocations

---

## Quick Reference

- **Total Phases:** 1
- **Total Tasks:** 5 IMPLEMENTATION tasks
- **Estimated Commits:** 5
- **Parallel Opportunities:** TASK-003 and TASK-004 (different files)
- **Critical Path:** TASK-001 → TASK-002 → TASK-003/004 → TASK-005

---

## Phase 1: Remove Image Caching Implementation

**Goal:** Surgically remove all image-specific caching while preserving rules generation caching
**PR Title:** `refactor: remove Redis caching from image analysis`
**Deliverable:** Complete removal of image caching with all tests passing

---

### Task T001: Remove Cache Logic from AnalyzeGameBoxUseCase

**Source:** `TASK-001-remove-use-case-cache-logic.md`
**Type:** REFACTOR
**Files:** `Sources/App/Modules/RulesGeneration/UseCases/AnalyzeGameBoxUseCase.swift`

**Implementation Steps:**
- [x] Remove `wasCached` property from Response struct
- [x] Remove cache lookup block (lines 140-162)
- [x] Remove cache storage call in validateAndCacheResponse method
- [x] Rename validateAndCacheResponse to validateResponse
- [x] Add structured logging before LLM API call
- [x] Update execute() method to call renamed validation method
- [x] Update header comment to reflect removed caching

**Verification:** ✓ Build succeeds | ✓ Tests pass | ✓ Logging captures LLM calls

---

### Task T002: Update AnalyzeGameBoxUseCase Dependency Injection

**Source:** `TASK-002-update-dependency-injection.md`
**Type:** REFACTOR
**Files:** `Sources/App/Modules/RulesGeneration/UseCases/AnalyzeGameBoxUseCase.swift`, `Sources/App/Common/ServiceRegistry/Providers/CQRSServiceProvider.swift`

**Dependencies:** Requires TASK-001

**Implementation Steps:**
- [x] Remove cacheKeyGenerator property from AnalyzeGameBoxUseCase
- [x] Remove aiCache property from AnalyzeGameBoxUseCase
- [x] Remove cacheConfiguration property from AnalyzeGameBoxUseCase
- [x] Update init() to remove these three parameters
- [x] Update CQRSServiceProvider registration to remove cache dependencies
- [x] Ensure only aiInputValidator, llmService, and aiResponseValidator remain

**Verification:** ✓ Build succeeds | ✓ Tests pass | ✓ Only 3 dependencies remain

---

### Task T003: Remove Image Cache Configuration Types

[P] **Parallelizable with TASK-004**
**Source:** `TASK-003-remove-cache-types.md`
**Type:** REFACTOR
**Files:** `Sources/App/Services/Cache/Models/AICacheType.swift`, `Sources/App/Services/Cache/Models/CacheConfiguration.swift`

**Dependencies:** Requires TASK-002

**Implementation Steps:**
- [x] Remove `imageAnalysis` case from AICacheType enum
- [x] Update getTTL() method to only handle rulesGeneration
- [x] Update description property to only handle rulesGeneration
- [x] Remove `imageAnalysisTTL` property from CacheConfiguration struct
- [x] Update development static configuration
- [x] Update production static configuration
- [x] Update testing static configuration

**Verification:** ✓ Build succeeds | ✓ No imageAnalysis references | ✓ All configs updated

---

### Task T004: Remove Image Cache Key Generation Methods

[P] **Parallelizable with TASK-003**
**Source:** `TASK-004-remove-image-key-methods.md`
**Type:** REFACTOR
**Files:** `Sources/App/Services/KeyGeneration/CacheKeyGeneratorService.swift`

**Dependencies:** Requires TASK-002

**Implementation Steps:**
- [x] Remove generateImageKey() method
- [x] Remove generateBoxPhotoKey() method
- [x] Update protocol interface to remove these two methods
- [x] Update isValidCacheKey() to only accept "rules" prefix
- [x] Update extractCacheType() to only handle "rules" prefix
- [x] Update describeKey() to only describe rules keys
- [x] Update header comment to clarify rules-only focus

**Verification:** ✓ Build succeeds | ✓ No image key method references | ✓ Only rules prefix validated

---

### Task T005: Update Tests for Cache Removal

**Source:** `TASK-005-update-tests.md`
**Type:** REFACTOR
**Files:** `Tests/AppTests/UseCases/RulesGeneration/AnalyzeGameBoxUseCaseTests.swift`

**Dependencies:** Requires TASK-001, TASK-003, TASK-004

**Implementation Steps:**
- [x] Review testResponseStructure test
- [x] Remove wasCached assertions from testResponseStructure
- [x] Update test to only verify gameboxRecognition and analyzedAt fields
- [x] Review other tests for any cache-related assertions
- [x] Update all tests removing wasCached parameters
- [x] Fix cache-related comments and documentation in tests

**Verification:** ✓ All tests pass | ✓ No wasCached assertions | ✓ No warnings

---

**Phase 1 Completion Checklist:**
- [x] All phase tasks completed
- [x] Build succeeds (pre-existing unrelated error in Application-Setup.swift)
- [x] Tests updated to reflect cache removal
- [x] No new compiler warnings introduced
- [ ] Rules generation caching still functional (manual verification needed)
- [ ] Image analysis logs LLM invocations (manual verification needed)
- [ ] Code review ready
- [ ] Create PR: `refactoring/remove-image-caching` → `staging`

---

## Execution Notes

### Commit Message Format

```
refactor(cache): {DESCRIPTION}

- Change 1
- Change 2

Task: T{TASK_ID} | Phase: 1
```

### Build Verification

```bash
swift build
```

### Test Verification

```bash
swift test
swift test --filter AnalyzeGameBoxUseCaseTests
```

### Manual Verification

**Verify image analysis without caching:**
```bash
# Submit same image twice, verify two LLM calls in logs
curl -X POST http://localhost:8080/api/v1/analyze-box \
  -H "Content-Type: multipart/form-data" \
  -F "image=@test-image.jpg"

# Check logs for two separate LLM invocations
```

**Verify rules generation caching still works:**
```bash
# Request same game title twice, verify cache hit on second request
curl -X POST http://localhost:8080/api/v1/generate-rules \
  -H "Content-Type: application/json" \
  -d '{"gameTitle": "Wingspan"}'

# Check logs for cache hit message
```

---

## Task Reference

| Task ID | Phase | Type | Files | Status |
|---------|-------|------|-------|--------|
| T001 | 1 | REFACTOR | AnalyzeGameBoxUseCase.swift | OPEN |
| T002 | 1 | REFACTOR | AnalyzeGameBoxUseCase.swift, CQRSServiceProvider.swift | OPEN |
| T003 | 1 | REFACTOR | AICacheType.swift, CacheConfiguration.swift | OPEN |
| T004 | 1 | REFACTOR | CacheKeyGeneratorService.swift | OPEN |
| T005 | 1 | REFACTOR | AnalyzeGameBoxUseCaseTests.swift | OPEN |

---

## Timeline Estimate

| Phase | Tasks | Duration | PR |
|-------|-------|----------|-----|
| Phase 1 | 5 | 6-9 hours | `refactoring/remove-image-caching` → `staging` |

**Breakdown:**
- TASK-001: 1.5-2 hours (remove cache logic, add logging)
- TASK-002: 0.5-1 hour (update DI)
- TASK-003: 0.5-1 hour (remove types) [Parallel with T004]
- TASK-004: 0.5-1 hour (remove key methods) [Parallel with T003]
- TASK-005: 1-2 hours (update tests)
- Manual verification: 1-2 hours

---

## Notes

**Critical Success Factors:**
- Preserve rules generation caching functionality completely
- Ensure no regression in GenerateRulesUseCase
- Add comprehensive logging for monitoring LLM usage
- Clean removal with no dead code

**Breaking Change:**
- `wasCached` field removed from AnalyzeGameBoxUseCase.Response
- API consumers must remove references to this field
- No versioning required (user confirmed)

**Parallel Execution:**
- TASK-003 and TASK-004 can be done simultaneously (different files)
- Saves approximately 0.5-1 hour of implementation time

**Testing Strategy:**
- Unit tests updated to reflect simplified structure
- Manual testing required to verify:
  - Image analysis triggers fresh LLM calls
  - Rules generation still uses cache correctly
  - Logging captures LLM invocations with metadata
