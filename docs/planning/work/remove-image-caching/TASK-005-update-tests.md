## TASK-005: Update Tests for Cache Removal

---
**Status:** OPEN
**Branch:** refactoring/remove-image-caching
**Type:** REFACTOR
**Phase:** 1
**Depends On:** TASK-001, TASK-003, TASK-004

---

### Overview

Update AnalyzeGameBoxUseCaseTests to remove assertions about wasCached field and cache behavior. Verify that the tests still validate the core functionality of image analysis.

This task ensures tests accurately reflect the simplified implementation without caching.

### Files Modified

- `Tests/AppTests/UseCases/RulesGeneration/AnalyzeGameBoxUseCaseTests.swift`

### Implementation Steps

- [ ] Review testResponseStructure test (lines 38-70)
- [ ] Remove wasCached assertions from testResponseStructure (lines 62, 65-69)
- [ ] Update test to only verify gameboxRecognition and analyzedAt fields
- [ ] Review other tests for any cache-related assertions
- [ ] Run full test suite to identify any other failures
- [ ] Fix any additional test failures related to removed cache functionality

### Code Example

**Current testResponseStructure (lines 38-70):**
```swift
@Test("AnalyzeGameBoxUseCase Response has correct structure")
func testResponseStructure() async throws {
    // Arrange
    let gameboxRecognition = GameboxRecognition.Response(
        guessedTitle: "Wingspan",
        confidence: 94,
        alternativeTitles: ["Wingspan: European Expansion"],
        keywordsDetected: ["bird", "engine", "building", "strategy"],
        notes: "Clear game box with excellent visibility"
    )

    // Act
    let response = AnalyzeGameBoxUseCase.Response(
        gameboxRecognition: gameboxRecognition,
        analyzedAt: Date(),
        wasCached: false
    )

    // Assert
    #expect(response.gameboxRecognition.guessedTitle == "Wingspan")
    #expect(response.gameboxRecognition.confidence == 94)
    #expect(response.gameboxRecognition.alternativeTitles.count == 1)
    #expect(response.gameboxRecognition.keywordsDetected.count == 4)
    #expect(response.analyzedAt <= Date())
    #expect(response.wasCached == false)

    // Test cached response
    let cachedResponse = AnalyzeGameBoxUseCase.Response(
        gameboxRecognition: gameboxRecognition,
        wasCached: true
    )
    #expect(cachedResponse.wasCached == true)
}
```

**After removal:**
```swift
@Test("AnalyzeGameBoxUseCase Response has correct structure")
func testResponseStructure() async throws {
    // Arrange
    let gameboxRecognition = GameboxRecognition.Response(
        guessedTitle: "Wingspan",
        confidence: 94,
        alternativeTitles: ["Wingspan: European Expansion"],
        keywordsDetected: ["bird", "engine", "building", "strategy"],
        notes: "Clear game box with excellent visibility"
    )

    // Act
    let response = AnalyzeGameBoxUseCase.Response(
        gameboxRecognition: gameboxRecognition,
        analyzedAt: Date()
    )

    // Assert
    #expect(response.gameboxRecognition.guessedTitle == "Wingspan")
    #expect(response.gameboxRecognition.confidence == 94)
    #expect(response.gameboxRecognition.alternativeTitles.count == 1)
    #expect(response.gameboxRecognition.keywordsDetected.count == 4)
    #expect(response.analyzedAt <= Date())
}
```

**Reference: Other tests should remain unchanged (lines 224-256):**
```swift
@Test("AnalyzeGameBoxUseCase maintains query idempotency characteristics")
func testQueryIdempotency() async throws {
    // Query use cases should be idempotent - same input produces same output
    // This is important for caching and performance optimization

    let imageData1 = "consistent-image-data".data(using: .utf8)!
    let imageData2 = "consistent-image-data".data(using: .utf8)!

    let context = RequestContext(
        clientIP: "127.0.0.1",
        logger: Logger(label: "idempotency-test")
    )

    let request1 = AnalyzeGameBoxUseCase.Request(
        imageData: imageData1,
        context: context
    )

    let request2 = AnalyzeGameBoxUseCase.Request(
        imageData: imageData2,
        context: context
    )

    // Same image data should produce identical requests
    #expect(request1.imageData == request2.imageData)
    #expect(request1.context.clientIP == request2.context.clientIP)
}
```

### Success Criteria

- [ ] All tests pass
- [ ] No test assertions on wasCached field
- [ ] testResponseStructure validates core response structure
- [ ] testQueryIdempotency remains unchanged (structural test)
- [ ] No compiler warnings in test files

### Verification Commands

```bash
swift test --filter AnalyzeGameBoxUseCaseTests
swift test  # Run full test suite
```

### Notes

This task depends on TASK-001 (Response struct changes), TASK-003 (removed types), and TASK-004 (removed methods) to be completed first. The tests validate structure and contracts, not implementation details, so most tests should require minimal changes.
