---
type: refactor
status: draft
slug: architecture-simplification
feature_branch: refactoring/architecture-simplification
---

# Architecture Simplification: Remove Use Cases & Service Infrastructure

## Overview

### Context
The current codebase has accumulated architectural complexity that adds overhead without proportional benefit:
- **Use Case Layer**: 17 use case files that mostly wrap simple repository calls
- **ServiceRegistry**: ~2,500 lines of DI infrastructure (ServiceContainer, ServiceCache, Providers)
- **Multiple Access Patterns**: 5+ different ways to access services (`req.useCases.auth.signUp`, `req.services.ipExtractor`, `app.serviceCache.llmService`, `req.resolveService(T.self)`)
- **Test Overhead**: Duplicate test coverage (use case tests + controller tests)

### Objective
Simplify to a single, consistent pattern:
- `req.services.llm` for services
- `req.repositories.users` for repositories
- Business logic lives directly in controllers
- One test approach: integration tests via HTTP

### Impact
- **Developer Experience**: One pattern to learn, consistent across codebase
- **Maintainability**: Less indirection, easier to trace code flow
- **Code Reduction**: ~9,900 lines removed
- **Test Clarity**: Single source of truth for test coverage

---

## Requirements

### R1: Remove All Use Cases
All 17 use case files must be deleted, with their business logic moved to the corresponding controllers.

**Acceptance Criteria:**
- No files remain in any `UseCases/` directory
- All business logic preserved in controllers
- No change in API behavior or responses

### R2: Remove ServiceRegistry Infrastructure
The entire ServiceRegistry system must be replaced with simple property-based access.

**Acceptance Criteria:**
- All 11 ServiceRegistry files deleted
- All 3 Architecture infrastructure files deleted
- Services accessible via `req.services.*`
- Repositories accessible via `req.repositories.*`
- Test injection works via property setters

### R3: Create Simple Accessor Pattern
New accessor infrastructure must provide clean, consistent access to services and repositories.

**Target API:**
```swift
// Services
req.services.llm
req.services.email
req.services.cache
req.services.aiCache
req.services.ipExtractor
req.services.aiInputValidator
req.services.promptSanitizer
req.services.cacheKeyGenerator
req.services.randomGenerator
req.services.uuidGenerator

// Repositories
req.repositories.users
req.repositories.refreshTokens
req.repositories.emailTokens
req.repositories.passwordTokens
req.repositories.generatedRules
req.repositories.waitlist
```

**Acceptance Criteria:**
- All services accessible via `req.services.*`
- All repositories accessible via `req.repositories.*`
- Properties are settable for test injection
- No async resolution required

### R4: Migrate All Test Coverage
Every test scenario from use case tests must be migrated to controller integration tests.

**Acceptance Criteria:**
- All use case test files deleted (12 files)
- Each test scenario exists in corresponding controller test
- No reduction in test coverage
- All tests pass

### R5: Preserve Complex Business Logic
The RulesGeneration module contains significant business logic that must be carefully preserved.

**Critical Logic to Preserve:**
- `GenerateRulesUseCase`: Input validation, cache lookup, DB fallback, LLM invocation, response validation, persistence
- `AnalyzeGameBoxUseCase`: Image format detection (magic bytes), AI input validation, LLM vision, response validation

**Acceptance Criteria:**
- All validation logic preserved
- Cache/DB fallback behavior unchanged
- Error handling maintained
- Logging preserved

---

## Affected Areas

### Files to Delete (44 files)

| Category | Count | Location |
|----------|-------|----------|
| Use Cases | 17 | `Sources/App/Modules/*/UseCases/` |
| ServiceRegistry | 11 | `Sources/App/Common/ServiceRegistry/` |
| Architecture | 3 | `Sources/App/Common/Architecture/` |
| Use Case Tests | 12 | `Tests/AppTests/UseCases/` |
| ServiceRegistry Tests | 1 | `Tests/AppTests/ServiceRegistry/` |

### Files to Create (2 files)

| File | Purpose |
|------|---------|
| `Request+Services.swift` | `req.services.*` and `req.repositories.*` accessors |
| `Application+Services.swift` | Service storage and initialization |

### Files to Modify

| File | Changes |
|------|---------|
| `AuthController.swift` | Add logic from 5 use cases |
| `UserController.swift` | Add logic from 4 use cases |
| `CacheAdminController.swift` | Add logic from 6 use cases |
| `RulesGenerationController.swift` | Add logic from 2 use cases (complex) |
| `Application-Setup.swift` | Replace `setupServiceRegistry()` with simple init |
| `TestWorld.swift` | Use direct property injection |
| `IsolatedTestWorld.swift` | Use direct property injection |
| Controller test files | Add migrated test scenarios |

---

## Out of Scope

- Changes to API contracts or endpoints
- Database schema changes
- New features or functionality
- Performance optimizations (beyond code reduction)

---

## Assumptions

1. **Test injection via properties is sufficient** - No need for protocol-based DI
2. **Integration tests provide adequate coverage** - Unit tests for use cases can be replaced by HTTP tests
3. **Controllers can handle increased complexity** - Business logic in controllers is acceptable for this codebase size
4. **Phased migration is safe** - Build verification after each phase catches issues early

---

## Implementation Phases

### Phase 1: Infrastructure Foundation
Create new accessor pattern and verify it works alongside existing system.

### Phase 2: Auth Module Migration
Migrate all 5 auth use cases to AuthController with tests.

### Phase 3: User Module Migration
Migrate all 4 user use cases to UserController with tests.

### Phase 4: CacheAdmin Module Migration
Migrate all 6 cache admin use cases to CacheAdminController with tests.

### Phase 5: RulesGeneration Module Migration (Highest Risk)
Carefully migrate complex AI logic to RulesGenerationController with comprehensive tests.

### Phase 6: Cleanup
Delete all old infrastructure, update test framework, final verification.

---

## Success Criteria

- [ ] All use cases deleted (17 files)
- [ ] All ServiceRegistry infrastructure deleted (11 files)
- [ ] All Architecture infrastructure deleted (3 files)
- [ ] New accessor pattern works: `req.services.llm`, `req.repositories.users`
- [ ] All business logic preserved in controllers
- [ ] All test scenarios migrated to controller tests
- [ ] Build passes with no warnings
- [ ] All tests pass
- [ ] Net code reduction: ~6,000+ lines

---

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| RulesGeneration complexity | HIGH | Careful line-by-line migration, preserve all validation logic |
| Test coverage gaps | MEDIUM | Map each use case test to controller test before deletion |
| Service injection in tests | MEDIUM | Verify TestWorld works with new pattern before full migration |
| Breaking changes | HIGH | Phase-by-phase approach, build verification after each phase |
