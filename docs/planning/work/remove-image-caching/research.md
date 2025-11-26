# Research: Remove Redis Caching for Image Analysis Only

---
**Date:** 2025-11-26
**Requirements:** `docs/planning/work/remove-image-caching/requirements.md`
**Linear Issue:** [TBD]
**Status:** complete

---

## Platform Detection

**Primary Technology Stack:**
- Language/Framework: Swift/Vapor 4
- Version: Swift 5.x
- Runtime/Platform: Server-side Swift (macOS/Linux)

**Build System:**
- Swift Package Manager (SPM)

## Dependencies Analysis

### Required Dependencies
| Dependency | Version | Purpose | Source |
|------------|---------|---------|--------|
| Vapor | 4.x | Web framework providing logging, async/await | Existing |
| Redis | N/A | Caching backend (remains for rules caching) | Existing |
| Crypto | Swift stdlib | SHA256 hashing for cache keys | Existing |

### Optional Dependencies
No new dependencies required for this refactoring work.

## Codebase Patterns

### Architectural Patterns Found
- **Pattern:** CQRS (Command Query Responsibility Segregation)
  - **Location:** `Sources/App/Common/ServiceRegistry/Providers/CQRSServiceProvider.swift:31-270`
  - **Usage:** Use cases are organized as Commands (state-changing) and Queries (read-only). AnalyzeGameBoxUseCase is registered as a Query at line 259-268.
  - **Relevance:** Image analysis is a Query operation. We need to update dependency injection when removing cache services.

- **Pattern:** Dependency Injection via ServiceRegistry
  - **Location:** `Sources/App/Common/ServiceRegistry/Providers/CQRSServiceProvider.swift:259-268`
  - **Usage:** Use cases are registered with explicit dependency injection:
    ```swift
    registry.register(AnalyzeGameBoxUseCase.self) { app in
        AnalyzeGameBoxUseCase(
            aiInputValidator: try await app.serviceRegistry.resolveRequired(...),
            cacheKeyGenerator: try await app.serviceRegistry.resolveRequired(...),
            aiCache: try await app.serviceRegistry.resolveRequired(...),
            llmService: try await app.serviceRegistry.resolveRequired(...),
            aiResponseValidator: try await app.serviceRegistry.resolveRequired(...),
            cacheConfiguration: try app.configuration.cache
        )
    }
    ```
  - **Relevance:** Must remove `cacheKeyGenerator`, `aiCache`, and `cacheConfiguration` dependencies from AnalyzeGameBoxUseCase registration.

- **Pattern:** Cache Key Generation with Type Prefixes
  - **Location:** `Sources/App/Services/KeyGeneration/CacheKeyGeneratorService.swift:67-92`
  - **Usage:** Three distinct key generation methods exist:
    - `generateRulesKey()` - line 55 - prefix: "rules"
    - `generateImageKey()` - line 68 - prefix: "image"
    - `generateBoxPhotoKey()` - line 80 - prefix: "box"
  - **Relevance:** `generateImageKey()` and `generateBoxPhotoKey()` can be completely removed. Only `generateRulesKey()` must remain for rules caching.

### Code Conventions
- **State Management:** Async/await with Vapor's async runtime
  - Example: `Sources/App/Modules/RulesGeneration/UseCases/AnalyzeGameBoxUseCase.swift:120` (async function signature)
- **Error Handling:** Swift error throwing with custom error types
  - Example: `Sources/App/Modules/RulesGeneration/UseCases/AnalyzeGameBoxUseCase.swift:134` (throws Abort)
- **Async Patterns:** Async/await throughout, cache operations use `await`
  - Example: `Sources/App/Modules/RulesGeneration/UseCases/AnalyzeGameBoxUseCase.swift:144` (`await aiCache.get()`)

### Naming Conventions
- Files: PascalCase.swift
- Types: PascalCase (structs, protocols, enums)
- Functions: camelCase
- Properties: camelCase

## Integration Points

### Components to Modify

