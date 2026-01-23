---
title: "Technical Architecture"
description: "System architecture, patterns, and technical details for project-rulebook-be"
author: Claude
date: 2026-01-23
---

# Technical Architecture Documentation

## System Overview

Project Rulebook is a Vapor 4 Swift web application that leverages AI to analyze board game box images and generate comprehensive rule summaries. The application employs a modular architecture with strict separation of concerns, simple property-based dependency injection, and enterprise-grade security.

### Core Architectural Principles

1. **Modular Monolith Architecture**: Complete vertical slices with colocated business logic
2. **Controller-Centric Design**: Business logic lives directly in controllers
3. **Service-Oriented Design**: All external integrations abstracted through service interfaces
4. **Repository Pattern**: Database operations abstracted for testability
5. **Property-Based DI**: Simple `req.services.*` and `req.repositories.*` accessor pattern

### Technology Stack

- **Framework**: Vapor 4 with Swift 6.0+
- **Database**: PostgreSQL (production), SQLite in-memory (testing)
- **ORM**: Fluent with auto-migration
- **Caching**: Redis for AI response caching
- **Authentication**: JWT with refresh tokens
- **Template Engine**: SwiftHtml for server-side rendering
- **External APIs**: Google Gemini (primary LLM), OpenAI (alternative), Brevo (email)

## Module Architecture

### Module Structure Pattern

Each module follows a complete vertical slice architecture:

```text
Sources/App/Modules/[Module]/
├── [Module]Module.swift      # Registration & configuration
├── [Module]Router.swift      # Route definitions
├── Controllers/              # HTTP endpoints + business logic
├── Repositories/             # Data access abstraction
├── Models/                   # Request/Response DTOs
└── Database/
    ├── Models/               # Fluent database models
    └── Migrations/           # Schema migrations
```

### Module Implementations

#### 1. UserModule
**Purpose**: User account management and profile operations

**Key Components**:
- `UserController`: Profile CRUD operations with business logic
- `UserRepository`: Data access abstraction
- `UserAccountModel`: Database entity

**Endpoints**:
- `GET /api/v1/user/me` - Get current user
- `PATCH /api/v1/user/update` - Update profile
- `DELETE /api/v1/user/delete` - Delete account
- `GET /api/v1/user/list` - List all users (admin)

#### 2. AuthModule
**Purpose**: Authentication, JWT management, email verification

**Key Components**:
- `AuthController`: Authentication workflows
- Token repositories (refresh, email, password)
- JWT payload structures and authenticators

**Security Features**:
- Access tokens: 15-minute expiry
- Refresh tokens: 7-day expiry with rotation
- Bcrypt password hashing
- Email verification flow
- Rate limiting per operation

**Endpoints**:
- `POST /api/v1/auth/sign-up` - Registration
- `POST /api/v1/auth/sign-in` - Login (Basic auth)
- `POST /api/v1/auth/apple-auth` - Apple Sign In
- `POST /api/v1/auth/refresh` - Token refresh
- `POST /api/v1/auth/reset-password` - Password reset
- `POST /api/v1/auth/logout` - End session (protected)

#### 3. FrontendModule
**Purpose**: Server-side rendering with SwiftHtml

**Key Components**:
- `FrontendController`: Web request handling
- Form framework with validation
- Template system with contexts
- SwiftHtml integration

**Features**:
- Comprehensive form validation framework
- Reusable template components
- Mobile-responsive design
- Async validation support

#### 4. RulesGenerationModule
**Purpose**: AI-powered game analysis with security

**Key Components**:
- `RulesGenerationController`: AI processing with security
- Security validation pipeline
- Intelligent caching system

**Security Pipeline**:
```text
Input → Sanitization → Injection Detection → AI Processing → Response Validation → Caching
```

**Cache Strategy**:
- Image analysis: 30-minute TTL
- Rules generation: 60-minute TTL
- Content-based cache keys
- 80% API cost reduction

**Endpoints**:
- `POST /api/v1/rules-generation/game-box-analysis` - Analyze game box
- `POST /api/v1/rules-generation/rules-summary` - Generate rules

#### 5. CacheAdminModule
**Purpose**: Cache management and monitoring

**Key Components**:
- `CacheAdminController`: Admin operations
- Statistics aggregation
- Health monitoring

**Features**:
- Real-time cache statistics
- Health status monitoring
- Manual cache operations
- Performance recommendations

