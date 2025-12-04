## TASK-012: Migrate GenerateRulesUseCase (HIGHEST RISK)

---
**Status:** OPEN
**Branch:** refactoring/architecture-simplification
**Type:** REFACTOR
**Phase:** 4
**Depends On:** T011
---

### Overview

**HIGHEST RISK TASK** - Migrate GenerateRulesUseCase (515 lines) to RulesGenerationController. This use case has complex 9-step orchestration logic that must be preserved exactly.

**Files:**
- `Sources/App/Modules/RulesGeneration/Controllers/RulesGenerationController.swift` (modify)
- `Sources/App/Modules/RulesGeneration/UseCases/GenerateRulesUseCase.swift` (reference, delete later)

### Implementation Steps

**Commit 1: Copy GenerateRulesUseCase.execute() to controller**
- [ ] Copy entire execute() method body (lines 133-409)
- [ ] Copy makeRulesSummary() helper (lines 413-430)
- [ ] Copy persistGeneratedSummary() helper (lines 432-513)
- [ ] Update to use `req.services.*` and `req.repositories.*` syntax
- [ ] Preserve ALL 9 orchestration steps exactly
- [ ] Preserve ALL logging with metadata
- [ ] Preserve ALL validation patterns

### 9-Step Orchestration (MUST PRESERVE)

```
Step 1: Log request initiation (lines 136-143)
Step 2: Basic input validation (lines 146-153)
Step 3: Security: Sanitize game title (lines 155-170)
Step 4: Redis cache lookup (lines 172-200)
Step 5: Database fallback (lines 210-279)
Step 6: LLM generation (lines 281-348)
Step 7: Security: Validate AI response (lines 350-408)
Step 8: Cache successful response (lines 362-367)
Step 9: Persist to database with upsert (lines 432-513)
```

### Code Example

```swift
// After migration - key sections to preserve:

func generateRules(_ req: Request) async throws -> RulesGeneration.Response {
    let context = RequestContext(
        logger: req.logger,
        clientIP: req.services.ipExtractor.extract(from: req),
        requestID: req.services.uuidGenerator.generate(),
        timestamp: Date.now
    )

    // Step 1: Log request initiation
    context.logger.info(
        "AI rules generation request initiated",
        metadata: [
            "endpoint": "generateRulesSummary",
            "client_ip": .string(context.clientIP),
            "request_id": .string(context.requestID),
            "timestamp": .string(ISO8601DateFormatter().string(from: context.timestamp)),
        ])

    let request = try req.content.decode(RulesGeneration.Request.self)

    // Step 2: Basic input validation
    guard !request.gameTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        throw Abort(.badRequest, reason: "Game title cannot be empty")
    }
    guard request.gameTitle.count <= 200 else {
        throw Abort(.badRequest, reason: "Game title too long (max 200 characters)")
    }

    // Step 3: CRITICAL SECURITY - Sanitize game title
    let sanitizedGameTitle: String
    do {
        sanitizedGameTitle = try req.services.aiInputValidator.validateAndSanitizeGameTitle(request.gameTitle)
    } catch let processingError as AIProcessingError {
        context.logger.warning(
            "Game title processing failed",
            metadata: [
                "error": .string(processingError.description),
                "raw_title": .string(request.gameTitle),
                "client_ip": .string(context.clientIP),
                "request_id": .string(context.requestID),
            ])
        throw processingError
    }

    // Step 4: Check Redis cache
    let cacheKey = req.services.cacheKeyGenerator.generateRulesKey(for: sanitizedGameTitle)
    var wasCached = false

    if let cachedResponse = await req.services.aiCache.get(key: cacheKey) {
        context.logger.info("Cache hit for rules generation", metadata: [...])
        let cachedBuffer = ByteBuffer(string: cachedResponse)
        let rulesSummary = try JSONDecoder().decode(RulesSummary.Response.self, from: cachedBuffer)
        wasCached = true
        return Response(rulesSummary: rulesSummary, processedGameTitle: rulesSummary.title, generatedAt: Date.now, wasCached: wasCached)
    }

    // Step 5: Database fallback
    if let storedRule = try await req.repositories.generatedRules.find(bySanitizedTitle: sanitizedGameTitle) {
        // ... restore from DB, refresh cache, update lastAccessedAt
    }

    // Step 6: LLM generation
    let systemPrompt = """..."""
    let rulesResponse = try await req.services.llm.generate(input: combinedPrompt)

    // Step 7: CRITICAL SECURITY - Validate AI response
    let validatedResponse = try req.services.aiResponseValidator.validateRulesSummaryResponse(...)

    // Step 8: Cache successful response
    await req.services.aiCache.set(key: cacheKey, value: validatedResponse, ttl: cacheConfiguration.rulesGenerationTTL)

    // Step 9: Persist to database with upsert
    await persistGeneratedSummary(...)

    return Response(...)
}

// Upsert pattern (lines 432-513) - MUST PRESERVE
private func persistGeneratedSummary(...) async {
    do {
        try await req.repositories.generatedRules.create(model)
    } catch {
        // Fallback to update on duplicate
        if let existing = try await req.repositories.generatedRules.find(bySanitizedTitle: sanitizedTitle) {
            existing.originalTitle = originalTitle
            // ... update all fields
            try await req.repositories.generatedRules.update(existing)
        }
    }
}
```

### Critical Logic to Preserve

1. **Input Validation** - Title cannot be empty, max 200 chars
2. **Prompt Injection Detection** - 27+ patterns in aiInputValidator
3. **3-Tier Cache Strategy** - Redis → DB → LLM
4. **Response Validation** - AI output must be valid JSON
5. **Upsert Pattern** - Create with fallback to update
6. **Logging** - All metadata must be preserved
7. **Error Handling** - Each step has specific error handling

### Success Criteria

- [ ] Build succeeds
- [ ] Rules generation returns identical responses
- [ ] Cache lookup works (Redis first)
- [ ] Database fallback works
- [ ] LLM generation works when cache misses
- [ ] Prompt injection is detected
- [ ] Response validation catches invalid JSON
- [ ] Upsert pattern works correctly
- [ ] All logging preserved
- [ ] All rules generation tests pass

### Verification

```bash
swift build
swift test --filter RulesGeneration
```

### Notes

- **DO NOT REFACTOR** - copy logic exactly as-is
- Test after each step if possible
- This is the highest-risk task in the entire migration
- If tests fail, compare line-by-line with original use case
