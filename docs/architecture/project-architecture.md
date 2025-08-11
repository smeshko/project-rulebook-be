# Project Architecture Documentation

This document serves as a comprehensive architectural guide for AI subagents working on this Vapor 4 Swift web application. It provides detailed information about the system's structure, patterns, and guidelines for extending the codebase.

## Architecture Overview

### Core Architecture Pattern
This application follows a **modular monolith architecture** with three key patterns:

1. **ModuleInterface Protocol**: All functionality is organized into self-contained modules
2. **Repository Pattern**: Data access is abstracted through repository interfaces in each module
3. **Service Layer**: External services and cross-cutting concerns are abstracted through service interfaces

### Design Principles
- **SOLID principles** with emphasis on Single Responsibility and Dependency Inversion
- **Composition over inheritance** for better testability and maintainability
- **Interface segregation** through protocol-based abstractions
- **Dependency injection** using Vapor's Application.Service framework

## Module System Guidelines

### When to Create Modules
Create a new module when you need:
- **New endpoints that are logically different** from existing ones
- A distinct domain area with its own business logic
- Separate authentication or authorization requirements
- Independent data models and operations

### Current Modules Inventory

#### 1. **UserModule** (`Sources/App/Modules/User/`)
- **Purpose**: User account management and profile operations
- **Endpoints**: User registration, profile management, account settings
- **Components**: UserController, UserRepository, UserAccountModel

#### 2. **AuthModule** (`Sources/App/Modules/Auth/`)
- **Purpose**: Authentication, JWT tokens, email verification, password reset
- **Endpoints**: Login, logout, token refresh, email verification, password reset
- **Components**: AuthController, RefreshTokenRepository, EmailTokenRepository, PasswordTokenRepository

#### 3. **FrontendModule** (`Sources/App/Modules/Frontend/`)
- **Purpose**: HTML rendering, forms, and web interface using SwiftHtml
- **Endpoints**: Web pages, form handling, template rendering
- **Components**: FrontendController, form validation framework, template system

#### 4. **RulesGenerationModule** (`Sources/App/Modules/RulesGeneration/`)
- **Purpose**: AI-powered game rules generation functionality
- **Endpoints**: Rules generation requests, game analysis
- **Components**: RulesController, AI integration with LLM services

#### 5. **CacheAdminModule** (`Sources/App/Modules/CacheAdmin/`)
- **Purpose**: AI response cache management for cost optimization
- **Endpoints**: Cache statistics, cache invalidation, cost monitoring
- **Components**: CacheAdminController, AICacheService integration

### Module Structure Template
```
Sources/App/Modules/[ModuleName]/
├── Controllers/
│   └── [ModuleName]Controller.swift
├── Database/
│   ├── Models/
│   │   └── [Entity]Model.swift
│   ├── Migrations/
│   │   └── Create[Entity].swift
│   └── Repositories/
│       ├── [Entity]Repository.swift (protocol)
│       └── Database[Entity]Repository.swift (implementation)
└── [ModuleName]Module.swift (implements ModuleInterface)
```

## Service Layer Guidelines

### When to Create Services
Create a new service when you need:
- **Internal functionality accessed from within endpoints**
- External API integrations (email, AI, payment processors)
- Cross-cutting concerns (logging, caching, validation)
- Business logic that spans multiple modules

### Current Services Inventory

#### 1. **EmailService** (`Sources/App/Services/Email/`)
- **Purpose**: Transactional email sending via Brevo
- **Interface**: `EmailServiceInterface`
- **Implementation**: `BrevoEmailService`
- **Registration**: `services.email.use(.brevo)`

#### 2. **LLMService** (`Sources/App/Services/LLM/`)
- **Purpose**: AI/LLM integration with OpenAI
- **Interface**: `LLMServiceInterface`
- **Implementation**: `OpenAILLMService`
- **Registration**: `services.llm.use(.openAI)`

#### 3. **AICacheService** (`Sources/App/Services/Cache/`)
- **Purpose**: AI response caching for cost optimization
- **Interface**: `AICacheServiceInterface`
- **Implementation**: `InMemoryAICacheService`
- **Registration**: `services.aiCache.use(.inMemory)`

#### 4. **Utility Services**
- **RandomGeneratorService**: Secure random value generation (`services.randomGenerator.use(.random)`)
- **UUIDGeneratorService**: UUID generation abstraction (`services.uuidGenerator.use(.random)`)
- **IPExtractorService**: Client IP address extraction (`services.ipExtractor.use(.default)`)

### Service Registration Pattern
Services are registered in `setupServices()` method in `Application-Setup.swift`:

