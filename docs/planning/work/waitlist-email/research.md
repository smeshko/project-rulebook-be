# Research: Waitlist Email Collection & Notification System

---
**Date:** 2025-12-03
**Requirements:** `docs/planning/work/waitlist-email/requirements.md`
**Exploration Cache:** Loaded from `.exploration-cache.json`
**Cache Age:** Same day
**Status:** complete
---

## Platform Detection

**Stack:** Swift 5.9+ / Vapor 4.110+
**Version:** macOS/Linux server deployment
**Build:** Swift Package Manager (SPM)

## Dependencies

| Dependency | Version | Purpose | Status |
|------------|---------|---------|--------|
| Vapor | 4.110+ | Web framework | existing |
| Fluent | 4.x | ORM for database models | existing |
| FluentPostgresDriver | 4.x | PostgreSQL support | existing |
| VaporToOpenAPI | 4.x | OpenAPI documentation | existing |
| Brevo API | v3 | Email sending service | existing |

## Codebase Patterns

### Architecture
- **Pattern:** Modular Architecture with Repository Pattern
  - Location: `Sources/App/Modules/User/UserModule.swift:1-16`
  - Usage: Each feature is a self-contained module with Model, Router, Controller, Repository

### Conventions
- **State:** Database via Fluent ORM - `Sources/App/Modules/User/Database/Models/UserAccountModel.swift`
- **Errors:** Vapor Abort errors - `Sources/App/Middlewares/EnsureAdminUserMiddleware.swift:8`
- **Async:** async/await throughout - `Sources/App/Modules/User/Controllers/UserController.swift`
- **Naming:** Files: PascalCase, Types: PascalCase, Funcs: camelCase

### Code Examples

**Module Structure Pattern:**
```swift
// Sources/App/Modules/User/UserModule.swift:1-16
struct UserModule: ModuleInterface {
    let router = UserRouter()

    func boot(_ app: Application) throws {
        app.migrations.add(UserMigrations.v1())
        if app.environment == .development {
            app.migrations.add(UserMigrations.seed())
        }
        try router.boot(routes: app.routes)
    }
}
```

**Fluent Model Pattern:**
```swift
// Sources/App/Modules/User/Database/Models/UserAccountModel.swift:1-66
final class UserAccountModel: @unchecked Sendable, DatabaseModelInterface, Authenticatable {
    typealias Module = UserModule
    static var schema: String { "users" }

    @ID() var id: UUID?
    @Field(key: FieldKeys.v1.email) var email: String
    @Timestamp(key: FieldKeys.v1.createdAt, on: .create) var createdAt: Date?
    // ... field keys pattern for versioned migrations
}

extension UserAccountModel {
    struct FieldKeys {
        struct v1 {
            static var email: FieldKey { "email" }
            // ...
        }
    }
}
```

**Migration Pattern:**
```swift
// Sources/App/Modules/User/Database/Migrations/UserMigrations.swift:4-29
enum UserMigrations {
    struct v1: AsyncMigration {
        func prepare(on db: Database) async throws {
            try await db.schema(UserAccountModel.schema)
                .id()
                .field(UserAccountModel.FieldKeys.v1.email, .string, .required)
                .unique(on: UserAccountModel.FieldKeys.v1.email)
                .create()
        }
        func revert(on db: Database) async throws {
            try await db.schema(UserAccountModel.schema).delete()
        }
    }
}
```

**Router Pattern with OpenAPI:**
```swift
// Sources/App/Modules/User/UserRouter.swift:1-57
struct UserRouter: RouteCollection {
    let userController = UserController()

    func boot(routes: RoutesBuilder) throws {
        user(routes: routes)
    }
}

private extension UserRouter {
    func user(routes: RoutesBuilder) {
        let api = routes
            .grouped("api")
            .grouped("user")
            .groupedOpenAPI(tags: .init(name: "User", description: "..."))

        // Public endpoints or protected endpoints with middleware
        let protectedAPI = api.grouped(UserAccountModel.guard())

        protectedAPI
            .grouped(EnsureAdminUserMiddleware())
            .get("list", use: userController.list)
            .openAPI(description: "...", response: .type([User.Detail.Response].self))
    }
}
```

**Repository Pattern:**
```swift
// Sources/App/Modules/User/Repositories/UserRepository.swift:1-50
protocol UserRepository: Repository {
    func find(id: UUID) async throws -> UserAccountModel?
    func find(email: String) async throws -> UserAccountModel?
    func create(_ model: UserAccountModel) async throws
    func all() async throws -> [UserAccountModel]
}

struct DatabaseUserRepository: UserRepository, DatabaseRepository {
    typealias Model = UserAccountModel
    let database: Database

    func find(email: String) async throws -> UserAccountModel? {
        try await UserAccountModel.query(on: database)
            .filter(\.$email == email)
            .first()
    }
}
```

**Email Sending Pattern:**
```swift
// Sources/App/Services/Email/Helpers/EmailVerifier.swift:1-35
struct EmailVerifier {
    let emailTokenRepository: any EmailTokenRepository
    let generator: RandomGeneratorService
    let application: Application

    func verify(for user: UserAccountModel) async throws {
        let token = generator.generate(bits: 256)
        let content = BrevoMail(
            sender: .init(name: "Sender", email: "noreply@sender.com"),
            to: [.init(name: name, email: user.email)],
            subject: "Verify your account",
            htmlContent: Templates.verifyEmail(token: emailToken.value, baseURL: ...)
        )
        try await application.serviceCache.emailService.send(content)
    }
}
```