#### 6. WaitlistModule
**Purpose**: Email waitlist management for app launches

**Key Components**:
- `WaitlistController`: Subscription management
- `WaitlistRepository`: Data access
- Email notification integration

**Endpoints**:
- `POST /api/v1/waitlist/subscribe` - Join waitlist
- `GET /api/v1/waitlist/unsubscribe` - Remove from waitlist
- `POST /api/v1/waitlist/notify` - Admin: send notifications

## Service Layer & Dependency Injection

### Property-Based Architecture

The application uses a simple property-based DI pattern that stores services on `Application` and provides access through `Request` extensions:

```swift
// Access services from any route handler
func handleRequest(_ req: Request) async throws -> Response {
    // Service access via req.services.*
    let llm = req.services.llm
    let cache = req.services.aiCache

    // Repository access via req.repositories.*
    let user = try await req.repositories.users.find(id: userId)

    return response
}
```

### Service Storage Pattern

```swift
// Application stores services
extension Application {
    var llmService: LLMService {
        get { serviceStorage.llmService! }
        set { serviceStorage.llmService = newValue }
    }
}

// Request provides convenient accessors
extension Request {
    var services: RequestServices {
        RequestServices(app: application)
    }
}

struct RequestServices {
    let app: Application
    var llm: LLMService { app.llmService }
    var email: EmailService { app.emailService }
    var aiCache: AICacheServiceInterface { app.aiCacheService }
    // ... other services
}
```

### Service Initialization

Services are initialized once during application startup in `Application-Setup.swift`:

```swift
func setupServices(_ app: Application) throws {
    // Initialize services
    app.llmService = LLMService(apiKey: Environment.openAIKey)
    app.emailService = EmailService(apiKey: Environment.brevoKey)
    app.aiCacheService = AICacheService(cache: app.cacheService)

    // Initialize repositories
    app.userRepository = UserDatabaseRepository(database: app.db)
    app.refreshTokenRepository = RefreshTokenDatabaseRepository(database: app.db)
    // ... other repositories
}
```

### Key Services

1. **LLMService**: AI text generation and image analysis (Google Gemini primary, OpenAI alternative)
2. **AICacheService**: Intelligent response caching with Redis
3. **EmailService**: Brevo transactional emails
4. **AIInputValidatorService**: AI input validation and sanitization
5. **PromptSanitizerService**: Prompt injection prevention
6. **CacheKeyGeneratorService**: Content-based cache key generation
7. **AIResponseValidationService**: AI response security validation

## Repository Pattern

### Repository Interface Pattern

```swift
protocol UserRepository: Repository {
    func create(_ user: UserAccountModel) async throws -> UserAccountModel
    func find(email: String) async throws -> UserAccountModel?
    func find(id: UUID) async throws -> UserAccountModel?
    func update(_ user: UserAccountModel) async throws -> UserAccountModel
    func delete(id: UUID) async throws
}
```

### Repository Implementation

```swift
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

### Repository Access Pattern

```swift
// In controllers - use req.repositories.*
func getUser(_ req: Request) async throws -> UserDTO {
    let userId = try req.auth.require(UserPayload.self).userId
    guard let user = try await req.repositories.users.find(id: userId) else {
        throw Abort(.notFound)
    }
    return UserDTO(from: user)
}
```

### Database Models

```swift
final class UserAccountModel: Model, Content {
    static let schema = "users"

    @ID(key: .id) var id: UUID?
    @Field(key: "email") var email: String
    @OptionalField(key: "password") var password: String?  // Optional for Apple Sign-In
    @Field(key: "is_admin") var isAdmin: Bool
    @Field(key: "is_email_verified") var isEmailVerified: Bool
    @OptionalField(key: "first_name") var firstName: String?
    @OptionalField(key: "last_name") var lastName: String?
    @OptionalField(key: "apple_user_identifier") var appleUserIdentifier: String?
    @Timestamp(key: "created_at", on: .create) var createdAt: Date?
    @Timestamp(key: "updated_at", on: .update) var updatedAt: Date?
    @Timestamp(key: "deleted_at", on: .delete) var deletedAt: Date?  // Soft delete
}
```

## Testing Architecture

### IsolatedTestWorld Pattern

The testing infrastructure uses IsolatedTestWorld for complete suite isolation:

```swift
@Suite(.serialized)  // Within-suite serialization
struct MyControllerTests {
    let testWorld: IsolatedTestWorld