```swift
func setupServices() throws {
    // Repository services
    repositories.usersService.use { app in DatabaseUserRepository(database: app.db) }
    repositories.emailTokensService.use { app in DatabaseEmailTokenRepository(database: app.db) }
    
    // External services
    services.email.use(.brevo)
    services.llm.use(.openAI)
    services.aiCache.use(.inMemory)
}
```

Each service is split into 2 parts, an interface with Application/Request integration:

`LLMService.swift:`
```swift
protocol LLMService {
    func generate(input: [OpenAIRequest.Message]) async throws -> String

    func `for`(_ request: Request) -> LLMService
}

extension Application.Services {
    var llm: Application.Service<LLMService> {
        .init(application: application)
    }
}

extension Request.Services {
    var llm: LLMService {
        self.request.application.services.llm.service.for(request)
    }
}
```

and a concrete implementation. 
`OpenAIService.swift:`
```swift
extension Application.Service.Provider where ServiceType == LLMService {
    static var openAI: Self {
        .init {
            $0.services.llm.use { OpenAIService(app: $0) }
        }
    }
}
... concrete implementation
```

## File Organization Patterns

### Database Models
- **Location**: `Sources/App/Modules/[ModuleName]/Database/Models/`
- **Naming**: Suffix with "Model" (e.g., `UserAccountModel`, `RefreshTokenModel`)
- **Pattern**: One model per file
- **Structure**: Fluent model with relationships, validation, and migrations

### Errors
- **Location**: `Sources/App/Entities/Errors/`
- **Naming**: `[DomainName]Error.swift` (e.g., `AuthenticationError.swift`, `UserError.swift`)
- **Pattern**: Centralized error definitions implementing `AbortError`
- **Structure**: Enum-based errors with HTTP status codes

### Repository Interfaces
- **Location**: `Sources/App/Modules/[ModuleName]/Repositories/`
- **Naming**: `[Entity]Repository.swift` (protocol) and `Database[Entity]Repository.swift` (implementation)
- **Pattern**: Protocol definition with database-specific implementation in same module
- **Registration**: Via `Application.Repositories` extensions

### Migrations
- **Location**: `Sources/App/Modules/[ModuleName]/Database/Migrations/`
- **Naming**: `Create[Entity].swift`, `Update[Entity]V2.swift`
- **Pattern**: Versioned migrations with rollback support

## Current System Inventory

### Authentication Components
- **UserCredentialsAuthenticator**: Email/password authentication middleware
- **UserPayloadAuthenticator**: JWT token validation middleware
- **JWT Management**: Access and refresh token handling
- **App Attest Integration**: Device verification for enhanced security

### Security Middleware Stack
1. **CORS Middleware**: Cross-origin request handling with configurable origins
2. **Rate Limiting**: Request throttling (RateLimitMiddleware)
3. **Security Headers**: HSTS, CSP, and other security headers (SecurityHeadersMiddleware)
4. **Authentication Middleware**: JWT validation and user context
5. **Error Handling**: Custom error middleware with environment-based responses

### Database Models (by Module)
- **User Module**: `UserAccountModel`
- **Auth Module**: `RefreshTokenModel`, `EmailTokenModel`, `PasswordTokenModel`
- **Cache Module**: AI response caching structures

### External Integrations
- **Brevo Email Service**: Transactional email delivery
- **OpenAI Integration**: GPT-based content generation
- **Database**: PostgreSQL (staging/production), SQLite (development/testing)

## Development Guidelines

### Extending Existing Modules
1. **Add new endpoints**: Extend existing controllers with new routes
2. **Database changes**: Create new migrations, don't modify existing ones
3. **Repository methods**: Add new methods to repository interfaces and implementations
4. **Error handling**: Add new error cases to centralized error files in `Entities/Errors/`

### Creating New Services
1. **Define interface**: Create protocol in `Sources/App/Services/[ServiceName]/`
2. **Implement service**: Create concrete implementation in same directory
3. **Create Application.Services extension**: Add service accessor and key
4. **Register service**: Add to `setupServices()` in `Application-Setup.swift`
5. **Add tests**: Create mock implementation for testing

### Creating New Modules
1. **Create module directory structure** following the template
2. **Implement ModuleInterface**: Create `[ModuleName]Module.swift`
3. **Add to module list**: Register in `setupModules()` in `Application-Setup.swift`
4. **Create repositories**: Define protocols and database implementations
5. **Add error handling**: Create error cases in `Entities/Errors/`

### Database Migration Best Practices
1. **Never modify existing migrations** - always create new ones
2. **Use descriptive names** with version numbers
3. **Include rollback logic** in `revert()` method
4. **Test migrations** against production-like data
5. **Document schema changes** in migration comments

