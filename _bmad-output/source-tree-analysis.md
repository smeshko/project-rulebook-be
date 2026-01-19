# Source Tree Analysis - project-rulebook-be

**Generated:** 2026-01-19
**Project Type:** Swift/Vapor Backend (Modular Monolith)

---

## Directory Structure Overview

```
project-rulebook-be/
├── 📁 Sources/                              # Main source code
│   └── 📁 App/                              # Application code
│       ├── 📁 Entrypoint/                   # ⭐ APPLICATION ENTRY POINT
│       │   ├── entrypoint.swift             # Main entry point (@main)
│       │   ├── configure.swift              # App configuration & route setup
│       │   └── Application-Setup.swift      # Application initialization
│       │
│       ├── 📁 Modules/                      # Feature modules (domain-driven)
│       │   ├── 📁 Auth/                     # 🔐 Authentication module
│       │   │   ├── AuthModule.swift         # Module bootstrapping
│       │   │   ├── AuthRouter.swift         # Route definitions
│       │   │   ├── 📁 Controllers/          # Request handlers
│       │   │   ├── 📁 Database/             # Fluent models & migrations
│       │   │   │   ├── 📁 Migrations/       # Schema migrations
│       │   │   │   └── 📁 Models/           # Database entities
│       │   │   ├── 📁 Models/               # DTOs & domain models
│       │   │   └── 📁 Repositories/         # Data access layer
│       │   │
│       │   ├── 📁 User/                     # 👤 User management module
│       │   │   ├── UserModule.swift
│       │   │   ├── UserRouter.swift
│       │   │   ├── 📁 Controllers/
│       │   │   ├── 📁 Database/
│       │   │   │   ├── 📁 Migrations/
│       │   │   │   └── 📁 Models/
│       │   │   ├── 📁 Models/
│       │   │   └── 📁 Repositories/
│       │   │
│       │   ├── 📁 RulesGeneration/          # 🎲 Core feature module
│       │   │   ├── RulesGenerationModule.swift
│       │   │   ├── RulesGenerationRouter.swift
│       │   │   ├── 📁 Controller/
│       │   │   ├── 📁 Database/
│       │   │   │   ├── 📁 Migrations/
│       │   │   │   └── 📁 Models/
│       │   │   ├── 📁 Models/
│       │   │   └── 📁 Repositories/
│       │   │
│       │   ├── 📁 Waitlist/                 # 📧 Email waitlist module
│       │   │   ├── WaitlistModule.swift
│       │   │   ├── WaitlistRouter.swift
│       │   │   ├── WaitlistController.swift
│       │   │   ├── 📁 Database/
│       │   │   │   ├── 📁 Migrations/
│       │   │   │   └── 📁 Models/
│       │   │   ├── 📁 Models/
│       │   │   └── 📁 Repositories/
│       │   │
│       │   ├── 📁 CacheAdmin/               # 🗄️ Admin cache management
│       │   │   ├── CacheAdminModule.swift
│       │   │   ├── CacheAdminRouter.swift
│       │   │   └── 📁 Controllers/
│       │   │
│       │   └── 📁 Frontend/                 # 🌐 HTML frontend rendering
│       │       ├── FrontendModule.swift
│       │       ├── FrontendRouter.swift
│       │       ├── 📁 Framework/            # Form/template framework
│       │       │   ├── 📁 Form/             # Form components
│       │       │   ├── 📁 Templates/        # Page templates
│       │       │   └── 📁 Validation/       # Form validation
│       │       ├── 📁 HTML/                 # HTML rendering
│       │       │   ├── 📁 Contexts/         # Template contexts
│       │       │   ├── 📁 Forms/            # HTML forms
│       │       │   └── 📁 Templates/        # HTML templates
│       │       ├── 📁 Models/
│       │       └── 📁 Controllers/
│       │
│       ├── 📁 Services/                     # Shared application services
│       │   ├── 📁 Cache/                    # 🗄️ Caching service (Redis)
│       │   │   └── 📁 Models/
│       │   ├── 📁 Configuration/            # ⚙️ App configuration
│       │   ├── 📁 Email/                    # 📧 Email service
│       │   │   └── 📁 Helpers/
│       │   ├── 📁 IPExtractor/              # 🌐 IP extraction utility
│       │   ├── 📁 KeyGeneration/            # 🔑 Key generation utility
│       │   ├── 📁 LLM/                      # 🤖 AI/LLM integration
│       │   │   └── 📁 Models/
│       │   ├── 📁 RandomGenerator/          # 🎲 Random generation
│       │   ├── 📁 Repositories/             # Base repository patterns
│       │   ├── 📁 UUIDGenerator/            # UUID generation
│       │   └── 📁 Validation/               # Validation service
│       │
│       ├── 📁 Common/                       # Cross-cutting concerns
│       │   ├── 📁 Context/                  # Request context
│       │   ├── 📁 Errors/                   # Error types
│       │   ├── 📁 Extensions/               # App/Request extensions
│       │   ├── 📁 Framework/                # Base interfaces
│       │   │   ├── Repository.swift         # Repository protocol
│       │   │   ├── ModuleInterface.swift    # Module protocol
│       │   │   └── DatabaseModelInterface.swift
│       │   ├── 📁 Middleware/               # Common middleware
│       │   ├── 📁 OpenAPI/                  # OpenAPI/Swagger UI
│       │   └── 📁 Validation/               # Validation rules
│       │
│       ├── 📁 Middlewares/                  # HTTP Middleware
│       │   ├── EnsureAdminUserMiddleware.swift
│       │   ├── UserPayloadAuthenticator.swift
│       │   ├── UserCredentialsAuthenticator.swift
│       │   └── 📁 Security/
│       │       ├── SecurityHeadersMiddleware.swift
│       │       └── 📁 RateLimit/            # Rate limiting
│       │           ├── RateLimitMiddleware.swift
│       │           ├── RateLimitConfiguration.swift
│       │           ├── RateLimitStorage.swift
│       │           └── RateLimitTypes.swift
│       │
│       ├── 📁 Extensions/                   # Swift extensions
│       │   ├── String+Hashtags.swift
│       │   ├── Data+Base64URL.swift
│       │   ├── URI-URL.swift
│       │   ├── SHA256+Base64.swift
│       │   ├── SHA256+String.swift
│       │   └── Environment+Keys.swift
│       │
│       ├── 📁 Errors/                       # Error handling
│       │   ├── UserError+AbortError.swift
│       │   ├── ContentError+AbortError.swift
│       │   └── AuthenticationError+AbortError.swift
│       │
│       └── 📁 Entities/                     # Domain entities
│           ├── 📁 AppAttest/
│           ├── 📁 Cache/
│           ├── 📁 Errors/
│           ├── 📁 Media/
│           ├── 📁 RulesGeneration/
│           └── 📁 User/
│
├── 📁 Tests/                                # Test suite
│   └── 📁 AppTests/
│       ├── 📁 Framework/                    # Test infrastructure
│       │   ├── 📁 Base/                     # Base test classes
│       │   ├── 📁 Builders/                 # Test data builders
│       │   ├── 📁 Helpers/                  # Test helpers
│       │   ├── 📁 Mocks/                    # Mock objects
│       │   │   ├── 📁 Models/
│       │   │   ├── 📁 Repositories/
│       │   │   └── 📁 Services/
│       │   └── 📁 Performance/              # Performance test base
│       ├── 📁 Tests/                        # Unit & integration tests
│       │   ├── 📁 ControllerTests/
│       │   │   ├── 📁 AuthenticationTests/
│       │   │   ├── 📁 RulesGenerationTests/
│       │   │   └── 📁 UserTests/
│       │   ├── 📁 ServiceTests/
│       │   └── 📁 RepositoryTests/
│       ├── 📁 Performance/                  # Performance tests
│       │   ├── 📁 Cache/
│       │   ├── 📁 Load/
│       │   └── 📁 Repository/
│       ├── 📁 Security/                     # Security tests
│       ├── 📁 Services/                     # Service tests
│       │   ├── 📁 Configuration/
│       │   ├── 📁 Domain/
│       │   └── 📁 LLM/
│       └── 📁 Validation/                   # Validation tests
│
├── 📁 Public/                               # Static files
│
├── 📁 docker/                               # Docker configuration
│   ├── 📁 postgres/
│   │   └── 📁 init/                         # DB init scripts
│   └── 📁 redis/
│       └── redis.conf                       # Redis config
│
├── 📁 docs/                                 # Documentation
│   ├── 📁 architecture/
│   ├── 📁 development/
│   ├── 📁 features/
│   ├── 📁 planning/
│   ├── 📁 product/
│   └── 📁 testing/
│
├── 📁 scripts/                              # Utility scripts
│
├── Package.swift                            # ⭐ SPM manifest
├── Package.resolved                         # Dependency lock file
├── Dockerfile                               # Container build
├── docker-compose.yml                       # Production compose
├── docker-compose.dev.yml                   # Development compose
├── railway.toml                             # Railway deployment
└── README.md                                # Project documentation
```

