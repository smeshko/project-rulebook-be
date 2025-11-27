## TASK-003: Remove Image Cache Configuration Types

---
**Status:** COMPLETE
**Branch:** refactoring/remove-image-caching
**Type:** REFACTOR
**Phase:** 1
**Depends On:** TASK-002

---

### Overview

Remove imageAnalysis enum case from AICacheType and imageAnalysisTTL property from CacheConfiguration. Update related methods to only handle rules generation caching.

This task eliminates image-specific cache configuration, making the types rules-focused only.

### Files Modified

- `Sources/App/Services/Cache/Models/AICacheType.swift`
- `Sources/App/Services/Cache/Models/CacheConfiguration.swift`

### Implementation Steps

- [x] Remove `imageAnalysis` case from AICacheType enum (line 6)
- [x] Update getTTL() method to only handle rulesGeneration case (remove imageAnalysis switch case)
- [x] Update description property to only handle rulesGeneration case
- [x] Remove `imageAnalysisTTL` property from CacheConfiguration struct (line 12)
- [x] Update development static configuration (remove imageAnalysisTTL, line 24)
- [x] Update production static configuration (remove imageAnalysisTTL, line 33)
- [x] Update testing static configuration (remove imageAnalysisTTL, line 42)
- [x] Remove `imageAnalysisTTL` property from CacheConfig in ConfigurationTypes.swift
- [x] Update DevelopmentConfiguration.swift cache config
- [x] Update ProductionConfiguration.swift cache config and validation
- [x] Update TestingConfiguration.swift cache config

### Code Example

**Current AICacheType enum (AICacheType.swift:4-29):**
```swift
public enum AICacheType: String, CaseIterable, Sendable {
    case rulesGeneration = "rules_generation"
    case imageAnalysis = "image_analysis"

    func getTTL(from config: CacheConfiguration) -> TimeInterval {
        switch self {
        case .rulesGeneration:
            return config.rulesGenerationTTL
        case .imageAnalysis:
            return config.imageAnalysisTTL
        }
    }

    var description: String {
        switch self {
        case .rulesGeneration:
            return "Rules Generation"
        case .imageAnalysis:
            return "Image Analysis"
        }
    }
}
```

**After removal:**
```swift
public enum AICacheType: String, CaseIterable, Sendable {
    case rulesGeneration = "rules_generation"

    func getTTL(from config: CacheConfiguration) -> TimeInterval {
        return config.rulesGenerationTTL
    }

    var description: String {
        return "Rules Generation"
    }
}
```

**Current CacheConfiguration (CacheConfiguration.swift:1-46):**
```swift
struct CacheConfiguration: Sendable {
    let maxEntries: Int
    let rulesGenerationTTL: TimeInterval
    let imageAnalysisTTL: TimeInterval
    let cleanupInterval: TimeInterval
    let enableLogging: Bool

    static let development = CacheConfiguration(
        maxEntries: 500,
        rulesGenerationTTL: 3600,
        imageAnalysisTTL: 1800,
        cleanupInterval: 300,
        enableLogging: true
    )
}
```

**After removal:**
```swift
struct CacheConfiguration: Sendable {
    let maxEntries: Int
    let rulesGenerationTTL: TimeInterval
    let cleanupInterval: TimeInterval
    let enableLogging: Bool

    static let development = CacheConfiguration(
        maxEntries: 500,
        rulesGenerationTTL: 3600,
        cleanupInterval: 300,
        enableLogging: true
    )
}
```

### Success Criteria

- [x] Build succeeds without errors (only CacheKeyGeneratorService error expected, fixed in TASK-004)
- [x] AICacheType enum only contains rulesGeneration case
- [x] CacheConfiguration only contains rulesGenerationTTL
- [x] All static configurations updated (development, production, testing)
- [x] No references to imageAnalysisTTL remain
- [x] No compiler warnings introduced

### Verification Commands

```bash
swift build
# Search for any remaining references
grep -r "imageAnalysis" Sources/
grep -r "imageAnalysisTTL" Sources/
```

### Notes

This task depends on TASK-002 to ensure no code references imageAnalysis type before we remove it.
