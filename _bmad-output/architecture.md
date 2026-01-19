# Architecture Documentation - project-rulebook-be

**Generated:** 2026-01-19
**Version:** 1.0
**Project Type:** Swift/Vapor Backend (Modular Monolith)

---

## Executive Summary

**project-rulebook-be** is an AI-powered board game rules generation backend built with Swift 6.0 and Vapor 4. The application provides REST API endpoints for game box image recognition and comprehensive rules summary generation using AI services (OpenAI/Gemini).

### Key Characteristics

- **Architecture Style:** Modular Monolith with Service-Oriented Design
- **Language:** Swift 6.0
- **Framework:** Vapor 4.115.1
- **Database:** PostgreSQL (production), SQLite (development/testing)
- **Caching:** Redis with in-memory fallback
- **Authentication:** JWT with refresh tokens

### Core Capabilities

1. **Game Box Recognition** - AI-powered image analysis to identify board games
2. **Rules Generation** - AI-generated comprehensive game rule summaries
3. **User Management** - Authentication, authorization, profile management
4. **Cache Administration** - AI response caching for cost optimization
5. **Email Waitlist** - Pre-launch subscriber management

---

## Technology Stack

### Core Technologies

| Category | Technology | Version | Purpose |
|----------|------------|---------|---------|
| Language | Swift | 6.0 | Primary development language |
| Framework | Vapor | 4.115.1 | Web application framework |
| ORM | Fluent | 4.12.0 | Database abstraction |
| Auth | JWT | 4.2.2 | Token-based authentication |
| Caching | Redis | 4.13.0 | High-performance caching |

### Databases

| Database | Driver | Use Case |
|----------|--------|----------|
| PostgreSQL | fluent-postgres-driver 2.10.1 | Production, Staging |
| SQLite | fluent-sqlite-driver 4.8.1 | Development, Testing |

### Additional Libraries

| Library | Purpose |
|---------|---------|
| SwiftHtml | Server-side HTML rendering |
| SwiftSvg | SVG generation |
| VaporToOpenAPI | OpenAPI specification generation |
| swift-crypto | Cryptographic operations |
| swift-nio | Async networking |

### Platform

- **Target:** macOS 15+
- **Build:** Swift Package Manager
- **Container:** Docker (multi-stage build)
- **Deployment:** Railway, Docker

---

## Architecture Pattern

### Modular Monolith

The application follows a modular monolith architecture where:

- Each **module** is a self-contained feature domain
- Modules communicate through well-defined interfaces
- Shared services provide cross-cutting functionality
- All modules deploy as a single unit

### Layered Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    HTTP Layer (Vapor)                       │
│  Routes → Middleware → Controllers → Responses              │
├─────────────────────────────────────────────────────────────┤
│                    Module Layer                             │
│  Auth │ User │ RulesGeneration │ Waitlist │ CacheAdmin │ Frontend
├─────────────────────────────────────────────────────────────┤
│                    Service Layer                            │
│  LLM │ Cache │ Email │ Configuration │ Validation          │
├─────────────────────────────────────────────────────────────┤
│                    Repository Layer                         │
│  Fluent ORM │ Database Abstraction                          │
├─────────────────────────────────────────────────────────────┤
│                    Infrastructure Layer                     │
│  PostgreSQL │ Redis │ External APIs (OpenAI/Gemini/Brevo)  │
└─────────────────────────────────────────────────────────────┘
```

### Module Structure Pattern

Each module follows a consistent internal structure:

```
{Module}/
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

## Data Architecture

### Database Schema

#### Core Tables

| Table | Module | Description |
|-------|--------|-------------|
| `users` | User | User accounts and profiles |
| `refresh_tokens` | Auth | JWT refresh tokens |
| `email_tokens` | Auth | Email verification tokens |
| `password_tokens` | Auth | Password reset tokens |
| `waitlist_entries` | Waitlist | Pre-launch subscribers |
| `generated_rules` | RulesGeneration | Cached AI-generated rules |

### Entity Relationships

