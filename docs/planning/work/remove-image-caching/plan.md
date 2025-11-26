# Implementation Plan: Remove Redis Caching for Image Analysis Only

---
**Date:** 2025-11-26
**Requirements:** `docs/planning/work/remove-image-caching/requirements.md`
**Research:** `docs/planning/work/remove-image-caching/research.md`
**Linear Issue:** [TBD]
**Feature Branch:** `refactoring/remove-image-caching`
**Status:** draft

---

## Summary

**What:** Remove Redis caching specifically from game box photo analysis while preserving caching for rules generation.

**Why:** User explicitly wants to eliminate caching for images only, accepting increased LLM API costs and ensuring every image analysis request triggers fresh AI processing.

**Who:** Game box photo analysis API endpoint users will experience no cache hits; rules generation users remain unaffected.

## Technical Context

### Platform & Technology
- **Stack:** Swift/Vapor 4 (server-side)
- **Version Requirements:** Swift 5.x
- **Build System:** Swift Package Manager (SPM)

### Key Dependencies
**Required:**
- Vapor 4.x: Web framework providing async/await, logging
- Redis: Remains for rules generation caching
- Crypto (Swift stdlib): SHA256 hashing (remains for rules cache keys)

**Optional:**
- None

### Architectural Patterns
**Primary Pattern:** CQRS (Command Query Responsibility Segregation)
**Rationale:** Use cases are organized as Commands (state-changing) and Queries (read-only). AnalyzeGameBoxUseCase is a Query that currently uses caching but will be simplified to direct LLM calls.

**Key Principles:**
- Dependency injection via ServiceRegistry
- Use cases encapsulate business logic directly (no over-engineered abstraction)
- Async/await for all I/O operations

### Files to Modify/Create
| File | Action | Purpose |
|------|--------|---------|
| `Sources/App/Modules/RulesGeneration/UseCases/AnalyzeGameBoxUseCase.swift` | modify | Remove cache lookup, storage, and dependencies; add logging |
| `Sources/App/Services/KeyGeneration/CacheKeyGeneratorService.swift` | modify | Remove image key generation methods |
| `Sources/App/Services/Cache/Models/AICacheType.swift` | modify | Remove imageAnalysis enum case |
| `Sources/App/Services/Cache/Models/CacheConfiguration.swift` | modify | Remove imageAnalysisTTL property |
| `Sources/App/Common/ServiceRegistry/Providers/CQRSServiceProvider.swift` | modify | Update AnalyzeGameBoxUseCase registration to remove cache dependencies |
| `Tests/AppTests/UseCases/RulesGeneration/AnalyzeGameBoxUseCaseTests.swift` | modify | Update tests to not assert cache behavior |

## Technical Decisions

### Decision Summary
Key architectural and technical choices made during research:

1. **Direct Use Case Modification:** Modify AnalyzeGameBoxUseCase directly to remove cache logic
   - Rationale: Use case follows "elegant simplicity" principle with embedded logic
   - Impact: Cleaner use case with fewer dependencies, straightforward data flow

2. **Preserve Cache Infrastructure:** Keep CacheKeyGeneratorService but remove image-specific methods
   - Rationale: Rules generation still requires cache key generation
   - Impact: Service becomes rules-focused, dead code eliminated

3. **Remove Response Field:** Remove `wasCached` field from AnalyzeGameBoxUseCase.Response
   - Rationale: Field would always be false, misleading to API consumers
   - Impact: Breaking API change but cleaner contract

4. **Add Structured Logging:** Log when LLM API is invoked for image analysis
   - Rationale: Enables monitoring of increased LLM call volume
   - Impact: Better observability of LLM usage patterns

## Phase Breakdown

> High-level implementation phases. Detailed tasks will be generated separately.

### Phase 0: Core Use Case Refactoring
**Goal:** Remove caching logic from AnalyzeGameBoxUseCase and update dependency injection

**Deliverables:**
- [ ] Remove cache lookup logic from AnalyzeGameBoxUseCase (lines 140-177)
- [ ] Remove cache storage logic from AnalyzeGameBoxUseCase (lines 336-340)
- [ ] Remove cache-related dependencies from use case (cacheKeyGenerator, aiCache, cacheConfiguration)
- [ ] Remove `wasCached` field from Response struct
- [ ] Add logging when LLM API is invoked
- [ ] Update CQRSServiceProvider to remove cache dependencies from registration