| Component | Location | Change Type | Impact |
|-----------|----------|-------------|--------|
| AnalyzeGameBoxUseCase | `Sources/App/Modules/RulesGeneration/UseCases/AnalyzeGameBoxUseCase.swift:24-344` | Modify | Remove cache lookup (141-162), cache storage (336-340), dependencies (66-75, 79-92) |
| CacheKeyGeneratorService | `Sources/App/Services/KeyGeneration/CacheKeyGeneratorService.swift:67-92` | Modify | Remove `generateImageKey()` and `generateBoxPhotoKey()` methods |
| AICacheType enum | `Sources/App/Services/Cache/Models/AICacheType.swift:4-29` | Modify | Remove `imageAnalysis` enum case (line 6) |
| CacheConfiguration | `Sources/App/Services/Cache/Models/CacheConfiguration.swift:11-12` | Modify | Remove `imageAnalysisTTL` property |
| CQRSServiceProvider | `Sources/App/Common/ServiceRegistry/Providers/CQRSServiceProvider.swift:259-268` | Modify | Remove cache-related dependencies from AnalyzeGameBoxUseCase registration |
| AnalyzeGameBoxUseCaseTests | `Tests/AppTests/UseCases/RulesGeneration/AnalyzeGameBoxUseCaseTests.swift:1-303` | Modify | Update tests to not assert cache behavior |

### Dependencies Between Components

```
AnalyzeGameBoxUseCase (Query)
    ├→ cacheKeyGenerator (REMOVE)
    ├→ aiCache (REMOVE)
    ├→ cacheConfiguration (REMOVE)
    ├→ aiInputValidator (KEEP)
    ├→ llmService (KEEP)
    └→ aiResponseValidator (KEEP)

GenerateRulesUseCase (Command)
    ├→ cacheKeyGenerator (KEEP - uses generateRulesKey)
    ├→ aiCache (KEEP)
    ├→ cacheConfiguration (KEEP - uses rulesGenerationTTL)
    └→ [other dependencies...]

CacheKeyGeneratorService
    ├→ generateRulesKey() (KEEP)
    ├→ generateImageKey() (REMOVE)
    ├→ generateBoxPhotoKey() (REMOVE)
    ├→ extractCacheType() (UPDATE - remove imageAnalysis case handling)
    └→ describeKey() (UPDATE - remove image/box case handling)

AICacheType
    ├→ rulesGeneration (KEEP)
    └→ imageAnalysis (REMOVE)

CacheConfiguration
    ├→ rulesGenerationTTL (KEEP)
    └→ imageAnalysisTTL (REMOVE)
```

**Description:** AnalyzeGameBoxUseCase currently depends on cache services that must be removed. GenerateRulesUseCase must remain untouched with its cache dependencies intact. CacheKeyGeneratorService and related types must have image-specific code removed while preserving rules-specific functionality.

### External Integrations
- **API/Service:** LLM Service
  - Usage: Image analysis via `llmService.analyzeImage()` at line 303-306
  - Impact: Will receive increased call volume without cache hits
  - Data Format: Base64-encoded image data URLs

## Clarifications Resolved

> All clarifications were resolved during requirements gathering phase. User confirmed complete removal (no deprecation).

### Clarification 1: Removal Strategy
**Question:** Should image cache code be deprecated or fully removed?
**Finding:** User explicitly requested complete removal
**Decision:** Remove all image-specific cache code entirely (no backward compatibility needed)
**Source:** User confirmation during requirements phase

### Clarification 2: Enum Case Handling
**Question:** Should AICacheType.imageAnalysis be kept for compatibility?
**Finding:** User confirmed no backward compatibility needed
**Decision:** Remove enum case entirely
**Source:** User confirmation during requirements phase

### Clarification 3: Logging Requirements
**Question:** Should we add logging for LLM API calls?
**Finding:** User confirmed logging is required
**Decision:** Add logging when LLM API is invoked for image analysis
**Source:** User confirmation during requirements phase

## Technical Decisions

