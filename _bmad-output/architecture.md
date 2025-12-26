---
stepsCompleted: [1, 2, 3, 4, 5, 6, 7, 8]
status: 'complete'
completedAt: '2025-12-25'
inputDocuments:
  - path: '_bmad-output/prd.md'
    type: 'prd'
    description: 'Backend PRD for project-rulebook-be'
workflowType: 'architecture'
lastStep: 6
project_name: 'project-rulebook-be'
user_name: 'Ivo'
date: '2025-12-25'
---

# Architecture Decision Document

_This document builds collaboratively through step-by-step discovery. Sections are appended as we work through each architectural decision together._

## Project Context Analysis

### Requirements Overview

**Functional Requirements:**
- 27 total requirements across 6 categories
- 22 implemented (Core API, Caching, Rate Limiting, AI Providers, Security)
- 5 future (User Accounts, Cloud Sync, Receipt Validation, Feedback, Analytics)
- Core value: Transform game box photos into structured, playable rules

**Non-Functional Requirements:**
- Reliability: 99.5% uptime, graceful degradation with AI provider fallback
- Scalability: 100 concurrent requests, stateless design for horizontal scaling
- Security: HTTPS-only, input validation, prompt injection prevention
- Observability: Structured logging, correlation IDs, health checks
- Caching: Cached responses should be fast (<100ms); AI responses are best-effort

**Scale & Complexity:**
- Primary domain: API Backend
- Complexity level: Low-Medium
- Estimated architectural components: 6 modules, 10 services, 2 external AI integrations

### Technical Constraints & Dependencies

| Constraint | Impact |
|------------|--------|
| **AI Provider Latency** | Response times depend on external LLM APIs; unpredictable and uncontrollable |
| **Cost Management** | AI calls are expensive; rate limiting and caching reduce costs |
| **Stateless Requirement** | No session state; all state in Redis/PostgreSQL |
| **Existing Codebase** | Brownfield project; must respect existing patterns and conventions |
| **Swift/Vapor Stack** | Technology locked; optimize within this ecosystem |

### Cross-Cutting Concerns Identified

| Concern | Affected Components |
|---------|---------------------|
| **Caching Strategy** | All AI endpoints, rules storage, rate limit counters |
| **Error Handling** | AI failures, network timeouts, validation errors |
| **Rate Limiting** | All public endpoints, per-IP tracking |
| **Observability** | Request tracing, performance metrics, error logging |
| **Input Validation** | All endpoints, prompt sanitization for AI |

## Technology Foundation (Brownfield)

### Established Stack

This is an existing production system. All new development must work within these constraints:

| Layer | Technology | Version |
|-------|------------|---------|
| Language | Swift | 6.0 |
| Framework | Vapor | 4.110+ |
| Database | PostgreSQL | (Railway managed) |
| Cache | Redis | (Railway managed) |
| Auth | JWT | vapor/jwt 4.x |
| Deployment | Railway | Linux containers |

### Architectural Patterns in Use

**Module Structure:**
- Feature modules in `Sources/App/Modules/`
- Each module owns: Router, Controller, Models, Repository
- Cross-cutting services in `Sources/App/Services/`

**Service Architecture:**
- Protocol-first design (`LLMService` protocol, `OpenAIService` + `GeminiService` implementations)
- Application-level service registration
- Request-scoped access via `req.services`

**Middleware Chain:**
- `SecurityHeadersMiddleware` → `RateLimitMiddleware` → `CorrelationIDMiddleware` → `ErrorMiddleware`

**Configuration:**
- `ConfigurationService` with environment-specific implementations
- `DevelopmentConfiguration`, `ProductionConfiguration`, `TestingConfiguration`

### Extension Principles

When adding new functionality:
1. Create new module in `Modules/` for feature-scoped work
2. Add shared services to `Services/` for cross-cutting concerns
3. Follow existing patterns — don't introduce new architectural concepts
4. Respect the modular monolith boundary — no microservices

## Core Architectural Decisions

### Decision Summary

| Decision | Choice | Rationale |
|----------|--------|-----------|
| **API Versioning** | URL prefix (`/v1/`) | Mobile apps can pin to specific version; explicit and debuggable |
| **Receipt Validation** | Server-side | Essential for credit system integrity; prevents fraud |

### API Versioning Strategy

**Decision:** URL prefix versioning (`/api/v1/...`)

**Implementation:**
- Current endpoints move under `/api/v1/rules-generation/`
- New endpoints added to `/v1/` namespace
- Breaking changes require `/v2/` namespace
- Deprecation: 6-month notice before removing old versions

