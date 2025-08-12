# ServiceRegistry Developer Guide

## Overview

The ServiceRegistry system provides centralized service management, dependency injection, and lifecycle control for the Project Rulebook application. This guide covers everything developers need to know about using and extending the ServiceRegistry.

## 🏗️ Architecture

### Core Components

```
ServiceRegistry System
├── ServiceRegistry (Protocol)          # Core interface for service management
├── ServiceContainer (Implementation)   # Thread-safe service resolution
├── ServiceLifecycle (Protocol)        # Service startup/shutdown management
├── ServiceHealthCheck (Protocol)      # Health monitoring interface
├── ServiceProvider (Protocol)         # Service registration pattern
└── Application Integration            # Vapor app and request extensions
```

### Key Features

- **Thread-Safe Resolution**: Uses NIOLock for concurrent access safety
- **Lazy Initialization**: Services created on-demand with singleton caching
- **Lifecycle Management**: Automatic startup/shutdown hooks
- **Health Monitoring**: Built-in health checks for service reliability
- **Request Integration**: Direct service injection from Request objects
- **Comprehensive Testing**: Full mockability and testing support

## 🚀 Getting Started

### Basic Service Resolution

The most common usage pattern is resolving services in controllers:

```swift
// In your controller
func handleRequest(_ request: Request) async throws -> Response {
    // Resolve required service (throws if not found)
    let userRepo = try await request.resolveService(any UserRepository.self)
    
    // Resolve optional service (returns nil if not found)
    let llmService = try await request.resolveServiceOptional(LLMService.self)
    
    // Use the services
    let user = try await userRepo.find(id: userId)
    // ...
}
```

### Service Registration

Services are registered using the ServiceProvider pattern:

```swift
// Create a service provider
struct UserServiceProvider: ServiceProvider {
    static func register(in registry: ServiceContainer, app: Application) async throws {
        // Register with factory function
        registry.register(UserService.self) { app in
            return UserService(
                database: app.db,
                configuration: app.configuration
            )
        }
        
        // Register existing instance
        let existingService = ExistingService()
        registry.register(ExistingService.self, instance: existingService)
    }
}

// Register in application setup
try await UserServiceProvider.register(in: app.serviceRegistry, app: app)
```

## 🛠️ Service Implementation Patterns

### Basic Service

```swift
// Simple service implementation
final class EmailService {
    private let apiKey: String
    
    init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    func sendEmail(to recipient: String, subject: String, body: String) async throws {
        // Implementation
    }
}

// Registration
registry.register(EmailService.self) { app in
    EmailService(apiKey: app.configuration.emailAPIKey)
}
```

### Service with Lifecycle Management

```swift
// Service that needs startup/shutdown hooks
final class DatabaseConnectionService: ServiceLifecycle {
    private var connection: DatabaseConnection?
    
    func startup(_ app: Application) async throws {
        connection = try await DatabaseConnection.connect(
            url: app.configuration.databaseURL
        )
        app.logger.info("Database connection established")
    }
    
    func shutdown(_ app: Application) async throws {
        try await connection?.close()
        app.logger.info("Database connection closed")
    }
    
    func query(_ sql: String) async throws -> [Row] {
        guard let connection = connection else {
            throw DatabaseError.notConnected
        }
        return try await connection.query(sql)
    }
}
```

### Service with Health Checks

```swift
// Service with health monitoring
final class LLMService: ServiceHealthCheck {
    private let apiClient: APIClient
    
    func healthCheckName() -> String {
        "LLM Service"
    }
    
    func isHealthy() async -> Bool {
        do {
            // Perform health check (e.g., ping API)
            _ = try await apiClient.ping()
            return true
        } catch {
            return false
        }
    }
    
    func generateRules(for game: String) async throws -> String {
        // Implementation
    }
}
```

### Full-Featured Service

