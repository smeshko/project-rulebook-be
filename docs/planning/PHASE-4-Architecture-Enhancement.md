# Phase 4: Architecture Enhancement

**Status**: 📋 PLANNED  
**Timeline**: 2-3 weeks  
**Priority**: P1 (High)  
**Prerequisites**: Phase 3 (Testing Infrastructure)

## 🎯 Objective

Improve system architecture by implementing proper service registry, refactoring controllers to use clean architecture patterns, and establishing cross-cutting concerns framework for consistent behavior across modules.

## 📋 Task 4.1: Service Registry & Dependency Injection

**Timeline**: 3-4 days | **Complexity**: Medium

### Current Issues
- Service registration is scattered across codebase
- Tight coupling between services and application
- No centralized service discovery mechanism
- Difficult to mock services for testing

### Implementation Plan

#### Step 1: Create ServiceRegistry Protocol
```swift
protocol ServiceRegistry {
    func register<T>(_ type: T.Type, factory: @escaping (Application) -> T)
    func resolve<T>(_ type: T.Type) -> T?
    func resolveAll<T>(_ type: T.Type) -> [T]
}

protocol ServiceLifecycle {
    func startup() async throws
    func shutdown() async throws
}
```

#### Step 2: Implement Service Container
```swift
final class ServiceContainer: ServiceRegistry {
    private var services: [ObjectIdentifier: Any] = [:]
    private var factories: [ObjectIdentifier: (Application) -> Any] = [:]
    
    func register<T>(_ type: T.Type, factory: @escaping (Application) -> T) {
        factories[ObjectIdentifier(type)] = factory
    }
    
    func resolve<T>(_ type: T.Type) -> T? {
        // Lazy initialization with caching
    }
}
```

#### Step 3: Auto-Discovery Pattern
```swift
@ServiceDiscoverable
class EmailService: Service {
    static let serviceIdentifier = "email"
}

// Automatic registration via reflection or build plugin
```

#### Step 4: Refactor Existing Services
- Migrate all services to new registry
- Update injection points in controllers
- Add lifecycle management
- Create service health checks

### Success Criteria
- ✅ All services registered centrally
- ✅ Services easily mockable for tests
- ✅ Dependency graph clearly visible
- ✅ Service lifecycle properly managed

---

## 📋 Task 4.2: Controller Architecture Refactoring

**Timeline**: 4-5 days | **Complexity**: High

### Current Issues
- Controllers contain business logic
- Mixed responsibilities (validation, transformation, persistence)
- Difficult to unit test business logic
- Code duplication across similar operations

### Implementation Plan

#### Step 1: Implement Use Case Pattern
```swift
// Domain layer
protocol SignUpUseCase {
    func execute(_ request: SignUpRequest) async throws -> SignUpResponse
}

// Application layer
final class SignUpUseCaseImpl: SignUpUseCase {
    let userRepository: UserRepository
    let emailService: EmailService
    let tokenGenerator: TokenGenerator
    
    func execute(_ request: SignUpRequest) async throws -> SignUpResponse {
        // Pure business logic here
    }
}
```

#### Step 2: Create Command/Query Separation
```swift
// Commands (mutations)
protocol Command {
    associatedtype Response
    func execute() async throws -> Response
}

// Queries (reads)
protocol Query {
    associatedtype Result
    func execute() async throws -> Result
}
```

#### Step 3: Implement Domain Services
```swift
final class AuthenticationService {
    func validateCredentials(_ credentials: Credentials) async throws -> User
    func generateTokens(for user: User) async throws -> TokenPair
    func invalidateTokens(for user: User) async throws
}
```

#### Step 4: Refactor All Controllers
- Extract business logic to use cases
- Controllers only handle HTTP concerns
- Implement request/response mapping
- Add consistent error handling

### Example Refactored Controller
```swift
final class AuthController {
    let signUpUseCase: SignUpUseCase
    let signInUseCase: SignInUseCase
    
    func signUp(_ req: Request) async throws -> Response {
        let dto = try req.content.decode(SignUpDTO.self)
        let request = SignUpRequest(from: dto)
        let result = try await signUpUseCase.execute(request)
        return try await result.encodeResponse(for: req)
    }
}
```

### Success Criteria
- ✅ Zero business logic in controllers
- ✅ Use cases testable in isolation
- ✅ Clear separation of concerns
- ✅ Reduced code duplication by 40%