**Migration Path:**
1. Add `/v1/` prefix to router groups
2. Maintain backward compatibility at root for transition period
3. Mobile apps update to use `/v1/` endpoints
4. Deprecate root endpoints after mobile apps updated

**Code Pattern:**
```swift
// RulesGenerationRouter.swift
let api = routes
    .grouped("api")
    .grouped("v1")  // Version prefix
    .grouped("rules-generation")
```

### Receipt Validation Strategy

**Decision:** Server-side validation for App Store and Play Store receipts

**Implementation:**
- New module: `Modules/Receipts/`
- Validates receipts against Apple/Google servers
- Links validated purchases to credit system
- Stores transaction records for audit

**Components:**

| Component | Purpose |
|-----------|---------|
| `ReceiptsModule` | Module registration |
| `ReceiptsRouter` | `/api/v1/receipts/validate` endpoint |
| `ReceiptsController` | Validation orchestration |
| `AppStoreValidationService` | Apple receipt verification |
| `PlayStoreValidationService` | Google receipt verification |
| `ReceiptRepository` | Transaction record storage |

**Validation Flow:**
1. Mobile app sends receipt data after successful purchase
2. Backend validates with Apple/Google servers
3. On success: add credits, store transaction
4. Return updated credit balance to app

**Security Considerations:**
- Never trust client-reported credit amounts
- Log all validation attempts (success and failure)
- Idempotent by transaction ID (prevent duplicate credit grants)

### Deferred Decisions

| Decision | Status | Rationale |
|----------|--------|-----------|
| Subscription Model | Deferred | Credit-based model is working |

### Out of Scope

| Decision | Rationale |
|----------|-----------|
| User Accounts | Not needed for core functionality; app works without accounts |
| Cloud Library Sync | Removed; local-only game library is sufficient |

## Implementation Patterns & Consistency Rules

### Naming Conventions

| Area | Convention | Example |
|------|------------|---------|
| Database tables | snake_case, plural | `waitlist_entries` |
| Database columns | snake_case | `created_at` |
| API endpoints | kebab-case | `/rules-generation/` |
| Swift types | PascalCase | `RulesGenerationController` |
| Swift properties | camelCase | `guessedTitle` |
| Swift files | PascalCase | `OpenAIService.swift` |
| Protocols | PascalCase + descriptive suffix | `AICacheServiceInterface` |

### Module Structure Pattern

Every new module follows this structure:
```
Modules/{ModuleName}/
├── {ModuleName}Module.swift      # Module registration
├── {ModuleName}Router.swift      # Route definitions
├── Controller/
│   └── {ModuleName}Controller.swift
├── Models/
│   └── {ModuleName}+Model.swift  # Request/Response types
├── Database/
│   ├── Models/                   # Fluent models
│   └── Migrations/               # Database migrations
└── Repositories/
    └── {ModuleName}Repository.swift
```

### Service Structure Pattern

Services follow protocol-first design:
```
Services/{ServiceArea}/
├── {ServiceName}Service.swift    # Protocol definition
├── {Implementation}Service.swift  # Concrete implementation
└── Models/                       # Service-specific types
```

### Error Handling Pattern

All errors conform to `AppError` enum:
```swift
enum SomeError: AppError {
    case invalidInput(String)
    case notFound

    var status: HTTPResponseStatus { ... }
    var reason: String { ... }
    var identifier: String { ... }
}
```

### API Response Patterns

**Success responses:** Direct JSON body
```json
{"title": "Wingspan", "confidence": 94}
```

**Error responses:** Vapor abort format
```json
{"error": true, "reason": "Invalid image format"}
```

### Enforcement: AI Agent Rules

When implementing new features, AI agents MUST:
1. Follow existing naming conventions exactly
2. Create new modules using the established structure
3. Use protocol-first design for new services
4. Conform errors to `AppError` pattern
5. Use `async/await` for all asynchronous operations
6. Register services at application level, access via `req.services`

## Project Structure & Boundaries

### Complete Project Directory Structure

