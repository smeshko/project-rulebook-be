---
project_name: 'project-rulebook-be'
user_name: 'Ivo'
date: '2025-12-25'
sections_completed: ['technology_stack', 'implementation_rules', 'patterns', 'testing', 'anti_patterns']
---

# Project Context for AI Agents

_Critical rules and patterns for implementing code in project-rulebook-be. Read this before writing any code._

---

## Technology Stack & Versions

| Component | Version | Notes |
|-----------|---------|-------|
| Swift | 6.0 | Strict concurrency enabled |
| Vapor | 4.110+ | Async/await throughout |
| Fluent | 4.8+ | PostgreSQL in prod, SQLite in dev |
| PostgreSQL | Railway managed | Via `DATABASE_URL` |
| Redis | Railway managed | Via `REDIS_URL` |
| JWT | vapor/jwt 4.x | For authentication |

---

## Critical Implementation Rules

### Swift 6 Concurrency

- **ALWAYS** use `async/await` — no completion handlers
- **ALWAYS** mark actors and sendable types correctly
- **NEVER** use `DispatchQueue` for async work — use structured concurrency
- Services accessed via `req` are already on correct isolation

### Vapor Request Handling

```swift
// CORRECT: Async route handler
func handler(req: Request) async throws -> Response {
    let result = try await someService.doWork()
    return .init(status: .ok)
}

// WRONG: Blocking or callback-based
func handler(req: Request) throws -> EventLoopFuture<Response> { ... }
```

### Module Boundaries

- Each module owns its Router, Controller, Models, Repository
- **NEVER** import one module's internal types into another
- Cross-module communication through Services only
- Controllers call Services, Services call Repositories

### Service Registration

```swift
// Register at app level in Application-Setup.swift
app.services.register(MyServiceProtocol.self) { app in
    RealMyService(app: app)
}

// Access in request handlers
let service = req.services.get(MyServiceProtocol.self)
```

### Error Handling

```swift
// ALWAYS conform errors to AppError
enum MyError: AppError {
    case invalidInput(String)
    case notFound

    var status: HTTPResponseStatus {
        switch self {
        case .invalidInput: return .badRequest
        case .notFound: return .notFound
        }
    }

    var reason: String {
        switch self {
        case .invalidInput(let msg): return msg
        case .notFound: return "Resource not found"
        }
    }

    var identifier: String {
        switch self {
        case .invalidInput: return "invalid_input"
        case .notFound: return "not_found"
        }
    }
}

// WRONG: Throwing raw errors
throw Abort(.badRequest) // Don't do this directly
```

---

## Naming Conventions

| Area | Convention | Example |
|------|------------|---------|
| Database tables | snake_case, plural | `waitlist_entries` |
| Database columns | snake_case | `created_at`, `user_id` |
| API endpoints | kebab-case with `/v1/` prefix | `/api/v1/rules-generation/game-box-analysis` |
| Swift types | PascalCase | `RulesGenerationController` |
| Swift properties | camelCase | `guessedTitle`, `createdAt` |
| Swift files | PascalCase matching type | `OpenAIService.swift` |
| Protocols | PascalCase + suffix | `AICacheServiceInterface` |
| Modules | PascalCase | `RulesGeneration/` |

---

## Module Structure (MUST FOLLOW)

```
Modules/{ModuleName}/
├── {ModuleName}Module.swift      # Module registration
├── {ModuleName}Router.swift      # Route definitions
├── Controller/
│   └── {ModuleName}Controller.swift
├── Models/
│   └── {ModuleName}+Model.swift  # Request/Response Codable types
├── Database/
│   ├── Models/                   # Fluent @Model classes
│   └── Migrations/               # Migration definitions
└── Repositories/
    └── {ModuleName}Repository.swift
```

---

## Service Structure (MUST FOLLOW)

```
Services/{ServiceArea}/
├── {Name}Service.swift           # Protocol definition
├── Real{Name}Service.swift       # Production implementation
├── Mock{Name}Service.swift       # Test implementation (in Tests/)
└── Models/                       # Service-specific types
```

**Protocol-first design:**
```swift
// Protocol in Services/
protocol LLMService: Sendable {
    func generateRules(for game: String) async throws -> RulesSummary
}

// Implementation in Services/
struct OpenAIService: LLMService {
    func generateRules(for game: String) async throws -> RulesSummary { ... }
}
```

---

## API Response Patterns

**Success:** Return the response type directly (Vapor encodes to JSON)
```swift
func handler(req: Request) async throws -> GameboxRecognition.Response {
    return .init(guessedTitle: "Wingspan", confidence: 94)
}
```

**Errors:** Throw `AppError` conforming types — middleware formats response
```json
{"error": true, "reason": "Invalid image format"}
```

---

## Testing Requirements

- Tests in `Tests/AppTests/` mirroring source structure
- Use `@testable import App`
- Use `Application.make(.testing)` for app instance
- Mock services via protocol injection
- **ALWAYS** test error cases, not just happy paths

```swift
@Test
func testInvalidInput() async throws {
    let app = try await Application.make(.testing)
    defer { await app.asyncShutdown() }

    try await app.test(.POST, "/api/rules-generation/rules-summary") { req in
        req.headers.contentType = .json
        try req.content.encode(["gameTitle": ""])
    } afterResponse: { res async throws in
        #expect(res.status == .badRequest)
    }
}
```

---

## Anti-Patterns (NEVER DO THESE)

| Anti-Pattern | Why It's Wrong | Do Instead |
|--------------|----------------|------------|
| `DispatchQueue.global().async` | Breaks structured concurrency | Use `async/await` |
| `try! force unwrap` | Crashes in production | Handle errors properly |
| Importing module internals | Breaks encapsulation | Use public APIs only |
| Raw `Abort()` throws | Inconsistent error format | Use `AppError` enum |
| Inline SQL queries | SQL injection risk | Use Fluent query builder |
| Hardcoded secrets | Security vulnerability | Use environment variables |
| Synchronous blocking calls | Blocks event loop | Use async alternatives |
| Creating new patterns | Inconsistency | Follow existing patterns |

---

## Environment Variables

| Variable | Purpose | Required |
|----------|---------|----------|
| `DATABASE_URL` | PostgreSQL connection | Prod only |
| `REDIS_URL` | Redis connection | Prod only |
| `OPENAI_API_KEY` | OpenAI API | Yes |
| `GEMINI_API_KEY` | Google Gemini API | Yes |
| `JWT_SECRET` | JWT signing | Yes |
| `BREVO_API_KEY` | Email service | Optional |

---

## Quick Reference

**Adding a new endpoint:**
1. Add route in `{Module}Router.swift`
2. Implement in `{Module}Controller.swift`
3. Define request/response in `Models/`
4. Add tests in `Tests/AppTests/`

**Adding a new service:**
1. Define protocol in `Services/{Area}/`
2. Implement in same directory
3. Register in `Application-Setup.swift`
4. Access via `req.services.get()`

**Adding a new module:**
1. Create directory structure per pattern above
2. Register in `Application-Setup.swift`
3. Add routes via module's router

---

*Project Context - project-rulebook-be*
*Generated: 2025-12-25*