**Dependencies:** None (can start immediately)

**Estimated Effort:** 2-3 hours

**Success Criteria:**
- AnalyzeGameBoxUseCase executes without cache dependencies
- Every image analysis request triggers LLM API call
- Logging captures LLM invocations with metadata
- Project builds without errors

**Technical Approach:**
Simplify the use case by removing the cache lookup block and the cache storage call in the validation method. Update the initializer and registration to no longer require cache services. Add structured logging before the LLM API call to track when fresh analysis occurs. Remove the `wasCached` field from the Response struct since it will always be false.

---

### Phase 1: Cache Configuration Cleanup
**Goal:** Remove image-specific cache configuration and types

**Deliverables:**
- [ ] Remove `imageAnalysis` case from AICacheType enum
- [ ] Update `getTTL()` method to only handle rulesGeneration case
- [ ] Remove `imageAnalysisTTL` from CacheConfiguration struct
- [ ] Update all CacheConfiguration static instances (development, production, testing)
- [ ] Remove image-specific case from `extractCacheType()` method in CacheKeyGeneratorService

**Dependencies:**
- Requires: Phase 0 (use case must no longer reference imageAnalysis type)

**Estimated Effort:** 1-2 hours

**Success Criteria:**
- AICacheType enum only contains rulesGeneration case
- CacheConfiguration only contains rulesGenerationTTL
- No compilation errors related to removed types
- Rules generation continues to use correct TTL

**Technical Approach:**
Remove the imageAnalysis enum case and corresponding TTL property. Update the switch statements in AICacheType and CacheKeyGeneratorService to only handle the rules case. Verify that GenerateRulesUseCase still functions correctly with the reduced configuration.

---

### Phase 2: Cache Key Service Cleanup
**Goal:** Remove image-specific key generation methods

**Deliverables:**
- [ ] Remove `generateImageKey()` method from CacheKeyGeneratorService
- [ ] Remove `generateBoxPhotoKey()` method from CacheKeyGeneratorService
- [ ] Update `isValidCacheKey()` to only validate "rules" prefix
- [ ] Update `describeKey()` to only describe rules keys
- [ ] Update protocol interface to remove image key methods

**Dependencies:**
- Requires: Phase 0 (use case must no longer call these methods)

**Estimated Effort:** 1 hour

**Success Criteria:**
- CacheKeyGeneratorService only contains rules-related methods
- Protocol interface updated to match
- No dead code remains
- Rules generation continues to generate correct cache keys

**Technical Approach:**
Remove the generateImageKey() and generateBoxPhotoKey() methods entirely. Update the helper methods (isValidCacheKey, extractCacheType, describeKey) to only recognize and validate the "rules" prefix. Update the protocol interface to remove these methods. Ensure GenerateRulesUseCase still has access to generateRulesKey().

---

### Phase 3: Testing & Verification
**Goal:** Update tests and verify rules caching remains functional

**Deliverables:**
- [ ] Update AnalyzeGameBoxUseCaseTests to remove cache behavior assertions
- [ ] Verify GenerateRulesUseCase tests still pass (cache behavior intact)
- [ ] Run full test suite to catch any missed references
- [ ] Manual verification: Image analysis triggers LLM calls
- [ ] Manual verification: Rules generation uses cache correctly

**Dependencies:**
- Requires: All previous phases

**Estimated Effort:** 2-3 hours

**Success Criteria:**
- All tests pass
- No test assertions on image cache behavior
- Rules generation cache tests still validate caching
- Manual testing confirms expected behavior
- Logging shows LLM calls for image analysis

**Technical Approach:**
Review AnalyzeGameBoxUseCaseTests and remove any assertions about the wasCached field or cache behavior. Run the full test suite to identify any other tests that reference the removed types or methods. Perform manual testing by submitting the same image twice and verifying that both requests trigger LLM calls (logs show two invocations). Test rules generation by requesting the same game title twice and verifying the second request returns cached results.

---

## Implementation Strategy

### State Management
No state management changes required. This refactoring removes caching logic but does not alter the core business logic flow.

**Data Flow:**
```
[HTTP Request] → [Controller] → [AnalyzeGameBoxUseCase]
    → [Validate Image] → [LLM Service] → [Validate Response] → [Return Result]
```