```
project-rulebook-be/
├── Package.swift
├── README.md
├── .gitignore
├── .env.example
├── docker-compose.yml
│
├── Sources/
│   └── App/
│       ├── Entrypoint/
│       │   ├── entrypoint.swift
│       │   ├── configure.swift
│       │   └── Application-Setup.swift
│       │
│       ├── Common/
│       │   ├── Errors/
│       │   │   └── AppError.swift
│       │   ├── Extensions/
│       │   ├── Framework/
│       │   │   ├── Repository.swift
│       │   │   ├── ModuleInterface.swift
│       │   │   └── DatabaseModelInterface.swift
│       │   ├── Middleware/
│       │   │   ├── ErrorMiddleware.swift
│       │   │   └── CorrelationIDMiddleware.swift
│       │   └── Validation/
│       │       └── ValidationRule.swift
│       │
│       ├── Middlewares/
│       │   ├── Security/
│       │   │   ├── SecurityHeadersMiddleware.swift
│       │   │   └── RateLimit/
│       │   │       ├── RateLimitMiddleware.swift
│       │   │       ├── RateLimitConfiguration.swift
│       │   │       ├── RateLimitStorage.swift
│       │   │       └── RateLimitTypes.swift
│       │   ├── UserPayloadAuthenticator.swift
│       │   └── UserCredentialsAuthenticator.swift
│       │
│       ├── Modules/
│       │   ├── Auth/                      # Authentication
│       │   ├── CacheAdmin/                # Cache management
│       │   ├── Frontend/                  # HTML templates
│       │   ├── RulesGeneration/           # Core AI pipeline
│       │   │   ├── RulesGenerationModule.swift
│       │   │   ├── RulesGenerationRouter.swift
│       │   │   ├── Controller/
│       │   │   ├── Models/
│       │   │   ├── Database/
│       │   │   └── Repositories/
│       │   ├── User/                      # User management
│       │   ├── Waitlist/                  # Email collection
│       │   │
│       │   └── Receipts/                  # [NEW] Receipt validation
│       │       ├── ReceiptsModule.swift
│       │       ├── ReceiptsRouter.swift
│       │       ├── Controller/
│       │       │   └── ReceiptsController.swift
│       │       ├── Models/
│       │       │   └── Receipts+Model.swift
│       │       ├── Database/
│       │       │   ├── Models/
│       │       │   │   └── TransactionModel.swift
│       │       │   └── Migrations/
│       │       │       └── ReceiptsMigrations.swift
│       │       └── Repositories/
│       │           └── ReceiptsRepository.swift
│       │
│       ├── Services/
│       │   ├── Cache/
│       │   │   ├── AICacheServiceInterface.swift
│       │   │   ├── RedisAICacheService.swift
│       │   │   └── Models/
│       │   ├── Configuration/
│       │   │   ├── ConfigurationService.swift
│       │   │   ├── DevelopmentConfiguration.swift
│       │   │   ├── ProductionConfiguration.swift
│       │   │   └── TestingConfiguration.swift
│       │   ├── Email/
│       │   │   ├── EmailService.swift
│       │   │   └── BrevoClient.swift
│       │   ├── LLM/
│       │   │   ├── LLMService.swift
│       │   │   ├── OpenAIService.swift
│       │   │   ├── GoogleGeminiService.swift
│       │   │   └── Models/
│       │   ├── Validation/
│       │   │   ├── AIInputValidatorService.swift
│       │   │   ├── AIResponseValidationService.swift
│       │   │   └── PromptSanitizerService.swift
│       │   │
│       │   └── Receipts/                  # [NEW] Receipt services
│       │       ├── AppStoreValidationService.swift
│       │       └── PlayStoreValidationService.swift
│       │
│       └── Extensions/
│
├── Tests/
│   └── AppTests/
│       ├── Modules/
│       │   ├── RulesGeneration/
│       │   └── Receipts/                  # [NEW]
│       └── Services/
│
└── _bmad-output/                          # Planning artifacts
    ├── prd.md
    └── architecture.md
```

### Architectural Boundaries

**API Boundaries:**

| Boundary | Scope |
|----------|-------|
| `/api/v1/rules-generation/` | AI-powered game recognition and rules |
| `/api/v1/receipts/` | [NEW] Purchase validation |
| `/api/waitlist/` | Email collection (public) |
| `/admin/` | Protected admin endpoints |

**Service Boundaries:**

| Service Layer | Responsibility |
|---------------|----------------|
| Controllers | Request handling, validation, response formatting |
| Services | Business logic, external API integration |
| Repositories | Data access, database operations |

**Data Boundaries:**

| Store | Data Type |
|-------|-----------|
| PostgreSQL | User data, transactions, generated rules |
| Redis | Rate limit counters, AI response cache |

### Requirements to Structure Mapping

**Current Features:**

