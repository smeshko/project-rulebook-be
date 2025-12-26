## TASK-014: Delete RulesGeneration Use Cases

---
**Status:** OPEN
**Branch:** refactoring/architecture-simplification
**Type:** REFACTOR
**Phase:** 4
**Depends On:** T012, T013
---

### Overview

Delete RulesGeneration use case files after comprehensive test verification.

**Files:**
- `Sources/App/Modules/RulesGeneration/UseCases/GenerateRulesUseCase.swift` (delete)
- `Sources/App/Modules/RulesGeneration/UseCases/AnalyzeGameBoxUseCase.swift` (delete)
- `Sources/App/Modules/RulesGeneration/UseCases/` (delete directory)
- `Tests/AppTests/UseCases/RulesGeneration/` (delete directory)

### Implementation Steps

**Commit 1: Delete RulesGeneration use cases after verification**
- [ ] Run full test suite - all must pass
- [ ] Verify rules generation endpoint manually if possible
- [ ] Verify game box analysis endpoint manually if possible
- [ ] Delete GenerateRulesUseCase.swift
- [ ] Delete AnalyzeGameBoxUseCase.swift
- [ ] Delete UseCases directory
- [ ] Remove use case imports from any files
- [ ] Update UseCaseAccessors.swift to remove rules generation use cases
- [ ] Delete rules generation use case test files
- [ ] Verify build and tests still pass

### Test Scenarios to Verify

**GenerateRules:**
- [ ] Empty title returns error
- [ ] Title too long returns error
- [ ] Prompt injection patterns detected
- [ ] Cache hit returns cached response
- [ ] Database hit returns stored response
- [ ] LLM generates new response on miss
- [ ] Invalid JSON response is rejected
- [ ] Successful response is cached
- [ ] Successful response is persisted

**AnalyzeGameBox:**
- [ ] Empty image returns error
- [ ] JPEG format detected (0xFF 0xD8 0xFF)
- [ ] PNG format detected (0x89 0x50 0x4E 0x47)
- [ ] GIF format detected (0x47 0x49 0x46)
- [ ] WebP format detected (RIFF + WEBP marker)
- [ ] Invalid format throws error
- [ ] LLM returns game identification
- [ ] Confidence score is present

### Success Criteria

- [ ] Build succeeds with no rules generation use case files
- [ ] All tests pass
- [ ] No orphaned imports or references
- [ ] RulesGeneration/UseCases/ directory doesn't exist

### Verification

```bash
swift build
swift test --filter RulesGeneration
swift test --filter GameBox
ls Sources/App/Modules/RulesGeneration/UseCases/ # Should fail
```

### Notes

- This is the most critical deletion - verify thoroughly
- Consider testing manually before deleting
- If any doubt, keep files and investigate
