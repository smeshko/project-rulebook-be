## TASK-002: Update AnalyzeGameBoxUseCase Dependency Injection

---
**Status:** COMPLETE
**Branch:** refactoring/remove-image-caching
**Type:** REFACTOR
**Phase:** 1
**Depends On:** TASK-001

---

### Overview

Remove cache-related dependencies (cacheKeyGenerator, aiCache, cacheConfiguration) from AnalyzeGameBoxUseCase initializer and update the service registration in CQRSServiceProvider.

This task completes the removal of cache dependencies from the use case, simplifying its initialization.

### Files Modified

- `Sources/App/Modules/RulesGeneration/UseCases/AnalyzeGameBoxUseCase.swift`
- `Sources/App/Common/ServiceRegistry/Providers/CQRSServiceProvider.swift`

### Implementation Steps

- [x] Remove cacheKeyGenerator property from AnalyzeGameBoxUseCase (line 67)
- [x] Remove aiCache property from AnalyzeGameBoxUseCase (line 69)
- [x] Remove cacheConfiguration property from AnalyzeGameBoxUseCase (line 75)
- [x] Update init() to remove these three parameters (lines 79-92)
- [x] Update CQRSServiceProvider registration to remove cache dependencies (lines 259-268)
- [x] Ensure only aiInputValidator, llmService, and aiResponseValidator remain

### Code Example

**Current dependency injection (CQRSServiceProvider.swift:259-268):**
```swift
registry.register(AnalyzeGameBoxUseCase.self) { app in
    AnalyzeGameBoxUseCase(
        aiInputValidator: try await app.serviceRegistry.resolveRequired(AIInputValidatorServiceInterface.self),
        cacheKeyGenerator: try await app.serviceRegistry.resolveRequired(CacheKeyGeneratorServiceInterface.self),
        aiCache: try await app.serviceRegistry.resolveRequired(AICacheServiceInterface.self),
        llmService: try await app.serviceRegistry.resolveRequired(LLMService.self),
        aiResponseValidator: try await app.serviceRegistry.resolveRequired(AIResponseValidationService.self),
        cacheConfiguration: try app.configuration.cache
    )
}
```

**After removal:**
```swift
registry.register(AnalyzeGameBoxUseCase.self) { app in
    AnalyzeGameBoxUseCase(
        aiInputValidator: try await app.serviceRegistry.resolveRequired(AIInputValidatorServiceInterface.self),
        llmService: try await app.serviceRegistry.resolveRequired(LLMService.self),
        aiResponseValidator: try await app.serviceRegistry.resolveRequired(AIResponseValidationService.self)
    )
}
```

**Reference: Simpler use case registration (CQRSServiceProvider.swift:206-208):**
```swift
registry.register(GetCurrentUserUseCase.self) { app in
    GetCurrentUserUseCase()
}
```

### Success Criteria

- [x] Build succeeds without errors (pre-existing unrelated error in Application-Setup.swift)
- [x] AnalyzeGameBoxUseCase initializer only has 3 dependencies
- [x] CQRSServiceProvider correctly registers AnalyzeGameBoxUseCase
- [x] No references to cache services in use case
- [x] No compiler warnings introduced

### Verification Commands

```bash
swift build
swift test --filter AnalyzeGameBoxUseCaseTests
```

### Notes

This task depends on TASK-001 because the use case logic must no longer reference cache services before we can remove them from the initializer.
