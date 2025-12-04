# Research: Architecture Simplification

---
**Date:** 2025-12-04
**Requirements:** `docs/planning/work/architecture-simplification/requirements.md`
**Exploration Cache:** Loaded from `.exploration-cache.json`
**Status:** complete
---

## Platform Detection

**Stack:** Swift/Vapor (Server-Side Swift)
**Version:** Swift 5.9+, Vapor 4.x
**Build:** Swift Package Manager (SPM)

## Dependencies

| Dependency | Version | Purpose | Status |
|------------|---------|---------|--------|
| Vapor | 4.x | Web framework | existing |
| Fluent | 4.x | ORM/Database | existing |
| JWT | - | Authentication | existing |
| NIO | - | Async runtime | existing |

## Codebase Patterns

### Architecture

- **Current Pattern:** Clean Architecture with Use Cases + ServiceRegistry DI
  - Location: `Sources/App/Common/ServiceRegistry/`
  - Usage: 17 use cases, 11 ServiceRegistry files, ~2,500 lines of DI infrastructure

- **Target Pattern:** Controller-based with simple property accessors
  - Example: `Sources/App/Modules/Frontend/Controllers/FrontendController.swift:5-34`
  - Usage: Direct `req.repositories.*` and `req.services.*` access

### Conventions

- **State:** Request-scoped services via ServiceRegistry → Target: `req.services.*`
- **Errors:** Vapor `Abort` with custom error types (`AuthenticationError`, `AIProcessingError`, `ContentError`)
- **Async:** Swift async/await throughout
- **Naming:** Files: PascalCase, Types: PascalCase, Funcs: camelCase

### Code Examples

**Current Pattern (Use Case with ServiceRegistry):**
```swift
// Sources/App/Modules/User/Controllers/UserController.swift:18-23
func getCurrentUser(_ req: Request) async throws -> User.Detail.Response {
    let user = try req.auth.require(UserAccountModel.self)
    let useCase = try await req.useCases.user.getCurrentUser  // Async resolution

    let request = GetCurrentUserUseCase.Request(user: user)
    return try await useCase.execute(request)
}
```

**Target Pattern (Direct Controller Logic):**
```swift
// Sources/App/Modules/Frontend/Controllers/FrontendController.swift:5-34
func verifyEmail(_ req: Request) async throws -> Response {
    let token = try req.query.get(String.self, at: "token")

    guard let token = try await req.repositories.emailTokens.find(token: token) else {
        return req.templates.renderHtml(OutcomeMessageTemplate(.init(
            text: "Token not found", title: "Token not found"
        )))
    }

    guard token.expiresAt > .now else {
        try await req.repositories.emailTokens.delete(id: token.requireID())
        return req.templates.renderHtml(OutcomeMessageTemplate(.init(
            text: "Token expired", title: "Token expired"
        )))
    }

    try await req.repositories.emailTokens.delete(id: token.requireID())
    token.user.isEmailVerified = true
    try await req.repositories.users.update(token.user)

    return req.templates.renderHtml(OutcomeMessageTemplate(.init(
        text: "Email successfully verified!", title: "Success"
    )))
}
```

## Integration Points

| Component | Location | Change | Impact |
|-----------|----------|--------|--------|
| Request+Services | New file | create | All controllers |
| Application+Services | New file | create | App startup |
| AuthController | `Modules/Auth/Controllers/` | modify | 5 use cases inline |
| UserController | `Modules/User/Controllers/` | modify | 4 use cases inline |
| CacheAdminController | `Modules/CacheAdmin/Controllers/` | modify | 6 use cases inline |
| RulesGenerationController | `Modules/RulesGeneration/Controllers/` | modify | 2 complex use cases |
| Application-Setup | `App/Application-Setup.swift` | modify | Replace setupServiceRegistry |
| TestWorld | `Tests/AppTests/Framework/` | modify | Property injection |

**Flow:** HTTP Request → Controller → Services/Repositories → Response

## Clarifications & Decisions

### 1. Service Resolution Pattern
**Question:** How to provide synchronous service access without async resolution?
**Finding:** Current ServiceCache already pre-resolves services at startup for sync access
**Decision:** Create simple struct accessors on Request that delegate to Application storage
**Rationale:** Eliminates async overhead, matches existing FrontendController pattern