```swift
// Service implementing all protocols
final class CacheService: ServiceLifecycle, ServiceHealthCheck {
    private var cache: Cache?
    private var isRunning = false
    
    // MARK: - ServiceLifecycle
    
    func startup(_ app: Application) async throws {
        cache = try Cache(configuration: app.configuration.cacheConfig)
        isRunning = true
        app.logger.info("Cache service started")
    }
    
    func shutdown(_ app: Application) async throws {
        isRunning = false
        try await cache?.shutdown()
        app.logger.info("Cache service stopped")
    }
    
    // MARK: - ServiceHealthCheck
    
    func healthCheckName() -> String {
        "Cache Service"
    }
    
    func isHealthy() async -> Bool {
        isRunning && cache?.isConnected == true
    }
    
    // MARK: - Service Methods
    
    func get<T: Codable>(_ key: String, as type: T.Type) async throws -> T? {
        try await cache?.get(key, as: type)
    }
    
    func set<T: Codable>(_ key: String, value: T, ttl: TimeInterval) async throws {
        try await cache?.set(key, value: value, ttl: ttl)
    }
}
```

## 🧪 Testing with ServiceRegistry

### Unit Testing

```swift
final class UserServiceTests: XCTestCase {
    var testCase: UnitTestCase!
    var app: Application { testCase.application }
    
    override func setUp() async throws {
        testCase = try await UnitTestCase()
        
        // Register test services
        try await setupTestServices()
    }
    
    override func tearDown() async throws {
        try await testCase.shutdown()
    }
    
    private func setupTestServices() async throws {
        // Register mock services for testing
        app.serviceRegistry.register(UserRepository.self, instance: MockUserRepository())
        app.serviceRegistry.register(EmailService.self, instance: MockEmailService())
    }
    
    func testUserRegistration() async throws {
        // Create mock request
        let request = Request(application: app, on: app.eventLoopGroup.next())
        
        // Resolve services (will get mocks)
        let userRepo = try await request.resolveService(any UserRepository.self)
        let emailService = try await request.resolveService(EmailService.self)
        
        // Test your logic
        // ...
    }
}
```

### Integration Testing

```swift
final class ServiceRegistryIntegrationTests: XCTestCase {
    var testCase: IntegrationTestCase!
    var app: Application { testCase.application }
    
    override func setUp() async throws {
        testCase = try await IntegrationTestCase()
    }
    
    override func tearDown() async throws {
        try await testCase.shutdown()
    }
    
    func testServiceLifecycleManagement() async throws {
        // Register services
        try await app.setupServiceRegistry()
        
        // Test service resolution
        let userRepo = try await app.serviceRegistry.resolveRequired(any UserRepository.self)
        XCTAssertNotNil(userRepo)
        
        // Test health checks
        let healthChecks = await app.serviceRegistry.healthCheckAll()
        XCTAssertFalse(healthChecks.isEmpty)
        
        // Test shutdown
        try await app.shutdownServiceRegistry()
    }
}
```

### Mock Services

```swift
// Mock implementation for testing
final class MockUserRepository: UserRepository {
    var users: [UUID: User] = [:]
    
    func create(_ user: User) async throws -> User {
        users[user.id] = user
        return user
    }
    
    func find(id: UUID) async throws -> User? {
        return users[id]
    }
    
    func find(email: String) async throws -> User? {
        return users.values.first { $0.email == email }
    }
    
    func update(_ user: User) async throws -> User {
        users[user.id] = user
        return user
    }
    
    func delete(id: UUID) async throws {
        users.removeValue(forKey: id)
    }
}
```

## 🔧 Application Integration

### Startup Configuration

```swift
// In your main application setup
public func configure(_ app: Application) async throws {
    // ... other configuration
    
    // Setup ServiceRegistry and register all services
    try await app.setupServiceRegistry()
    
    // Register shutdown hook
    app.lifecycle.use {
        try await app.shutdownServiceRegistry()
    }
}
```

### Custom Service Providers

```swift
// Group related services into providers
struct DatabaseServiceProvider: ServiceProvider {
    static func register(in registry: ServiceContainer, app: Application) async throws {
        // User repository
        registry.register(any UserRepository.self) { app in
            return UserDatabaseRepository(database: app.db)
        }
        
        // Token repositories
        registry.register(any RefreshTokenRepository.self) { app in
            return RefreshTokenDatabaseRepository(database: app.db)
        }
        
        registry.register(any EmailTokenRepository.self) { app in
            return EmailTokenDatabaseRepository(database: app.db)
        }
    }
}

struct ExternalServiceProvider: ServiceProvider {
    static func register(in registry: ServiceContainer, app: Application) async throws {
        // Email service
        registry.register(EmailService.self) { app in
            return EmailService(
                apiKey: app.configuration.brevoAPIKey,
                logger: app.logger
            )
        }
        
        // LLM service
        registry.register(LLMService.self) { app in
            return LLMService(
                apiKey: app.configuration.openAIAPIKey,
                httpClient: app.http.client.shared
            )
        }
    }
}
```