---

## Entry Points

| File | Type | Description |
|------|------|-------------|
| `Sources/App/Entrypoint/entrypoint.swift` | **Main** | Application bootstrap with `@main` |
| `Sources/App/Entrypoint/configure.swift` | Config | Routes, middleware, database setup |
| `Dockerfile` | Build | Container entry point |
| `Package.swift` | Build | Swift Package Manager manifest |

---

## Module Structure Pattern

Each module follows this consistent structure:

```
Module/
├── {Module}Module.swift      # Module registration & boot
├── {Module}Router.swift      # Route definitions
├── Controllers/              # Request handlers
├── Database/
│   ├── Migrations/           # Schema changes
│   └── Models/               # Fluent entities
├── Models/                   # DTOs, request/response types
└── Repositories/             # Data access abstraction
```

---

## Key Integration Points

| Layer | Location | Purpose |
|-------|----------|---------|
| API Routes | `Modules/*/Router.swift` | HTTP endpoint definitions |
| Database | `Modules/*/Database/` | Fluent ORM integration |
| Services | `Services/` | Cross-module business logic |
| Middleware | `Middlewares/` | Request/response processing |
| External APIs | `Services/LLM/` | AI/ML service integration |
| Email | `Services/Email/` | Email delivery |
| Caching | `Services/Cache/` | Redis caching layer |

---

## Statistics

| Metric | Count |
|--------|-------|
| Feature Modules | 6 |
| Shared Services | 10 |
| Database Models | 5 |
| Test Directories | 14 |
| Total Directories | ~100 |