### Decision 1: Direct Use Case Modification vs Service Layer
**Choice:** Modify use case directly to remove cache logic
**Rationale:**
- AnalyzeGameBoxUseCase follows "elegant simplicity" principle (documented in line 8)
- Cache logic is embedded directly in use case (lines 140-177)
- Removing dependencies is cleaner than adding feature flags or conditional logic
**Alternatives Considered:**
- Create abstraction layer: Rejected because it violates the documented "elegant simplicity" principle
- Use feature flag to disable caching: Rejected because user wants complete removal, not just disabling
**Impact:** Simpler use case with fewer dependencies, more straightforward data flow

### Decision 2: Cache Key Generator Service Preservation
**Choice:** Keep CacheKeyGeneratorService but remove image-specific methods
**Rationale:**
- Service is shared between image analysis and rules generation
- Rules generation still requires `generateRulesKey()` method
- Protocol interface (CacheKeyGeneratorServiceInterface) is used by remaining use cases
**Alternatives Considered:**
- Remove entire service: Rejected because rules generation depends on it
- Keep all methods but deprecate: Rejected because user wants complete removal
**Impact:** Service becomes rules-focused, dead code eliminated

### Decision 3: Response Structure Modification
**Choice:** Remove `wasCached` field from AnalyzeGameBoxUseCase.Response
**Rationale:**
- Field is always false without caching
- Keeping it would be misleading to API consumers
- Clean break from caching functionality
**Alternatives Considered:**
- Keep field, always return false: Rejected because it's misleading and serves no purpose
- Add "cachingDisabled" field: Rejected because it's unnecessary information for clients
**Impact:** Breaking change to API response structure, but cleaner contract

### Decision 4: Logging Strategy
**Choice:** Add structured logging when LLM API is invoked
**Rationale:**
- Enables monitoring of increased LLM call volume
- Consistent with existing logging patterns in the codebase
- User explicitly requested this capability
**Alternatives Considered:**
- No logging: Rejected because user requested monitoring capability
- Metrics instead of logs: Future enhancement, logs are immediate solution
**Impact:** Better observability of LLM usage patterns

## Performance Considerations

**Constraints Identified:**
- LLM API latency: ~2-5 seconds per image analysis request
- Increased LLM API costs: Every request triggers fresh analysis (no cache hits)
- API rate limits: May become more relevant with increased call volume

**Optimization Opportunities:**
- None for this phase - user explicitly wants caching removed
- Future consideration: Client-side caching or CDN-based solutions if needed

## Risks & Unknowns

### Known Risks
1. **Risk:** Increased LLM API costs due to repeated analysis of identical images
   - **Mitigation:** User is aware and accepts this trade-off
   - **Impact if unaddressed:** Higher operational costs, but user decision

2. **Risk:** Breaking API change due to response structure modification
   - **Mitigation:** Document breaking change, update API version if applicable
   - **Impact if unaddressed:** Client applications may break if they rely on `wasCached` field

3. **Risk:** Accidental impact on rules generation caching
   - **Mitigation:** Comprehensive testing of GenerateRulesUseCase, careful removal of only image-specific code
   - **Impact if unaddressed:** Rules caching breaks, significant performance degradation

### Remaining Unknowns
- [ ] Are there other components/tests that reference imageAnalysis enum case?
- [ ] Does the API versioning strategy require a version bump for breaking changes?

## Research Summary

**Key Findings:**
1. **Clean Separation Exists:** Image caching and rules caching use distinct keys (box_* vs rules_*), enum cases, and TTL configurations
2. **Dependency Injection is Well-Structured:** CQRSServiceProvider cleanly separates dependencies, making removal straightforward
3. **Tests are Structural Only:** Existing tests don't mock cache behavior, only validate structure - minimal test updates needed

**Confidence Level:** High
- All affected files identified and reviewed
- Clear separation between image and rules caching
- No hidden dependencies discovered
- User requirements are clear and unambiguous

**Recommended Next Steps:**
1. Create detailed implementation plan with phases
2. Start with removing image cache dependencies from AnalyzeGameBoxUseCase
3. Update CacheKeyGeneratorService to remove image methods
4. Clean up configuration and type enums
5. Verify rules generation caching remains functional

---

**Ready for Planning:** Yes