### Testing Strategy
- **TestWorld**: Centralized test environment setup
- **Mock Services**: In-memory implementations for all external services
- **Repository Mocks**: In-memory database operations
- **HTTP Testing**: XCTVapor for endpoint testing
- **Unit Testing**: Business logic testing with dependency injection

## Integration Patterns

### Request Flow Architecture
```
HTTP Request → Middleware Stack → Router → Controller → Service/Repository → Database/External API
```

### Dependency Injection Patterns
1. **Application Level**: Services registered via `Application.Services` extensions
2. **Repository Level**: Registered via `Application.Repositories` extensions
3. **Request Level**: Accessed through `Request.Services` and `Request.Repositories`
4. **Controller Level**: Service and repository injection through request context

### Repository Registration Pattern
```swift
// Repository Protocol (in module)
protocol UserRepository: Repository {
    func find(id: UUID) async throws -> UserAccountModel?
}

// Database Implementation (in module)
struct DatabaseUserRepository: UserRepository, DatabaseRepository {
    let database: Database
}

// Application Extension
extension Application.Repositories {
    var users: any UserRepository { usersService.service }
    var usersService: Application.Service<any UserRepository> {
        .init(application: application)
    }
}

// Request Extension
extension Request.Services {
    var users: any UserRepository { request.application.repositories.users }
}
```

### Error Handling Strategy
1. **Centralized Errors**: Domain-specific errors in `Entities/Errors/`
2. **Error Middleware**: Global error handling and logging
3. **Validation Errors**: Form and request validation with user-friendly messages
4. **External Service Errors**: Wrapped and transformed for consistent handling

### Configuration Management
- **Environment Detection**: Automatic environment-based configuration
- **ConfigurationService**: Environment-specific service implementations
- **Database Configuration**: Auto-switching between SQLite and PostgreSQL
- **Security Configuration**: Environment-appropriate security settings

## Security Architecture

### Authentication Flow
1. **Credential Authentication**: Email/password validation via `UserCredentialsAuthenticator`
2. **JWT Generation**: Access and refresh token creation
3. **Token Validation**: Middleware-based token verification via `UserPayloadAuthenticator`
4. **Session Management**: Refresh token rotation and invalidation

### Data Protection
- **Password Hashing**: Bcrypt-based secure password storage
- **Token Security**: Cryptographically secure token generation
- **Input Validation**: Comprehensive request validation
- **SQL Injection Prevention**: Fluent ORM query building

## Database Architecture

### Schema Design Principles
- **Normalized Structure**: Proper relationship modeling
- **Audit Fields**: Created/updated timestamps on all models
- **Soft Deletes**: Where appropriate for data retention
- **Indexing Strategy**: Performance-optimized database indexes

### Environment-Specific Configuration
- **Development**: SQLite in-memory database
- **Testing**: Isolated SQLite databases per test
- **Staging/Production**: PostgreSQL with TLS configuration

## Testing Strategy

### Test Categories
1. **Unit Tests**: Service and business logic testing
2. **Integration Tests**: Database and external service integration
3. **HTTP Tests**: Endpoint testing with XCTVapor
4. **Mock Testing**: In-memory service implementations

### TestWorld Pattern
- **Centralized Setup**: Single test environment configuration
- **Service Mocking**: Automatic mock service registration
- **Database Setup**: Clean database state per test
- **Authentication Helpers**: Test user creation and authentication

## AI Subagent Guidelines

### Patterns to Follow
1. **Use repository protocols** defined in module directories, not in Common/Framework
2. **Follow the service registration pattern** with Application.Services extensions
3. **Place errors in centralized location** (`Entities/Errors/`) not module-specific
4. **Register new modules** in `setupModules()` in Application-Setup.swift
5. **Create tests** for all new functionality with proper mocks

### Patterns to Avoid
1. **Don't create service protocols in Common/Framework** - they belong in service directories
2. **Don't create module-specific error files** - use centralized `Entities/Errors/`
3. **Don't bypass repository interfaces** with direct database access
4. **Don't modify existing migrations** - create new ones
5. **Don't ignore the modular structure** - respect boundaries

### Service Creation Checklist
1. Create service interface and implementation in `Sources/App/Services/[ServiceName]/`
2. Add `Application.Services` extension with service accessor
3. Add `Application.ServiceKey` definition
4. Register service in `setupServices()` using `.use()` pattern
5. Create mock implementation for testing
6. Add service to TestWorld for test integration

### Module Creation Checklist
1. Create directory structure following template
2. Implement `ModuleInterface` with `boot()` and `setUp()` methods
3. Create repository protocols and database implementations
4. Add error cases to appropriate file in `Entities/Errors/`
5. Register module in `setupModules()` array
6. Create comprehensive tests with mocks

This architecture documentation provides the foundation for maintaining and extending the codebase while preserving its modular, testable, and maintainable design principles.