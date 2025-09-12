# Technical Architecture Documentation

## System Overview

Project Rulebook is a Vapor 4 Swift web application that leverages AI to analyze board game box images and generate comprehensive rule summaries. The application employs a modular architecture with strict separation of concerns, comprehensive dependency injection, and enterprise-grade security.

### Core Architectural Principles

1. **Modular Monolith Architecture**: Complete vertical slices with colocated business logic
2. **Clean Architecture Layers**: Clear separation between HTTP, business logic, and infrastructure
3. **Service-Oriented Design**: All external integrations abstracted through service interfaces
4. **Repository Pattern**: Database operations abstracted for testability
5. **Dependency Injection**: ServiceRegistry system for comprehensive DI and lifecycle management

### Technology Stack

- **Framework**: Vapor 4 with Swift 5.9+
- **Database**: PostgreSQL (production), SQLite in-memory (testing)
- **ORM**: Fluent with auto-migration
- **Caching**: Redis for AI response caching
- **Authentication**: JWT with refresh tokens
- **Template Engine**: SwiftHtml for server-side rendering
- **External APIs**: OpenAI (Responses API), Brevo (email)

## Module Architecture

### Module Structure Pattern

Each module follows a complete vertical slice architecture:

```
Sources/App/Modules/[Module]/
├── [Module]Module.swift      # Registration & configuration
├── Controllers/              # HTTP endpoints
├── UseCases/                # Business logic (COLOCATED!)
├── Repositories/            # Data access
├── Models/                  # Domain entities
└── Services/                # External integrations
```

### Module Implementations

#### 1. UserModule
**Purpose**: User account management and profile operations

**Key Components**:
- `UserController`: Profile CRUD operations
- `UserRepository`: Data access abstraction
- `UserAccountModel`: Database entity

**Endpoints**:
- `GET /api/users/profile` - Get current user
- `PATCH /api/users/profile` - Update profile
- `DELETE /api/users/profile` - Delete account
- `GET /api/users/list` - List all users (admin)

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
- `POST /api/auth/sign-up` - Registration
- `POST /api/auth/sign-in` - Login
- `POST /api/auth/refresh-token` - Token refresh
- `POST /api/auth/verify-email` - Email verification
- `POST /api/auth/reset-password` - Password reset

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
- `RulesGenerationController`: AI processing
- Security validation pipeline
- Intelligent caching system

**Security Pipeline**:
```
Input → Sanitization → Injection Detection → AI Processing → Response Validation → Caching
```

**Cache Strategy**:
- Image analysis: 30-minute TTL
- Rules generation: 60-minute TTL
- Content-based cache keys
- 80% API cost reduction

**Endpoints**:
- `POST /api/rules-generation/game-box-analysis` - Analyze game box
- `POST /api/rules-generation/rules-summary` - Generate rules

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

## Service Layer & Dependency Injection

### ServiceRegistry Architecture

The ServiceRegistry provides centralized service management with the following features:

```swift
ServiceRegistry System
├── ServiceContainer         # Thread-safe resolution with NIOLock
├── ServiceLifecycle        # Startup/shutdown management
├── ServiceHealthCheck      # Health monitoring
└── ServiceProvider         # Registration pattern
```

### Service Registration Pattern

```swift
// Define a service provider
struct DatabaseServiceProvider: ServiceProvider {
    static func register(in registry: ServiceContainer, app: Application) async throws {
        // Register with factory function
        registry.register(UserRepository.self) { app in
            return UserDatabaseRepository(database: app.db)
        }
        
        // Register existing instance
        let configService = ConfigurationService(app: app)
        registry.register(ConfigurationService.self, instance: configService)
    }
}

// Register in application setup
try await DatabaseServiceProvider.register(in: app.serviceRegistry, app: app)
```

### Service Resolution Pattern

```swift
// In controllers
func handleRequest(_ request: Request) async throws -> Response {
    // Resolve required service (throws if not found)
    let userRepo = try await request.resolveService(any UserRepository.self)
    
    // Resolve optional service
    let cache = try await request.resolveServiceOptional(CacheService.self)
    
    // Use services
    let user = try await userRepo.find(id: userId)
}
```

### Service Implementation Patterns

#### Basic Service
```swift
final class EmailService {
    private let apiKey: String
    
    init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    func sendEmail(to: String, subject: String) async throws {
        // Implementation
    }
}
```

#### Service with Lifecycle
```swift
final class CacheService: ServiceLifecycle, ServiceHealthCheck {
    private var cache: Cache?
    
    func startup(_ app: Application) async throws {
        cache = try Cache(config: app.configuration.cacheConfig)
        app.logger.info("Cache service started")
    }
    
    func shutdown(_ app: Application) async throws {
        try await cache?.shutdown()
        app.logger.info("Cache service stopped")
    }
    
    func healthCheckName() -> String { "Cache Service" }
    
    func isHealthy() async -> Bool {
        cache?.isConnected == true
    }
}
```

### Key Services

1. **ConfigurationService**: Environment-specific configuration
2. **LLMService**: OpenAI integration using Responses API
3. **AICacheService**: Intelligent response caching
4. **EmailService**: Brevo transactional emails
5. **SecurityServices**: AI input validation and sanitization

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
final class UserDatabaseRepository: UserRepository {
    let database: Database
    
    init(database: Database) {
        self.database = database
    }
    
    func find(email: String) async throws -> UserAccountModel? {
        try await UserAccountModel.query(on: database)
            .filter(\.$email == email)
            .first()
    }
}
```

### Database Models

```swift
final class UserAccountModel: Model, Content {
    static let schema = "user_accounts"
    