### 2. Test Injection Mechanism
**Question:** How will tests inject mock services without ServiceRegistry?
**Finding:** IsolatedTestWorld currently registers mocks BEFORE configure(app) runs
**Decision:** Use settable properties on Application for service storage; tests set directly
**Rationale:** Simpler than factory registration, tests already configure pre-setup

### 3. Complex Use Case Migration
**Question:** How to handle GenerateRulesUseCase's 515 lines of orchestration logic?
**Finding:** Logic is sequential (validation → cache → DB → LLM → persist), no abstraction needed
**Decision:** Move entire execute() body to controller method, preserve all 9 steps exactly
**Rationale:** Complexity is inherent to the domain, not architecture - moving it doesn't add risk

### 4. Error Handling Preservation
**Question:** Will error handling change during migration?
**Finding:** Errors are thrown directly from use cases, controllers just propagate
**Decision:** Keep all error types and throw locations identical
**Rationale:** HTTP error mapping is handled by error middleware, not controllers

### 5. Database Constraint Detection
**Question:** SignUpUseCase has brittle string matching for duplicate email detection
**Finding:** Pattern matching for PostgreSQL (sqlState: 23505) and SQLite (UNIQUE constraint)
**Decision:** Preserve exact string patterns during migration
**Rationale:** Changing patterns would break duplicate detection - this is critical business logic

## Critical Business Logic to Preserve

### GenerateRulesUseCase (515 lines, HIGHEST RISK)
```
9-Step Orchestration:
1. Log request initiation (lines 136-143)
2. Basic input validation (lines 146-153)
3. Security: Sanitize game title (lines 155-170)
4. Redis cache lookup (lines 172-200)
5. Database fallback (lines 210-279)
6. LLM generation (lines 281-348)
7. Security: Validate AI response (lines 350-408)
8. Cache successful response (lines 362-367)
9. Persist to database with upsert (lines 432-513)
```

### AnalyzeGameBoxUseCase (287 lines)
```
Binary Image Format Detection (lines 156-194):
- JPEG: [0xFF, 0xD8, 0xFF]
- PNG: [0x89, 0x50, 0x4E, 0x47]
- GIF: [0x47, 0x49, 0x46]
- WebP: [0x52, 0x49, 0x46, 0x46] + bytes[8-11] == [0x57, 0x45, 0x42, 0x50]
```

### SignUpUseCase - Duplicate Email Detection (lines 88-101)
```swift
// PostgreSQL detection
let isPostgreSQLDuplicateEmail = errorString.contains("sqlState: 23505") &&
    (errorString.contains("uq:users.email") ||
     errorString.contains("Key (email)") ||
     errorString.contains("duplicate key") && errorString.contains("email"))

// SQLite detection
let isSQLiteDuplicateEmail = errorString.contains("UNIQUE constraint failed: users.email")
```

## Risks & Unknowns

**Risks:**
1. **RulesGeneration Complexity** - Mitigation: Line-by-line migration with identical logic
2. **Test Coverage Gaps** - Mitigation: Map each use case test to controller test before deletion
3. **Binary Format Detection** - Mitigation: Copy exact byte sequences, add tests
4. **Upsert Race Conditions** - Mitigation: Preserve create-with-fallback pattern exactly
5. **Prompt Injection Patterns** - Mitigation: Keep all 27+ validation patterns intact

**Unknowns:**
- [x] Target accessor API verified (FrontendController shows pattern)
- [x] Test injection approach confirmed (property assignment)
- [x] ServiceCache pattern understood (can be replaced with Application storage)

## Summary

**Key Findings:**
1. Target architecture already exists in FrontendController - verified working pattern
2. Business logic complexity is domain-inherent, not architecture-driven - safe to move
3. Test injection via pre-registration works - can simplify to property assignment
4. ServiceRegistry (2,500 lines) + Use Cases (17 files) = ~6,000+ lines removable

**Confidence:** High
- Clear path forward with proven pattern
- All critical logic documented with line numbers
- No external dependencies or API changes required

**Next Steps:**
1. Create Request+Services accessor infrastructure
2. Migrate Auth module (simplest, most tests)
3. Migrate User and CacheAdmin modules
4. Carefully migrate RulesGeneration (complex)
5. Delete infrastructure, verify build and tests

---
**Ready for Planning:** Yes
