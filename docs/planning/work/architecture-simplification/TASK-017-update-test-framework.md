## TASK-017: Update Test Framework for Property Injection

---
**Status:** OPEN
**Branch:** refactoring/architecture-simplification
**Type:** REFACTOR
**Phase:** 5
**Depends On:** T015, T016
---

### Overview

Update IsolatedTestWorld and TestWorld to use direct property injection instead of ServiceRegistry.

**Files:**
- `Tests/AppTests/Framework/IsolatedTestWorld.swift` (modify)
- `Tests/AppTests/Framework/TestWorld.swift` (modify)

### Implementation Steps

**Commit 1: Update test framework for direct property injection**
- [ ] Remove ServiceRegistry registration calls
- [ ] Use direct property assignment on Application
- [ ] Update configureForTesting() to set properties directly
- [ ] Remove any `serviceRegistry.register()` calls
- [ ] Verify all tests pass

### Code Changes

```swift
// BEFORE (IsolatedTestWorld.swift)
private func configureForTesting() async throws {
    app.serviceRegistry.register((any UserRepository).self) { _ in self.userRepository }
    app.serviceRegistry.register((any RefreshTokenRepository).self) { _ in self.tokenRepository }
    app.serviceRegistry.register(EmailService.self) { _ in FakeEmailProvider() }
    app.serviceRegistry.register(LLMService.self) { _ in self.fakeLLMService }
    // ...
    try await app.setupServiceRegistry()
}

// AFTER
private func configureForTesting() async throws {
    // Direct property injection
    app.userRepository = userRepository
    app.refreshTokenRepository = tokenRepository
    app.emailTokenRepository = emailTokenRepository
    app.passwordTokenRepository = passwordTokenRepository
    app.generatedRuleRepository = generatedRuleRepository

    app.emailService = FakeEmailProvider()
    app.llmService = fakeLLMService
    app.aiCacheService = mockAICacheService
    app.cacheService = InMemoryTestCacheService()
    app.randomGeneratorService = RiggedRandomGeneratorService(value: "test_random_value")
    app.uuidGeneratorService = constantUUIDGenerator

    // Configure other app settings
    try app.jwt.signers.use(.es256(key: .generate()))
    try app.initializeConfiguration()
    // No more setupServiceRegistry() call
    try app.setupJWT()
    try app.setupMiddleware()
    try app.setupModules()
}
```

### Test Framework Updates

**IsolatedTestWorld:**
- Remove all `app.serviceRegistry.register()` calls
- Replace with `app.{service} = mock` assignments
- Remove `try await app.setupServiceRegistry()` call

**TestWorld (if still used):**
- Same changes as IsolatedTestWorld
- Or mark as deprecated if moving to IsolatedTestWorld only

### Success Criteria

- [ ] Build succeeds
- [ ] All tests pass
- [ ] No references to `serviceRegistry` in test code
- [ ] Test injection still works (mocks are used)
- [ ] Tests are isolated (no shared state issues)

### Verification

```bash
swift build
swift test
grep -r "serviceRegistry" Tests/
```

### Notes

- Property injection is simpler than factory registration
- Order of assignment doesn't matter (no dependencies)
- Settable properties allow test injection
- This is the last step before Phase 6 verification