```
UserAccountModel (users)
    │
    ├──1:N── RefreshTokenModel
    ├──1:N── EmailTokenModel
    └──1:N── PasswordTokenModel

WaitlistEntryModel (standalone)
GeneratedRuleModel (standalone, caching layer)
```

### Migration Strategy

- Fluent migrations with versioning (v1, v2, etc.)
- Auto-run on application startup
- Seed data for default admin user

---

## API Design

### REST API Structure

```
/api/v1/
├── /auth/              # Authentication
│   ├── POST /sign-in
│   ├── POST /sign-up
│   ├── POST /apple-auth
│   ├── POST /refresh
│   ├── POST /reset-password
│   └── POST /logout
├── /user/              # User management
│   ├── GET /me
│   ├── PATCH /update
│   ├── DELETE /delete
│   └── GET /list (admin)
├── /rules-generation/  # Core AI feature
│   ├── POST /game-box-analysis
│   └── POST /rules-summary
├── /waitlist/          # Email waitlist
│   ├── POST /
│   ├── GET /unsubscribe/:token
│   ├── GET /stats (admin)
│   └── POST /notify (admin)
/api/admin/
└── /cache/             # Cache administration
    ├── GET /stats
    ├── GET /health
    ├── GET /entries
    ├── GET /redis/health
    ├── DELETE /
    └── POST /cleanup
```

### Authentication

- **JWT Bearer Tokens** for API authentication
- **Refresh Tokens** for session management
- **Admin Middleware** for privileged endpoints

### Rate Limiting

| Operation | Limit | Window |
|-----------|-------|--------|
| Image Analysis | 3/hour | Per IP |
| Rules Generation | 10/hour | Per IP |
| General API | 100/hour | Per IP |

---

## Component Overview

### Modules (6)

| Module | Responsibility |
|--------|----------------|
| **Auth** | User authentication, JWT tokens, email verification |
| **User** | User profiles, account management, admin operations |
| **RulesGeneration** | AI image analysis, rules generation, caching |
| **Waitlist** | Email subscription, launch notifications |
| **CacheAdmin** | Cache monitoring, statistics, management |
| **Frontend** | HTML rendering, forms, email templates |

### Services (10)

| Service | Responsibility |
|---------|----------------|
| **LLM** | OpenAI/Gemini API integration |
| **Cache** | Redis caching layer |
| **Email** | Brevo email delivery |
| **Configuration** | Environment management |
| **Validation** | Input validation rules |
| **IPExtractor** | Client IP detection |
| **KeyGeneration** | Secure key generation |
| **RandomGenerator** | Random value generation |
| **UUIDGenerator** | UUID generation |
| **Repositories** | Base repository patterns |

### Middleware Stack

```
Request Flow:
→ Security Headers (HSTS, CSP, X-Frame-Options)
→ CORS
→ Correlation ID
→ Error Handler
→ Rate Limiting
→ Authentication (where required)
→ Controller
```

---

## Security Architecture

### Authentication Flow

```
Client → POST /auth/sign-in → JWT Access Token + Refresh Token
      → API Request + Bearer Token → Validated → Controller
      → Token Expired → POST /auth/refresh → New Access Token
```

### Security Layers

1. **Transport:** TLS (production)
2. **Headers:** Security headers middleware
3. **Authentication:** JWT verification
4. **Authorization:** Admin middleware for privileged routes
5. **Rate Limiting:** IP-based request throttling
6. **Input Validation:** Sanitization and validation
7. **AI Security:** Prompt injection protection

### AI Security

- Input sanitization for LLM prompts
- Response validation
- Content filtering
- Injection attempt detection

---

## Caching Architecture

### Cache Layers

1. **Redis Cache** - Primary distributed cache
2. **In-Memory Cache** - Application-level fallback

### Cache Strategy

| Content | TTL | Strategy |
|---------|-----|----------|
| Rules Summary | 1 hour | Content-based keys |
| Image Analysis | 30 min | Content-based keys |
| User Sessions | 24 hours | Token-based |