**Before:**
```
[HTTP Request] → [Controller] → [AnalyzeGameBoxUseCase]
    → [Check Cache] → [Cache Hit? Return Cached : Call LLM] → [Cache Result] → [Return]
```

**After:**
```
[HTTP Request] → [Controller] → [AnalyzeGameBoxUseCase]
    → [Validate Image] → [Log LLM Call] → [LLM Service] → [Validate Response] → [Return Result]
```

**Description:** Simplified flow removes cache lookup and storage, directly invoking LLM service with added logging.

### Data Flow
The use case data flow is simplified by removing the cache layer entirely. Image validation, LLM invocation, and response validation remain unchanged.

### Error Handling
**Strategy:** Swift error throwing (existing pattern preserved)

**Error Types to Handle:**
- Invalid image data: AIProcessingError (unchanged)
- LLM service failures: ContentError (unchanged)
- No new error types introduced

### Performance Considerations
**Optimization Points:**
- None for this phase - user explicitly wants caching removed

**Constraints:**
- LLM API latency: ~2-5 seconds per request (accepted by user)
- Increased API costs: Every request triggers fresh analysis (accepted by user)

## Dependencies & Risks

### Internal Dependencies
- Phase 0 blocks Phase 1 (types must not be referenced before removal)
- Phase 0 blocks Phase 2 (methods must not be called before removal)
- Phase 3 requires all previous phases

### External Dependencies
- LLM Service: Must remain available and functional (no changes to integration)

### Known Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Breaking API change (wasCached field removal) | High | Medium | Document breaking change, consider API versioning |
| Accidental impact on rules caching | Low | High | Comprehensive testing of GenerateRulesUseCase, careful code review |
| Increased LLM API costs | High (intentional) | Low | User is aware and accepts this trade-off |
| LLM rate limiting becomes issue | Medium | Medium | Monitor call volume, add rate limiting if needed (future work) |

### Assumptions
> Critical assumptions that, if invalid, would require plan revision

- Rules generation caching code is completely independent from image caching code
- No other use cases or components reference imageAnalysis enum case
- API consumers can tolerate breaking change to Response structure
- User accepts increased LLM API costs and latency

## Acceptance Criteria Mapping

> Maps requirements.md acceptance criteria to implementation phases

| Acceptance Criterion | Phase | Verification Method |
|---------------------|-------|---------------------|
| Image analysis requests always execute fresh LLM analysis | Phase 0 | Manual test: Submit same image twice, verify two LLM calls in logs |
| Rules generation caching continues to function identically | Phase 3 | Automated test: GenerateRulesUseCase tests pass |
| Image analysis use case no longer has cache dependencies | Phase 0 | Code review: Verify dependency injection in CQRSServiceProvider |
| Redis unavailability doesn't affect image analysis | Phase 0 | Manual test: Stop Redis, verify image analysis still works |
| All tests pass with caching removed | Phase 3 | Automated test: Run full test suite |
| Log entry created when LLM API is called | Phase 0 | Manual test: Check logs for structured logging entry |

## Documentation Plan

**Code Documentation:**
- [ ] Update AnalyzeGameBoxUseCase header comments to reflect removed caching
- [ ] Update CacheKeyGeneratorService comments to clarify rules-only focus
- [ ] Add inline comment explaining LLM logging

**User Documentation:**
- [ ] Update API documentation to reflect removed wasCached field (if applicable)

**Developer Documentation:**
- [ ] Add note to ADRs about image caching removal decision (if applicable)

## Next Steps

1. **Review this plan** with stakeholders/team
2. **Clarify any remaining questions** (see Unknowns below)
3. **Begin Phase 0 implementation**
4. **Work is already on feature branch:** `refactoring/remove-image-caching`

## Remaining Unknowns

> Issues that need resolution before or during implementation

- [ ] Are there other components/tests that reference imageAnalysis enum case? (Will discover during Phase 1)
- [ ] Does the API versioning strategy require a version bump for breaking changes? (To be determined with team)

**Impact:** These unknowns don't block starting Phase 0. If additional references to imageAnalysis are found, they'll be cleaned up in Phase 1. API versioning decision can be made during review.

---

**Plan Status:** draft
**Approval Required From:** User (already approved requirements)
**Target Start Date:** 2025-11-26
