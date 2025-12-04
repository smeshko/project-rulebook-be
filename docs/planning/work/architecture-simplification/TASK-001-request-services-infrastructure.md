## TASK-001: Create Request+Services Infrastructure

---
**Status:** COMPLETE
**Branch:** refactoring/architecture-simplification
**Type:** IMPLEMENTATION
**Phase:** 0
**Depends On:** None
---

### Overview

Create the foundational infrastructure for the new accessor pattern. This establishes `req.services.*` and `req.repositories.*` syntax that will replace the ServiceRegistry pattern.

**Files:**
- `Sources/App/Common/Extensions/Application+Services.swift` (create)
- `Sources/App/Common/Extensions/Request+Services.swift` (create)

### Implementation Steps

**Commit 1: Create service/repository accessor infrastructure**
- [x] Create `Application+Services.swift` with storage keys for all services
- [x] Create `Request+Services.swift` with Services and Repositories structs
- [x] Add settable properties on Application for each service (for test injection)
- [x] Add read-only accessors on Request that delegate to Application

### Code Example

```swift
// Target pattern from FrontendController.swift:8
// req.repositories.emailTokens.find(token: token)

// Application+Services.swift
extension Application {
    private struct LLMServiceKey: StorageKey {
        typealias Value = LLMService
    }

    var llmService: LLMService {
        get { storage[LLMServiceKey.self]! }
        set { storage[LLMServiceKey.self] = newValue }
    }

    // Similar for all services and repositories...
}

// Request+Services.swift
extension Request {
    var services: Services { Services(app: application) }
    var repositories: Repositories { Repositories(app: application) }
}

struct Services {
    let app: Application
    var llm: LLMService { app.llmService }
    var email: EmailService { app.emailService }
    var cache: AICacheServiceInterface { app.aiCacheService }
    var aiCache: AICacheServiceInterface { app.aiCacheService }
    var ipExtractor: IPExtractorService { app.ipExtractorService }
    var aiInputValidator: AIInputValidatorServiceInterface { app.aiInputValidatorService }
    var promptSanitizer: PromptSanitizerServiceInterface { app.promptSanitizerService }
    var cacheKeyGenerator: CacheKeyGeneratorServiceInterface { app.cacheKeyGeneratorService }
    var randomGenerator: RandomGeneratorService { app.randomGeneratorService }
    var uuidGenerator: UUIDGeneratorService { app.uuidGeneratorService }
}

struct Repositories {
    let app: Application
    var users: any UserRepository { app.userRepository }
    var refreshTokens: any RefreshTokenRepository { app.refreshTokenRepository }
    var emailTokens: any EmailTokenRepository { app.emailTokenRepository }
    var passwordTokens: any PasswordTokenRepository { app.passwordTokenRepository }
    var generatedRules: any GeneratedRuleRepository { app.generatedRuleRepository }
    var waitlist: any WaitlistRepository { app.waitlistRepository }
}
```

### Services to Include

**Services (10):**
- llm: LLMService
- email: EmailService
- cache/aiCache: AICacheServiceInterface
- ipExtractor: IPExtractorService
- aiInputValidator: AIInputValidatorServiceInterface
- promptSanitizer: PromptSanitizerServiceInterface
- cacheKeyGenerator: CacheKeyGeneratorServiceInterface
- randomGenerator: RandomGeneratorService
- uuidGenerator: UUIDGeneratorService
- aiResponseValidator: AIResponseValidationService

**Repositories (6):**
- users: UserRepository
- refreshTokens: RefreshTokenRepository
- emailTokens: EmailTokenRepository
- passwordTokens: PasswordTokenRepository
- generatedRules: GeneratedRuleRepository
- waitlist: WaitlistRepository

### Success Criteria

- [x] Build succeeds with new files
- [x] `req.services.llm` syntax compiles
- [x] `req.repositories.users` syntax compiles (existing pattern preserved)
- [x] Properties are settable for test injection

### Verification

```bash
swift build
```

### Notes

- Storage keys use Vapor's built-in StorageKey pattern
- Properties on Application are settable to allow test injection
- Request accessors are read-only (delegate to Application)
- This task creates infrastructure only - no existing code changes yet
