## TASK-002: Initialize Services in Application Setup

---
**Status:** COMPLETE
**Branch:** refactoring/architecture-simplification
**Type:** IMPLEMENTATION
**Phase:** 0
**Depends On:** T001
---

### Overview

Update Application-Setup.swift to initialize all services using the new accessor pattern. Services will be stored directly on Application storage instead of going through ServiceRegistry.

**Files:**
- `Sources/App/Application-Setup.swift` (modify)

### Implementation Steps

**Commit 1: Add service initialization to setupServices()**
- [x] Add initialization code for all services after current setupServiceRegistry() call
- [x] Initialize repositories with database connection
- [x] Initialize external services (LLM, Email, Cache)
- [x] Initialize domain services (validators, generators)
- [x] Both patterns will coexist temporarily during migration

### Code Example

```swift
// Add to Application-Setup.swift after existing setupServiceRegistry()

// Initialize repositories
self.userRepository = DatabaseUserRepository(database: db)
self.refreshTokenRepository = DatabaseRefreshTokenRepository(database: db)
self.emailTokenRepository = DatabaseEmailTokenRepository(database: db)
self.passwordTokenRepository = DatabasePasswordTokenRepository(database: db)
self.generatedRuleRepository = DatabaseGeneratedRuleRepository(database: db)
self.waitlistRepository = DatabaseWaitlistRepository(database: db)

// Initialize external services
self.llmService = GoogleGeminiService(app: self)
self.emailService = BrevoEmailService(app: self)
self.cacheService = RedisCacheService(app: self)
self.aiCacheService = RedisAICacheService(
    cacheService: self.cacheService,
    keyGenerator: self.cacheKeyGeneratorService,
    logger: self.logger
)

// Initialize domain services
self.randomGeneratorService = RealRandomGeneratorService(app: self)
self.uuidGeneratorService = RealUUIDGeneratorService(app: self)
self.ipExtractorService = DefaultIPExtractorService(app: self)
self.promptSanitizerService = PromptSanitizerService()
self.aiInputValidatorService = AIInputValidatorService(
    promptSanitizer: self.promptSanitizerService
)
self.cacheKeyGeneratorService = CacheKeyGeneratorService()
self.aiResponseValidatorService = AIResponseValidationService()
```

### Success Criteria

- [x] Build succeeds
- [x] All tests pass (existing ServiceRegistry still works)
- [x] Services accessible via both old and new patterns
- [x] Application starts successfully

### Verification

```bash
swift build
swift test
```

### Notes

- Both patterns will coexist during migration
- Old ServiceRegistry calls continue to work
- New `req.services.*` calls now also work
- Order of initialization matters for dependencies