    @ID(key: .id) var id: UUID?
    @Field(key: "email") var email: String
    @Field(key: "password_hash") var passwordHash: String
    @Field(key: "is_admin") var isAdmin: Bool
    @Field(key: "is_email_verified") var isEmailVerified: Bool
    @Timestamp(key: "created_at", on: .create) var createdAt: Date?
    @Timestamp(key: "updated_at", on: .update) var updatedAt: Date?
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
        // Each suite gets its own Application instance
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

1. **Unit Tests**: Direct testing of use cases and services
2. **Integration Tests**: Controller and repository testing with IsolatedTestWorld
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

// Register in tests
testWorld.app.serviceRegistry.register(
    UserRepository.self,
    instance: MockUserRepository()
)
```

### Testing Best Practices

- **Suite Isolation**: Each test suite gets fresh Application and database
- **Concurrent Execution**: Test suites run in parallel safely
- **SQLite In-Memory**: Fast, isolated test database
- **Comprehensive Mocking**: All external services mockable
- **Swift Testing**: Modern testing framework with `@Test` and `#expect`

## External Integrations

### OpenAI Integration

Uses the modern Responses API (`/v1/responses`), NOT deprecated Chat Completions:

```swift
struct OpenAIRequest {
    let input: InputContent
    let instructions: String
    let temperature: Double
    let maxOutputTokens: Int
}

// Usage
let request = OpenAIRequest(
    input: .text(gameTitle),
    instructions: "Generate comprehensive game rules...",
    temperature: 0.7,
    maxOutputTokens: 2000
)

let response = try await openAIService.generateResponse(request)
let text = response.extractText()  // No backward compatibility
```

### Redis Caching

High-performance caching for AI responses:

```swift
// Cache key generation
func generateCacheKey(for content: String, context: String) -> String {
    let hash = SHA256.hash(data: content.data(using: .utf8)!)
    return "\(context)_\(hash.hex)"
}

// Cache operations
try await cache.set(key, value: response, ttl: 3600)
if let cached = try await cache.get(key, as: Response.self) {
    return cached
}
```

### Email Service (Brevo)

```swift
protocol EmailServiceInterface {
    func sendVerificationEmail(to: String, token: String) async throws
    func sendPasswordResetEmail(to: String, resetLink: String) async throws
    func sendWelcomeEmail(to: String, name: String) async throws
}
```

## Security Architecture

### AI Security Pipeline

Multi-layer security for AI interactions:

1. **Input Sanitization**: Remove dangerous characters
2. **Injection Detection**: Pattern-based detection
3. **Content Validation**: Structural validation
4. **Response Validation**: AI output scanning

```swift
// Security validation example
let sanitized = try sanitizer.sanitize(input)
try validator.detectInjection(sanitized)
let response = try await llm.generate(sanitized)
try validator.validateResponse(response)
```

### Rate Limiting

Operation-specific rate limits:

```yaml
Rate Limits:
  - Image Analysis: 5/hour per IP
  - Rules Generation: 10/hour per IP
  - General API: 100/hour per IP
  - Admin Endpoints: No limit (authenticated)
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
  Database: SQLite in-memory
  Logging: Debug level
  Security: Relaxed for testing
  
Testing:
  Database: SQLite in-memory
  Services: All mocked
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
- **Use Case Colocation**: Business logic within modules
- **Service Simplicity**: Direct registration over factories
- **Framework Alignment**: Work with Vapor conventions
- **Three-Strike Rule**: Create abstractions on third occurrence

## Architectural Guidelines

### Design Principles

1. **Single Responsibility**: Each component has one clear purpose
2. **Dependency Inversion**: Depend on abstractions, not concretions
3. **Interface Segregation**: Small, focused interfaces
4. **Open/Closed**: Open for extension, closed for modification
5. **Liskov Substitution**: Subtypes replaceable without breaking

### Best Practices

1. **Never use static methods** - Always create services with DI
2. **Maintain module boundaries** - Complete vertical slices
3. **Colocate use cases** - Business logic within modules
4. **Mock everything** - All services must be testable
5. **Use framework conventions** - Work with Vapor, not against it

### Anti-Patterns to Avoid

- Separating use cases from modules
- Creating abstractions before third use
- Using complex patterns when simple suffice
- Static service methods
- Business logic in controllers

## Migration Notes

### From Legacy Patterns

```swift
// OLD: Vapor service pattern
app.services.userService.use(UserService.init)
let service = request.application.services.userService.service

// NEW: ServiceRegistry pattern
registry.register(UserService.self) { app in
    return UserService(database: app.db)
}
let service = try await request.resolveService(UserService.self)
```

### Testing Migration

```swift
// OLD: XCTest with manual setup
class UserTests: XCTestCase {
    var app: Application!
    override func setUp() { /* complex setup */ }
}

// NEW: Swift Testing with IsolatedTestWorld
@Suite(.serialized)
struct UserTests {
    let testWorld: IsolatedTestWorld
    init() async throws {
        testWorld = try await IsolatedTestWorld()
    }
}
```

## Future Considerations

### Potential Enhancements

1. **GraphQL API**: Alternative to REST endpoints
2. **WebSocket Support**: Real-time features
3. **Background Jobs**: Queue system for async processing
4. **Multi-tenancy**: Organization-based isolation
5. **API Versioning**: Backward compatibility strategy

### Scalability Path

1. **Horizontal Scaling**: Stateless design ready
2. **Database Sharding**: Partition strategy defined
3. **Cache Distribution**: Redis cluster ready
4. **Load Balancing**: Compatible architecture
5. **Microservices**: Module boundaries enable extraction

---

This technical architecture provides a comprehensive foundation for development, testing, and maintenance of the Project Rulebook application. All components follow established patterns, maintain clear boundaries, and prioritize testability and security.