| Feature | Module | Services |
|---------|--------|----------|
| Game Box Analysis | `RulesGeneration/` | `LLMService`, `CacheService` |
| Rules Generation | `RulesGeneration/` | `LLMService`, `CacheService` |
| Rate Limiting | `Middlewares/Security/RateLimit/` | Redis |
| Waitlist | `Waitlist/` | `EmailService` |

**Planned Features:**

| Feature | Module | Services |
|---------|--------|----------|
| Receipt Validation | `Receipts/` | `AppStoreValidationService`, `PlayStoreValidationService` |
| API Versioning | Router updates | N/A (routing only) |

### Integration Points

**External Integrations:**

| Service | Purpose | Location |
|---------|---------|----------|
| OpenAI API | Game recognition, rules generation | `Services/LLM/OpenAIService.swift` |
| Google Gemini | Fallback AI provider | `Services/LLM/GoogleGeminiService.swift` |
| App Store Server API | [NEW] Receipt validation | `Services/Receipts/AppStoreValidationService.swift` |
| Google Play Developer API | [NEW] Receipt validation | `Services/Receipts/PlayStoreValidationService.swift` |
| Brevo | Email delivery | `Services/Email/BrevoClient.swift` |
| Railway | PostgreSQL, Redis hosting | Environment config |

**Internal Data Flow:**

```
Request → Middleware Chain → Router → Controller → Service → Repository → Database
                                                  ↓
                                           External APIs (AI/Receipts)
                                                  ↓
                                              Response
```

## Architecture Validation Results

### Coherence Validation

**Decision Compatibility:** All technology choices (Swift 6.0, Vapor 4.110+, PostgreSQL, Redis, JWT) are compatible and work together. No version conflicts detected.

**Pattern Consistency:** Implementation patterns align with Swift/Vapor conventions. Naming follows established codebase standards.

**Structure Alignment:** Project structure supports all architectural decisions. Boundaries are clear and consistent with existing code.

### Requirements Coverage

| Category | Requirements | Status |
|----------|--------------|--------|
| Core API | FR1-7 | ✅ Implemented |
| Caching | FR8-11 | ✅ Implemented |
| Rate Limiting | FR12-14 | ✅ Implemented |
| AI Providers | FR15-18 | ✅ Implemented |
| Security | FR19-22 | ✅ Implemented |
| Receipt Validation | FR23 | ✅ Architected |
| Feedback API | FR24 | 📋 Planned |
| Usage Analytics | FR25 | 📋 Planned |

### Implementation Readiness

**Decision Completeness:** ✅ All critical decisions documented with technology versions

**Structure Completeness:** ✅ Project structure fully mapped with new components marked

**Pattern Completeness:** ✅ Naming, module, service, and error patterns specified

### Architecture Readiness Assessment

**Overall Status:** READY FOR IMPLEMENTATION

**Confidence Level:** High

**Key Strengths:**
- Brownfield project with proven patterns
- Clear extension principles for new features
- Protocol-first service design enables testability
- Modular structure isolates changes

**First Implementation Priority:**
1. API versioning migration (`/api/v1/` prefix)
2. Receipt validation module (`Modules/Receipts/`)

---

## Architecture Completion Summary

### Workflow Completion

| Item | Status |
|------|--------|
| **Architecture Decision Workflow** | COMPLETED ✅ |
| **Total Steps Completed** | 8 |
| **Date Completed** | 2025-12-25 |
| **Document Location** | `_bmad-output/architecture.md` |

### Final Architecture Deliverables

**Complete Architecture Document:**
- All architectural decisions documented with specific versions
- Implementation patterns ensuring AI agent consistency
- Complete project structure with all files and directories
- Requirements to architecture mapping
- Validation confirming coherence and completeness

**Implementation Ready Foundation:**
- 2 new architectural decisions (API versioning, receipt validation)
- 6 implementation patterns defined (naming, module, service, error, response, enforcement)
- 7 modules specified (6 existing + 1 new)
- 27 requirements supported

### Implementation Handoff

**For AI Agents:**
This architecture document is your complete guide for implementing project-rulebook-be. Follow all decisions, patterns, and structures exactly as documented.

**Development Sequence:**
1. Add `/v1/` prefix to existing routers
2. Create `Receipts` module following module structure pattern
3. Implement `AppStoreValidationService` and `PlayStoreValidationService`
4. Add database migrations for transaction storage
5. Connect to mobile app purchase flows
6. Implement Feedback API for user rule corrections
7. Add anonymous usage analytics collection

---

**Architecture Status:** READY FOR IMPLEMENTATION ✅

*Architecture Decision Document - project-rulebook-be*
*Completed: 2025-12-25*
