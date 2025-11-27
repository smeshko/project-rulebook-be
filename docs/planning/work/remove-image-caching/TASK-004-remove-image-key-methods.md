## TASK-004: Remove Image Cache Key Generation Methods

---
**Status:** OPEN
**Branch:** refactoring/remove-image-caching
**Type:** REFACTOR
**Phase:** 1
**Depends On:** TASK-002

---

### Overview

Remove generateImageKey() and generateBoxPhotoKey() methods from CacheKeyGeneratorService. Update helper methods to only recognize and validate "rules" prefix.

This task eliminates dead code for image key generation, making the service rules-focused only.

### Files Modified

- `Sources/App/Services/KeyGeneration/CacheKeyGeneratorService.swift`

### Implementation Steps

- [ ] Remove generateImageKey() method (lines 67-77)
- [ ] Remove generateBoxPhotoKey() method (lines 79-92)
- [ ] Update protocol interface to remove these two methods (lines 16-19)
- [ ] Update isValidCacheKey() to only accept "rules" prefix (line 104, remove "image" and "box")
- [ ] Update extractCacheType() to only handle "rules" prefix (lines 119-126, remove image/box cases)
- [ ] Update describeKey() to only describe rules keys (lines 139-148, remove image/box cases)
- [ ] Update header comment to clarify rules-only focus

### Code Example

**Current protocol interface (CacheKeyGeneratorService.swift:8-29):**
```swift
protocol CacheKeyGeneratorServiceInterface: Sendable {
    func `for`(_ request: Request) -> CacheKeyGeneratorServiceInterface

    func generateRulesKey(for gameTitle: String) -> String

    func generateImageKey(for imageData: Data) -> String

    func generateBoxPhotoKey(for imageData: Data, context: String) -> String

    func isValidCacheKey(_ key: String) -> Bool

    func extractCacheType(from key: String) -> AICacheType?

    func describeKey(_ key: String) -> String
}
```

**After removal:**
```swift
protocol CacheKeyGeneratorServiceInterface: Sendable {
    func `for`(_ request: Request) -> CacheKeyGeneratorServiceInterface

    func generateRulesKey(for gameTitle: String) -> String

    func isValidCacheKey(_ key: String) -> Bool

    func extractCacheType(from key: String) -> AICacheType?

    func describeKey(_ key: String) -> String
}
```

**Current isValidCacheKey (line 95-112):**
```swift
func isValidCacheKey(_ key: String) -> Bool {
    let components = key.split(separator: "_")
    guard components.count == 2 else { return false }

    let prefix = String(components[0])
    let hash = String(components[1])

    // Validate prefix
    let validPrefixes = ["rules", "image", "box"]
    guard validPrefixes.contains(prefix) else { return false }

    // Validate hash (32 hex characters)
    guard hash.count == 32 else { return false }
    guard hash.allSatisfy({ $0.isHexDigit }) else { return false }

    return true
}
```

**After removal:**
```swift
func isValidCacheKey(_ key: String) -> Bool {
    let components = key.split(separator: "_")
    guard components.count == 2 else { return false }

    let prefix = String(components[0])
    let hash = String(components[1])

    // Validate prefix
    guard prefix == "rules" else { return false }

    // Validate hash (32 hex characters)
    guard hash.count == 32 else { return false }
    guard hash.allSatisfy({ $0.isHexDigit }) else { return false }

    return true
}
```

**Current extractCacheType (lines 114-127):**
```swift
func extractCacheType(from key: String) -> AICacheType? {
    guard isValidCacheKey(key) else { return nil }

    let prefix = String(key.split(separator: "_").first ?? "")
    switch prefix {
    case "rules":
        return .rulesGeneration
    case "image", "box":
        return .imageAnalysis
    default:
        return nil
    }
}
```

**After removal:**
```swift
func extractCacheType(from key: String) -> AICacheType? {
    guard isValidCacheKey(key) else { return nil }
    return .rulesGeneration
}
```

### Success Criteria

- [ ] Build succeeds without errors
- [ ] CacheKeyGeneratorService only contains rules-related methods
- [ ] Protocol interface updated to remove image methods
- [ ] isValidCacheKey() only validates "rules" prefix
- [ ] extractCacheType() only returns rulesGeneration
- [ ] describeKey() only describes rules keys
- [ ] No dead code remains
- [ ] No compiler warnings introduced

### Verification Commands

```bash
swift build
# Search for any remaining image key references
grep -r "generateImageKey\|generateBoxPhotoKey" Sources/
```

### Notes

This task depends on TASK-002 to ensure AnalyzeGameBoxUseCase no longer calls these methods before we remove them. This task can be done in parallel with TASK-003 since they modify different files.