    init() async throws {
        testWorld = try await IsolatedTestWorld()  // Fresh app & repos
    }

    @Test func testEndpoint() async throws {
        let response = try await testWorld.app.sendRequest(
            to: "/api/endpoint",
            method: .POST,
            body: requestBody
        )
        #expect(response.status == .ok)
    }
}
```

### Test Categories

1. **Integration Tests**: Controller and endpoint testing with IsolatedTestWorld
2. **Unit Tests**: Service and repository testing with mocks
3. **Performance Tests**: Benchmarking with clear baselines
4. **Mock Services**: Complete mocking of external dependencies

### Mock Service Pattern

```swift
final class MockUserRepository: UserRepository {
    var users: [UUID: UserAccountModel] = [:]

    func create(_ user: UserAccountModel) async throws -> UserAccountModel {
        users[user.id!] = user
        return user
    }

    func find(id: UUID) async throws -> UserAccountModel? {
        return users[id]
    }
}

// Register mock in tests via property injection
testWorld.app.userRepository = mockUserRepository
```

### Testing Best Practices

- **Suite Isolation**: Each test suite gets fresh Application and database
- **Concurrent Execution**: Test suites run in parallel safely
- **SQLite In-Memory**: Fast, isolated test database
- **Property Injection**: Set mock services/repositories directly on Application
- **Swift Testing**: Modern testing framework with `@Test` and `#expect`

## External Integrations

### LLM Integration

The application uses an abstracted `LLMService` protocol with Google Gemini as the primary implementation:

```swift
// LLMService protocol - provider-agnostic
protocol LLMService {
    func generate(input: String) async throws -> String
    func analyzeImage(imageData: String, prompt: String) async throws -> String
}

// Usage in controller
let response = try await req.services.llm.generate(input: prompt)
let imageAnalysis = try await req.services.llm.analyzeImage(imageData: base64Image, prompt: analysisPrompt)
```

Available implementations:
- `GoogleGeminiService` (default) - Uses Google's Gemini API
- `OpenAIService` - Uses OpenAI's `/v1/responses` API

### Redis Caching

High-performance caching for AI responses:

```swift
// Cache key generation
func generateCacheKey(for content: String, context: String) -> String {
    let hash = SHA256.hash(data: content.data(using: .utf8)!)
    return "\(context)_\(hash.hex)"
}

// Cache operations via service
let cached = try await req.services.aiCache.get(key)
try await req.services.aiCache.set(key, value: response, ttl: 3600)
```

### Email Service (Brevo)

```swift
// Access via req.services.email
try await req.services.email.sendVerificationEmail(to: email, token: token)
try await req.services.email.sendPasswordResetEmail(to: email, resetLink: link)
```

## Security Architecture

### AI Security Pipeline

Multi-layer security for AI interactions:

1. **Input Sanitization**: Remove dangerous characters
2. **Injection Detection**: Pattern-based detection
3. **Content Validation**: Structural validation
4. **Response Validation**: AI output scanning

```swift
// Security validation in controller
let sanitized = try req.services.promptSanitizer.sanitize(input)
try req.services.aiInputValidator.validate(sanitized)
let response = try await req.services.llm.generate(sanitized)
try req.services.aiResponseValidator.validate(response)
```

### Rate Limiting

Operation-specific rate limits:

```yaml
Rate Limits (Production):
  - Image Analysis: 3/hour per IP
  - Rules Generation: 10/hour per IP
  - API Operations: 50/hour per IP
  - General Requests: 500/hour per IP
  - Waitlist: 10/hour per IP
  - Admin Operations: 10/5min (authenticated)
```

### Authentication & Authorization

- **JWT Tokens**: Access (15min) and refresh (7 days) tokens
- **Middleware**: `UserCredentialsAuthenticator`, `UserPayloadAuthenticator`
- **Role-Based**: Admin checks in controllers
- **Session Management**: Secure token rotation

## Performance Optimization

### Caching Strategy

- **AI Response Cache**: 80% cost reduction
- **TTL Management**: Context-aware expiration
- **LRU Eviction**: Automatic memory management
- **Hit Rate Monitoring**: Real-time statistics

### Database Optimization

- **Connection Pooling**: Efficient connection reuse
- **Proper Indexing**: Optimized query performance
- **Async Operations**: Non-blocking database access
- **Migration System**: Version-controlled schema

### Response Times (SLA)