### Cache Benefits

- 80% reduction in AI API costs
- Sub-100ms response times for cached content
- LRU eviction for memory management

---

## Testing Architecture

### Test Categories

| Type | Location | Framework |
|------|----------|-----------|
| Unit | `Tests/AppTests/Tests/ServiceTests` | XCTest |
| Integration | `Tests/AppTests/Tests/ControllerTests` | VaporTesting |
| Performance | `Tests/AppTests/Performance` | XCTest |
| Security | `Tests/AppTests/Security` | XCTest |

### Test Infrastructure

- **TestWorld** - Isolated test environments
- **Mock Services** - External service simulation
- **Test Data Factory** - Consistent test data
- **Performance Benchmarks** - Automated benchmarking

### Test Configuration

- SQLite in-memory database
- Mocked external services
- Isolated test transactions

---

## Deployment Architecture

### Container Architecture

```
┌─────────────────────────────────────┐
│           Load Balancer             │
└─────────────────┬───────────────────┘
                  │
┌─────────────────▼───────────────────┐
│         Vapor Application           │
│    (Docker: swift:6.0-jammy-slim)   │
└─────────────────┬───────────────────┘
                  │
      ┌───────────┼───────────┐
      │           │           │
┌─────▼────┐ ┌────▼────┐ ┌────▼────┐
│PostgreSQL│ │  Redis  │ │External │
│          │ │         │ │ APIs    │
└──────────┘ └─────────┘ └─────────┘
```

### Environment Matrix

| Environment | Database | Cache | External Services |
|-------------|----------|-------|-------------------|
| Development | PostgreSQL (Docker) | Redis (Docker) | Real APIs |
| Testing | SQLite (memory) | Mock | Mocked |
| Staging | PostgreSQL (TLS) | Redis (TLS) | Real APIs |
| Production | PostgreSQL (TLS) | Redis (TLS) | Real APIs |

### Deployment Platform

- **Primary:** Railway (auto-deploy from Git)
- **Alternative:** Docker Compose, Kubernetes

---

## Integration Points

### External Services

| Service | Purpose | Integration |
|---------|---------|-------------|
| OpenAI | AI/LLM for game analysis | REST API |
| Google Gemini | Alternative AI provider | REST API |
| Brevo | Email delivery | REST API |
| Apple | Sign in with Apple | OAuth |

### Internal Integration

```
Modules → Services → External APIs
        ↓
     Repositories → Database
        ↓
     Cache → Redis
```

---

## Source Files Summary

| Category | Count |
|----------|-------|
| Feature Modules | 6 |
| Shared Services | 10 |
| Database Models | 5 |
| Migrations | 4 |
| Controllers | ~12 |
| Test Files | ~50+ |
| Total Directories | ~100 |

---

## Key Architectural Decisions

### ADR-001: Modular Monolith over Microservices

**Decision:** Implement as modular monolith
**Rationale:** Simpler deployment, reduced operational complexity, suitable for team size
**Trade-offs:** Less independent scaling, shared deployment cycle

### ADR-002: Fluent ORM with Repository Pattern

**Decision:** Use Fluent with repository abstraction
**Rationale:** Database agnostic, testable, clean separation
**Trade-offs:** Additional abstraction layer, learning curve

### ADR-003: Redis for AI Response Caching

**Decision:** Cache AI responses in Redis
**Rationale:** 80% API cost reduction, fast response times
**Trade-offs:** Cache invalidation complexity, memory usage

### ADR-004: JWT with Refresh Tokens

**Decision:** Stateless JWT with refresh token rotation
**Rationale:** Scalable, no server-side session storage
**Trade-offs:** Token revocation complexity

---

## References

- [API Contracts](./api-contracts.md)
- [Data Models](./data-models.md)
- [Source Tree Analysis](./source-tree-analysis.md)
- [Development Guide](./development-guide.md)
- [Deployment Guide](./deployment-guide.md)
- [Existing Architecture Docs](../docs/architecture/)
