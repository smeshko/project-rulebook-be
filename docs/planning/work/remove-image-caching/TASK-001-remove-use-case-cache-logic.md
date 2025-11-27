## TASK-001: Remove Cache Logic from AnalyzeGameBoxUseCase

---
**Status:** COMPLETE
**Branch:** refactoring/remove-image-caching
**Type:** REFACTOR
**Phase:** 1
**Depends On:** None

---

### Overview

Remove all caching logic from AnalyzeGameBoxUseCase including cache lookup, cache storage, and the wasCached field from the Response struct. Add structured logging when LLM API is invoked.

This task simplifies the use case by removing the cache layer entirely, following the "elegant simplicity" principle documented in the use case itself.

### Files Modified

- `Sources/App/Modules/RulesGeneration/UseCases/AnalyzeGameBoxUseCase.swift`

### Implementation Steps

- [x] Remove `wasCached` property from Response struct (line 49)
- [x] Remove `wasCached` parameter from Response init (lines 50-59)
- [x] Remove cache lookup block (lines 140-162)
- [x] Remove cache storage call in `validateAndCacheResponse` method (lines 336-340)
- [x] Rename `validateAndCacheResponse` to `validateResponse` and remove caching logic
- [x] Add structured logging before LLM API call with image metadata (size, model)
- [x] Update execute() method to call renamed validation method
- [x] Update header comment to reflect removed caching (line 15)

### Code Example

**Current cache lookup (lines 140-162):**
```swift
// 2. Check cache for existing results
let cacheKey = cacheKeyGenerator.generateBoxPhotoKey(for: request.imageData, context: "box")
var wasCached = false

if let cachedResponse = await aiCache.get(key: cacheKey) {
    request.context.logger.info("Cache hit for game identification", metadata: [
        "cache_key": .string(cacheKey),
        "client_ip": .string(request.context.clientIP),
        "request_id": .string(request.context.requestID)
    ])

    let cachedBuffer = ByteBuffer(string: cachedResponse)
    let gameboxRecognition = try JSONDecoder().decode(GameboxRecognition.Response.self, from: cachedBuffer)
    wasCached = true

    let response = Response(
        gameboxRecognition: gameboxRecognition,
        analyzedAt: Date.now,
        wasCached: wasCached
    )

    return response
}
```

**After removal - add logging before LLM call:**
```swift
// 2. Log LLM API invocation
context.logger.info("Invoking LLM for image analysis", metadata: [
    "image_size": .string("\(request.imageData.count) bytes"),
    "client_ip": .string(context.clientIP),
    "request_id": .string(context.requestID)
])

// 3. Generate AI analysis
let aiResponse = try await performAIAnalysis(dataURL: dataURL, context: request.context)
```

**Reference: GenerateRulesUseCase logging pattern (line 378):**
```swift
context.logger.info(
    "AI rules generation completed successfully",
    metadata: [
        "game_title": .string(sanitizedGameTitle),
        "confidence": .string("\(rulesSummary.confidence)"),
        "cached": .string("true"),
        "cache_key": .string(cacheKey),
        "client_ip": .string(context.clientIP),
        "request_id": .string(context.requestID),
    ])
```

### Success Criteria

- [x] Build succeeds without errors (will fully succeed after TASK-002)
- [x] AnalyzeGameBoxUseCase no longer references cache services in execute() method
- [x] Response struct no longer has wasCached field
- [x] Logging captures LLM invocations with metadata
- [x] No new compiler warnings introduced (unused dependencies expected until TASK-002)

### Verification Commands

```bash
swift build
swift test --filter AnalyzeGameBoxUseCaseTests
```

### Notes

This task removes cache logic but does NOT remove cache dependencies from the initializer yet. That will be done in TASK-002 after updating the dependency injection registration.