```yaml
Performance Targets:
  - Authentication: < 200ms
  - AI Rules (cached): < 100ms
  - AI Rules (fresh): < 3000ms
  - Image Analysis (cached): < 100ms
  - Image Analysis (fresh): < 5000ms
  - Database Queries: < 50ms
```

## Development Workflow

### Environment Configuration

```yaml
Development:
  Database: PostgreSQL (via Docker)
  Logging: Debug level
  Security: Relaxed for testing

Testing:
  Database: SQLite in-memory
  Services: All mocked via property injection
  Isolation: Complete per suite

Production:
  Database: PostgreSQL with TLS
  Caching: Redis cluster
  Security: Maximum
  Monitoring: Comprehensive
```

### Build & Run Commands

```bash
# Development
swift build
swift run App serve --hostname 0.0.0.0 --port 8080

# Testing
swift test  # Concurrent suite execution

# Database
docker-compose -f docker-compose.dev.yml up -d  # Start services
docker-compose -f docker-compose.dev.yml down -v  # Reset
```

### Code Organization Standards

- **Module Completeness**: Each module contains full vertical slice
- **Controller-Centric**: Business logic in controllers, not separate layer
- **Service Simplicity**: Direct property access over factory patterns
- **Framework Alignment**: Work with Vapor conventions
- **Three-Strike Rule**: Create abstractions on third occurrence

### Naming Conventions

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

### Environment Variables

| Variable | Purpose | Required |
|----------|---------|----------|
| `DATABASE_URL` | PostgreSQL connection | Prod only |
| `REDIS_URL` | Redis connection | Prod only |
| `OPENAI_API_KEY` | OpenAI API | Yes |
| `GEMINI_API_KEY` | Google Gemini API | Yes |
| `JWT_SECRET` | JWT signing | Yes |
| `BREVO_API_KEY` | Email service | Optional |

## Architectural Guidelines

### Design Principles

1. **Single Responsibility**: Each component has one clear purpose
2. **Dependency Inversion**: Depend on abstractions (protocols), not concretions
3. **Interface Segregation**: Small, focused interfaces
4. **Simplicity**: Prefer simple patterns over complex abstractions
5. **Framework Harmony**: Work with Vapor, not against it

### Best Practices

1. **Use property accessors** - `req.services.*` and `req.repositories.*`
2. **Maintain module boundaries** - Complete vertical slices
3. **Keep business logic in controllers** - No separate use case layer
4. **Mock via property injection** - Set mock implementations on Application
5. **Use framework conventions** - Work with Vapor patterns

### Anti-Patterns to Avoid

| Anti-Pattern | Why It's Wrong | Do Instead |
|--------------|----------------|------------|
| `DispatchQueue.global().async` | Breaks structured concurrency | Use `async/await` |
| `try!` force unwrap | Crashes in production | Handle errors properly |
| Importing module internals | Breaks encapsulation | Use public APIs only |
| Raw `Abort()` throws | Inconsistent error format | Use `AppError` enum |
| Inline SQL queries | SQL injection risk | Use Fluent query builder |
| Hardcoded secrets | Security vulnerability | Use environment variables |
| Synchronous blocking calls | Blocks event loop | Use async alternatives |
| Creating new patterns | Inconsistency | Follow existing patterns |
| Complex DI frameworks | Unnecessary complexity | Use property-based DI |
| Abstractions before third use | Premature abstraction | Wait for third occurrence |

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
4. Access via `req.services.*`

**Adding a new module:**
1. Create directory structure per Module Structure Pattern above
2. Register in `Application-Setup.swift`
3. Add routes via module's router

**Error handling pattern:**
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
```

## Future Considerations

### Potential Enhancements

1. **API Versioning**: URL prefix strategy (`/api/v1/...`)
2. **Receipt Validation**: App Store and Play Store purchases
3. **GraphQL API**: Alternative to REST endpoints
4. **WebSocket Support**: Real-time features
5. **Background Jobs**: Queue system for async processing

### Scalability Path

1. **Horizontal Scaling**: Stateless design ready
2. **Database Sharding**: Partition strategy defined
3. **Cache Distribution**: Redis cluster ready
4. **Load Balancing**: Compatible architecture
5. **Microservices**: Module boundaries enable extraction

---

This technical architecture provides a comprehensive foundation for development, testing, and maintenance of the Project Rulebook application. All components follow established patterns, maintain clear boundaries, and prioritize simplicity and testability.