## 📊 Monitoring and Health Checks

### Accessing Health Status

```swift
// Check health of all services
let healthChecks = await app.serviceRegistry.healthCheckAll()

for check in healthChecks {
    if check.healthy {
        app.logger.info("Service \(check.name): ✅ Healthy")
    } else {
        app.logger.warning("Service \(check.name): ⚠️ Unhealthy")
    }
}
```

### Custom Health Check Endpoint

```swift
// Create a health check endpoint
func healthCheck(_ request: Request) async throws -> HealthCheckResponse {
    let checks = await request.application.serviceRegistry.healthCheckAll()
    
    let response = HealthCheckResponse(
        status: checks.allSatisfy(\.healthy) ? "healthy" : "degraded",
        services: checks.map { service in
            ServiceHealthStatus(
                name: service.name,
                status: service.healthy ? "up" : "down"
            )
        }
    )
    
    return response
}
```

## ⚠️ Error Handling

### ServiceRegistry Errors

```swift
// Handle service resolution errors
do {
    let service = try await request.resolveService(RequiredService.self)
    // Use service
} catch let error as ServiceRegistryError {
    switch error {
    case .serviceNotFound(let type):
        request.logger.error("Service not found: \(type)")
        throw Abort(.internalServerError, reason: "Required service unavailable")
    
    case .serviceInitializationFailed(let type, let underlyingError):
        request.logger.error("Service initialization failed: \(type), error: \(underlyingError)")
        throw Abort(.internalServerError, reason: "Service initialization error")
    
    case .circularDependency(let chain):
        request.logger.error("Circular dependency detected: \(chain)")
        throw Abort(.internalServerError, reason: "Service configuration error")
    
    case .factoryTypeMismatch(let type):
        request.logger.error("Factory type mismatch: \(type)")
        throw Abort(.internalServerError, reason: "Service configuration error")
    }
}
```

## 🔐 Security Considerations

### Service Isolation

- Services should be stateless where possible
- Avoid storing user-specific data in singleton services
- Use request-scoped services for user context

```swift
// DON'T: Store user state in singleton service
final class BadUserService {
    var currentUser: User? // ❌ Global state
}

// DO: Pass user context to methods
final class GoodUserService {
    func processUser(_ user: User) async throws -> ProcessedUser {
        // ✅ Stateless operation
    }
}
```

### Dependency Validation

- Validate service dependencies at startup
- Fail fast if critical services are missing
- Use health checks to monitor service availability

```swift
// Validate critical services at startup
try await app.setupServiceRegistry()

// Ensure critical services are available
_ = try await app.serviceRegistry.resolveRequired(DatabaseService.self)
_ = try await app.serviceRegistry.resolveRequired(EmailService.self)

app.logger.info("All critical services validated successfully")
```

## 📈 Performance Considerations

### Service Resolution Performance

- Services are created lazily and cached as singletons
- Thread-safe resolution using NIOLock
- Minimal overhead for subsequent resolutions

### Memory Management

- Services are retained for application lifetime
- Implement proper cleanup in shutdown hooks
- Use weak references where appropriate to avoid cycles

```swift
// Avoid retain cycles in service dependencies
final class ServiceA {
    weak var serviceB: ServiceB? // ✅ Use weak reference if needed
    
    func configure(with serviceB: ServiceB) {
        self.serviceB = serviceB
    }
}
```

## 🎯 Best Practices

### 1. Service Design

- Keep services focused on single responsibilities
- Use dependency injection rather than service location
- Implement proper error handling and logging
- Make services testable with clear interfaces

### 2. Registration Patterns

- Group related services in service providers
- Register services in logical order (dependencies first)
- Use factory functions for services with dependencies
- Register instances only for stateless utilities

### 3. Testing

- Always provide mock implementations for tests
- Test service registration and resolution
- Verify lifecycle management in integration tests
- Use dedicated test service providers

### 4. Error Handling

- Handle service resolution failures gracefully
- Log service errors with appropriate context
- Provide meaningful error messages to clients
- Implement proper fallback strategies

This ServiceRegistry system provides a robust foundation for dependency injection and service management in the Project Rulebook application, enabling clean architecture patterns and comprehensive testing support.