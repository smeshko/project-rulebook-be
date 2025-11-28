---
type: refactor
status: draft
priority: P2
created: 2025-11-26
slug: remove-image-caching
feature_branch: refactoring/remove-image-caching
linear_issue:
linear_url:
---

# Remove Redis Caching for Image Analysis Only

## Overview

**Context**: The application currently uses Redis to cache both game box image analysis results and rules generation results. The caching infrastructure is shared between these two features, with distinct cache types (imageAnalysis vs rulesGeneration) and TTL configurations.

**Objective**: Remove Redis caching specifically for the game box photo analysis feature while preserving caching for rules generation. This requires surgically removing image-specific caching logic without affecting the rules caching infrastructure.

**Impact**:
- Game box photo analysis API endpoint will no longer benefit from cache hits
- Every image analysis request will trigger an LLM API call
- Rules generation caching remains unaffected
- Slightly increased LLM API costs for repeated image analysis requests
- Redis infrastructure remains in place for rules caching

## Requirements

> Requirements must be testable and technology-agnostic. Focus on WHAT needs to happen, not HOW.

1. **REQ-001**: Image analysis requests must always execute fresh LLM analysis
   - Rationale: User explicitly wants to eliminate caching for images only

2. **REQ-002**: Image cache key generation logic must be completely removed
   - Rationale: Eliminate dead code paths that are no longer used (no deprecation, full removal)

3. **REQ-003**: Rules generation caching must continue to function identically to current behavior
   - Rationale: Only image caching should be affected, not rules caching

4. **REQ-004**: Image analysis cache type configuration must be completely removed
   - Rationale: No need to maintain configuration for unused functionality (AICacheType.imageAnalysis enum case and imageAnalysisTTL must be removed entirely)

5. **REQ-005**: The caching infrastructure (RedisAICacheService, RedisCacheService) must remain operational
   - Rationale: Rules generation still requires caching capabilities

6. **REQ-006**: Service dependency injection must reflect the removal of caching from image analysis
   - Rationale: Image analysis use case should no longer depend on cache services

7. **REQ-007**: All existing unit/integration tests must pass with caching removed
   - Rationale: Ensure no regressions in related functionality

8. **REQ-008**: Image analysis must log when LLM API calls are made
   - Rationale: Enable monitoring of LLM API call volume after cache removal

## Acceptance Criteria

> Measurable conditions that must be met for this work to be considered complete.

### Functional Acceptance
- [ ] **Given** a game box photo is submitted for analysis, **When** the same photo is submitted multiple times, **Then** each request triggers a fresh LLM API call (no cache hits)

- [ ] **Given** a rules generation request is made, **When** the same game title is requested multiple times, **Then** subsequent requests return cached results (cache behavior unchanged)

- [ ] **Given** the application starts, **When** dependencies are initialized, **Then** the image analysis use case no longer has cache service dependencies injected

### Edge Cases
- [ ] Handles scenario where Redis is unavailable without affecting image analysis (since it no longer uses Redis)
- [ ] Handles scenario where an old image cache key exists in Redis (should be ignored/expired naturally)

### Testing Requirements
- [ ] All existing tests for rules generation caching continue to pass
- [ ] Tests for image analysis no longer assert cache behavior
- [ ] Integration tests verify image analysis works without caching

### Logging Requirements
- [ ] **Given** an image analysis request is processed, **When** the LLM API is called, **Then** a log entry is created documenting the request (with appropriate metadata such as image size, model used)

## Affected Areas

**Components**:
- AnalyzeGameBoxUseCase - Contains image caching logic that must be removed
- CacheKeyGeneratorService - Includes image key generation methods to be removed
- AICacheType - Enum defining cache types (imageAnalysis case must be removed)
- CacheConfiguration - Contains imageAnalysisTTL configuration to be removed

**Files**:
- `Sources/App/Modules/RulesGeneration/UseCases/AnalyzeGameBoxUseCase.swift` - Remove cache lookup and storage calls, add logging
- `Sources/App/Services/KeyGeneration/CacheKeyGeneratorService.swift` - Remove image key generation methods entirely
- `Sources/App/Services/Cache/Models/AICacheType.swift` - Remove imageAnalysis enum case
- `Sources/App/Services/Cache/Models/CacheConfiguration.swift` - Remove imageAnalysisTTL property
- `Sources/App/Common/ServiceRegistry/Providers/CQRSServiceProvider.swift` - Adjust AnalyzeGameBoxUseCase dependency injection

**Related Systems**:
- Redis Infrastructure (RedisAICacheService, RedisCacheService) - Must remain functional for rules caching
- Rules Generation Feature - Must not be affected by this change
- LLM Service - Will receive increased call volume for image analysis

## Assumptions

> Document reasonable defaults and assumptions made during requirements gathering.

- The performance impact of removing image caching is acceptable (no cache = more LLM calls)
- Image analysis traffic volume is low enough that increased LLM API costs are acceptable
- Rules generation caching should remain active (this refactor is image-specific only)
- Existing cached image entries in Redis can expire naturally (no need for explicit cache flush)
- The cache infrastructure (services, interfaces, Redis connection) should remain intact for rules caching
- Image-specific cache code can be completely removed without backward compatibility concerns
- Logging added for LLM API calls will help monitor increased call volume

## Implementation Decisions

> Clarifications confirmed with user.

- **Complete Removal**: All image-specific cache code will be fully removed (no deprecation, no backward compatibility)
- **Enum Case**: AICacheType.imageAnalysis will be removed entirely
- **Key Generation**: Image cache key generation methods will be removed entirely
- **Logging**: Add logging to track LLM API calls for image analysis

---

**Next Steps**: Requirements are finalized. Ready to proceed to implementation planning.