---

## 📋 Task 4.3: Cross-Cutting Concerns Framework

**Timeline**: 3-4 days | **Complexity**: Medium

### Current Issues
- Authentication applied inconsistently
- Logging scattered throughout code
- Validation logic duplicated
- No centralized error handling

### Implementation Plan

#### Step 1: Implement Aspect-Oriented Middleware
```swift
protocol Aspect {
    func before(_ request: Request) async throws
    func after(_ request: Request, _ response: Response) async throws
    func onError(_ request: Request, _ error: Error) async throws
}

final class LoggingAspect: Aspect {
    func before(_ request: Request) async throws {
        request.logger.info("Request: \(request.method) \(request.url)")
    }
}
```

#### Step 2: Create Validation Framework
```swift
@propertyWrapper
struct Validated<T: Validatable> {
    var wrappedValue: T {
        didSet { try? wrappedValue.validate() }
    }
}

protocol ValidationRule {
    func validate(_ value: Any) throws
}
```

#### Step 3: Implement Correlation ID Tracking
```swift
extension Request {
    var correlationID: String {
        headers.first(name: "X-Correlation-ID") ?? UUID().uuidString
    }
}

struct CorrelationMiddleware: AsyncMiddleware {
    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        request.logger = request.logger.with(metadataKey: "correlation-id", value: request.correlationID)
        let response = try await next.respond(to: request)
        response.headers.add(name: "X-Correlation-ID", value: request.correlationID)
        return response
    }
}
```

#### Step 4: Unified Error Handling
```swift
final class ErrorHandlingAspect: Aspect {
    func onError(_ request: Request, _ error: Error) async throws {
        let errorResponse = ErrorResponseBuilder.build(from: error)
        request.logger.error("Error: \(error)", metadata: ["correlation-id": request.correlationID])
        throw errorResponse
    }
}
```

### Success Criteria
- ✅ Consistent logging across all requests
- ✅ Validation rules centralized and reusable
- ✅ All requests have correlation IDs
- ✅ Error handling standardized

---

## 🏗️ Architecture After Phase 4

### Clean Architecture Layers
```
┌─────────────────────────────────┐
│      Presentation Layer         │ ← Controllers, DTOs
├─────────────────────────────────┤
│      Application Layer          │ ← Use Cases, Commands/Queries
├─────────────────────────────────┤
│        Domain Layer             │ ← Entities, Domain Services
├─────────────────────────────────┤
│     Infrastructure Layer        │ ← Repositories, External Services
└─────────────────────────────────┘
```

### Service Architecture
```
ServiceRegistry
    ├── EmailService
    ├── LLMService
    ├── CacheService
    ├── AuthenticationService
    └── [Future Services]
```

### Request Flow
```
Request → Middleware Chain → Controller → Use Case → Domain Service → Repository
                ↓                             ↓
           Aspects (Logging, Validation, Auth, Error Handling)
```

## 📊 Implementation Schedule

### Week 1
- **Days 1-3**: Service Registry implementation
- **Day 4**: Begin controller refactoring

### Week 2
- **Days 1-4**: Complete controller refactoring
- **Day 5**: Begin cross-cutting concerns

### Week 3
- **Days 1-2**: Complete cross-cutting concerns
- **Days 3-4**: Integration and testing
- **Day 5**: Documentation and review

## 🎯 Definition of Done

### Task 4.1 (Service Registry)
- [ ] ServiceRegistry protocol implemented
- [ ] All services migrated to registry
- [ ] Service lifecycle management working
- [ ] Tests updated for new patterns

### Task 4.2 (Controller Refactoring)
- [ ] All controllers refactored
- [ ] Use cases extracted and tested
- [ ] Domain services implemented
- [ ] Zero business logic in controllers

### Task 4.3 (Cross-Cutting Concerns)
- [ ] Aspect framework implemented
- [ ] Validation framework created
- [ ] Correlation ID tracking active
- [ ] Unified error handling working

### Overall Phase 4
- [ ] Architecture documentation updated
- [ ] All tests passing
- [ ] Performance benchmarks met
- [ ] Code review completed
- [ ] Merged to main branch

---

*Phase Start: After Phase 3*  
*Estimated Duration: 2-3 weeks*  
*Next Phase: Performance & Reliability*