**Email Template Pattern:**
```swift
// Sources/App/Services/Email/Helpers/Templates.swift:1-324
enum Templates {
    static func verifyEmail(token: String, baseURL: String) -> String {
        """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <!-- ... full HTML email template ... -->
        </head>
        <body>
            <a href="\(baseURL)/verify-email?token=\(token)">Verify email</a>
        </body>
        </html>
        """
    }
}
```

**Rate Limiting Pattern:**
```swift
// Sources/App/Middlewares/Security/RateLimit/RateLimitMiddleware.swift:167-211
private func determineRateLimit(for request: Request) -> RateLimitInfo {
    let path = request.url.path

    if path.contains("/api/rules-generation/game-box-analysis") {
        return RateLimitInfo(type: .imageAnalysis, maxRequests: ..., windowSeconds: ...)
    }
    if path.hasPrefix("/api/") {
        return RateLimitInfo(type: .api, maxRequests: ..., windowSeconds: ...)
    }
    return RateLimitInfo(type: .general, maxRequests: ..., windowSeconds: ...)
}
```

## Integration Points

| Component | Location | Change | Impact |
|-----------|----------|--------|--------|
| WaitlistModule | `Sources/App/Modules/Waitlist/` | create | New module |
| WaitlistModel | `Sources/App/Modules/Waitlist/Database/Models/` | create | New table |
| WaitlistMigrations | `Sources/App/Modules/Waitlist/Database/Migrations/` | create | Schema |
| WaitlistRepository | `Sources/App/Modules/Waitlist/Repositories/` | create | Data access |
| WaitlistRouter | `Sources/App/Modules/Waitlist/` | create | Endpoints |
| WaitlistController | `Sources/App/Modules/Waitlist/` | create | Business logic |
| Templates | `Sources/App/Services/Email/Helpers/Templates.swift` | modify | Add templates |
| Application-Setup | `Sources/App/Entrypoint/Application-Setup.swift:83-89` | modify | Register module |
| RateLimitTypes | `Sources/App/Middlewares/Security/RateLimit/RateLimitTypes.swift` | modify | Add waitlist type |
| RateLimitMiddleware | `Sources/App/Middlewares/Security/RateLimit/RateLimitMiddleware.swift` | modify | Add waitlist path |

**Flow:**
1. `POST /api/waitlist` → `RateLimitMiddleware` → `WaitlistRouter` → `WaitlistController.subscribe`
2. `WaitlistController` → `WaitlistRepository.findByEmail` (check duplicate)
3. `WaitlistRepository.create` → Database
4. `EmailService.send` → Brevo API → Confirmation email
5. `GET /api/waitlist/unsubscribe/:token` → `WaitlistController.unsubscribe` → Delete from DB
6. `POST /api/waitlist/notify` → `EnsureAdminUserMiddleware` → Bulk email send (admin only, same module)

## Clarifications & Decisions

### Rate Limiting for Waitlist
**Question:** How should rate limiting work for the waitlist endpoint?
**Finding:** Existing rate limit system uses path-based detection in `RateLimitMiddleware`
**Decision:** Add new `waitlist` rate limit type with moderate limits (e.g., 10 requests/hour per IP)
**Rationale:** Prevents spam while allowing legitimate signups; stricter than general API but not as strict as AI endpoints

### Database vs File Storage
**Question:** Where to store waitlist emails?
**Finding:** All other data uses Fluent/PostgreSQL; existing migration patterns well established
**Decision:** Use PostgreSQL via Fluent with dedicated `waitlist` table
**Rationale:** Consistency with existing patterns, better querying for bulk operations, transactional safety

### Unsubscribe Token Strategy
**Question:** How to implement secure unsubscribe?
**Finding:** Auth module uses SHA256-hashed tokens stored in DB (`EmailTokenModel` pattern)
**Decision:** Store unhashed unique token per waitlist entry, include in email URL
**Rationale:** Waitlist tokens don't need same security level as auth tokens; simpler implementation

## Risks & Unknowns

**Risks:**
1. **Email delivery failures** - Mitigation: Store email first, send async; log failures for retry
2. **Bulk notification performance** - Mitigation: Batch emails, use background job pattern
3. **Rate limit bypass via IP rotation** - Mitigation: Also validate email format, consider honeypot

**Unknowns:**
- [x] Rate limiting approach - Decided: Add waitlist-specific rate limit
- [x] Storage choice - Decided: PostgreSQL via Fluent
- [x] Unsubscribe mechanism - Decided: Token-based URL

## Summary

**Key Findings:**
1. Codebase has well-established module pattern (User, Auth, Rules modules) to follow exactly
2. Email service (Brevo) is fully operational with template system in place
3. Rate limiting middleware supports path-based operation types, easy to extend
4. Admin middleware (`EnsureAdminUserMiddleware`) provides simple admin-only protection

**Confidence:** High
- Clear patterns to follow
- All dependencies already in place
- No external service integration needed (Brevo already configured)

**Next Steps:**
1. Create plan.md with phased implementation
2. Generate tasks for each phase
3. Begin implementation starting with database model

---
**Ready for Planning:** Yes
