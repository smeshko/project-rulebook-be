# Phase 5: Performance & Reliability

**Status**: 🔄 IN PROGRESS  
**Timeline**: 1-2 weeks  
**Priority**: P2 (Medium-High)  
**Prerequisites**: Phase 4 (Architecture Enhancement)

## 🎯 Objective

Optimize system performance through database query optimization, implement comprehensive caching strategy to reduce external API costs, and establish consistent error handling patterns for improved reliability.

## 📋 Task 5.1: Database Performance Optimization

**Timeline**: 3-4 days | **Complexity**: Medium

### Current Issues
- No database indexes defined
- Potential N+1 query problems in relationships
- No connection pooling configuration
- Missing query performance monitoring
- Inefficient repository query patterns

### Implementation Plan

#### Step 1: Add Database Indexes
```swift
// Migration for performance-critical indexes
struct AddPerformanceIndexes: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("users")
            .field("email", .string, .required)
            .unique(on: "email")
            .create()
        
        try await database.schema("refresh_tokens")
            .field("value", .string, .required)
            .field("user_id", .uuid, .required)
            .index(on: "value")
            .index(on: "user_id")
            .create()
        
        try await database.schema("email_tokens")
            .field("value", .string, .required)
            .index(on: "value")
            .create()
    }
}
```

#### Step 2: Optimize Repository Queries
```swift
// Before: N+1 problem
func getUsersWithTokens() async throws -> [User] {
    let users = try await User.query(on: db).all()
    for user in users {
        user.tokens = try await user.$tokens.query(on: db).all()
    }
    return users
}

// After: Eager loading
func getUsersWithTokens() async throws -> [User] {
    try await User.query(on: db)
        .with(\.$tokens)
        .all()
}
```

#### Step 3: Configure Connection Pooling
```swift
// Database configuration
app.databases.use(.postgres(
    hostname: config.database.host,
    port: config.database.port,
    username: config.database.username,
    password: config.database.password,
    database: config.database.name,
    maxConnectionsPerEventLoop: 2,
    connectionPoolTimeout: .seconds(30)
), as: .psql)
```

#### Step 4: Implement Query Monitoring
```swift
struct QueryPerformanceMiddleware: DatabaseMiddleware {
    func intercept(_ event: DatabaseEvent, on db: Database) async throws {
        let start = Date()
        defer {
            let duration = Date().timeIntervalSince(start)
            if duration > 0.1 { // Log slow queries
                db.logger.warning("Slow query (\(duration)s): \(event.query)")
            }
        }
        try await event.next()
    }
}
```

### Performance Targets
- Query response time < 50ms for 95% of queries
- Zero N+1 query problems
- Connection pool utilization < 80%
- Database CPU usage < 60%

### Success Criteria
- ✅ All critical tables have appropriate indexes
- ✅ Repository queries optimized with eager loading
- ✅ Connection pooling properly configured
- ✅ Query monitoring dashboard operational

---

## 📋 Task 5.2: Caching Strategy Implementation

**Timeline**: 2-3 days | **Complexity**: Medium

### Current Issues
- No caching for expensive operations
- Repeated API calls to OpenAI for same inputs
- No distributed caching mechanism
- Missing cache invalidation strategy

### Implementation Plan

#### Step 1: Integrate Redis
```swift
// Package.swift
.package(url: "https://github.com/vapor/redis.git", from: "4.0.0")

// Configuration
app.redis.configuration = try RedisConfiguration(
    hostname: config.cache.host,
    port: config.cache.port,
    password: config.cache.password,
    database: 0,
    pool: RedisConfiguration.PoolOptions(
        maximumConnectionCount: 10,
        minimumConnectionCount: 2
    )
)
```

#### Step 2: Implement Cache Service
```swift
protocol CacheService {
    func get<T: Codable>(_ key: String, as type: T.Type) async throws -> T?
    func set<T: Codable>(_ key: String, value: T, ttl: TimeInterval?) async throws
    func delete(_ key: String) async throws
    func flush() async throws
}

final class RedisCacheService: CacheService {
    let redis: RedisClient
    
    func get<T: Codable>(_ key: String, as type: T.Type) async throws -> T? {
        guard let data = try await redis.get(key, as: Data.self) else { return nil }
        return try JSONDecoder().decode(type, from: data)
    }
    
    func set<T: Codable>(_ key: String, value: T, ttl: TimeInterval? = nil) async throws {
        let data = try JSONEncoder().encode(value)
        if let ttl = ttl {
            try await redis.setex(key, to: data, expirationInSeconds: Int(ttl))
        } else {
            try await redis.set(key, to: data)
        }
    }
}
```

#### Step 3: Cache LLM Responses
```swift
final class CachedLLMService: LLMService {
    let llmService: LLMService
    let cache: CacheService
    
    func generate(input: [OpenAIRequest.Message]) async throws -> String {
        // Generate cache key from input
        let cacheKey = "llm:\(SHA256.hash(data: input.description.data(using: .utf8)!))"
        
        // Check cache first
        if let cached = try await cache.get(cacheKey, as: String.self) {
            logger.info("LLM cache hit for key: \(cacheKey)")
            return cached
        }
        
        // Generate and cache response
        let response = try await llmService.generate(input: input)
        try await cache.set(cacheKey, value: response, ttl: 3600) // 1 hour TTL
        
        return response
    }
}
```

#### Step 4: Implement Cache Warming
```swift
struct CacheWarmingJob: AsyncScheduledJob {
    func run(context: QueueContext) async throws {
        // Pre-cache popular game rules
        let popularGames = ["Monopoly", "Scrabble", "Chess", "Checkers"]
        
        for game in popularGames {
            let request = RulesGenerationRequest(gameTitle: game)
            _ = try await rulesService.generate(request) // Will cache automatically
        }
    }
}
```

### Cache Strategy
- **LLM Responses**: 1 hour TTL (80% hit rate expected)
- **User Sessions**: 15 minutes TTL
- **Static Content**: 24 hours TTL
- **Game Rules**: 7 days TTL

### Success Criteria
- ✅ Redis integrated and operational
- ✅ Cache service implemented with TTL support
- ✅ LLM responses cached effectively
- ✅ 80% reduction in OpenAI API calls
- ✅ Cache hit rate > 70% overall

---

## 📋 Task 5.3: Error Handling Consistency

**Timeline**: 2 days | **Complexity**: Low

### Current Issues
- Inconsistent error types across modules
- Generic error messages to users
- Missing error context and correlation
- No error recovery patterns

### Implementation Plan

#### Step 1: Standardize Error Types
```swift
// Domain errors
enum DomainError: AppError {
    case userNotFound
    case invalidCredentials
    case emailAlreadyExists
    case tokenExpired
    
    var identifier: String {
        switch self {
        case .userNotFound: return "user.not_found"
        case .invalidCredentials: return "auth.invalid_credentials"
        case .emailAlreadyExists: return "user.email_exists"
        case .tokenExpired: return "auth.token_expired"
        }
    }
    
    var reason: String {
        switch self {
        case .userNotFound: return "User account not found"
        case .invalidCredentials: return "Invalid email or password"
        case .emailAlreadyExists: return "Email address already registered"
        case .tokenExpired: return "Authentication token has expired"
        }
    }
    
    var status: HTTPStatus {
        switch self {
        case .userNotFound: return .notFound
        case .invalidCredentials: return .unauthorized
        case .emailAlreadyExists: return .conflict
        case .tokenExpired: return .unauthorized
        }
    }
}
```

#### Step 2: Add Error Context
```swift
struct ErrorContext {
    let correlationID: String
    let timestamp: Date
    let path: String
    let method: HTTPMethod
    let userID: UUID?
    
    func attachTo(_ error: Error) -> ErrorWithContext {
        ErrorWithContext(error: error, context: self)
    }
}

struct ErrorWithContext: Error {
    let error: Error
    let context: ErrorContext
    
    var localizedDescription: String {
        "\(error.localizedDescription) [ID: \(context.correlationID)]"
    }
}
```

#### Step 3: Implement Error Recovery
```swift
protocol Recoverable {
    func canRecover(from error: Error) -> Bool
    func recover(from error: Error) async throws
}

struct RetryableOperation<T> {
    let maxAttempts: Int
    let backoff: TimeInterval
    let operation: () async throws -> T
    
    func execute() async throws -> T {
        var lastError: Error?
        
        for attempt in 1...maxAttempts {
            do {
                return try await operation()
            } catch {
                lastError = error
                if attempt < maxAttempts {
                    try await Task.sleep(nanoseconds: UInt64(backoff * Double(attempt) * 1_000_000_000))
                }
            }
        }
        
        throw lastError ?? DomainError.unknownError
    }
}
```

#### Step 4: Error Monitoring
```swift
struct ErrorMonitor {
    static func track(_ error: Error, context: ErrorContext) {
        // Log to monitoring service
        logger.error("Error occurred", metadata: [
            "error": .string(error.localizedDescription),
            "correlation_id": .string(context.correlationID),
            "path": .string(context.path),
            "user_id": .string(context.userID?.uuidString ?? "anonymous")
        ])
        
        // Send to error tracking service (e.g., Sentry)
        // Sentry.capture(error: error, context: context)
    }
}
```

### Success Criteria
- ✅ All errors use standardized types
- ✅ Error context included in all responses
- ✅ Retry logic implemented for transient failures
- ✅ Error monitoring dashboard configured
- ✅ User-friendly error messages

---

## 🎯 Performance & Reliability Targets

### Performance Metrics
- **API Response Time**: p95 < 200ms
- **Database Query Time**: p95 < 50ms
- **Cache Hit Rate**: > 70%
- **OpenAI API Calls**: -80% reduction

### Reliability Metrics
- **Error Rate**: < 1%
- **Successful Recovery Rate**: > 90% for transient errors
- **Uptime**: 99.9%
- **Data Consistency**: 100%

## 📊 Implementation Schedule

### Week 1
- **Day 1-2**: Database indexes and query optimization
- **Day 3**: Connection pooling and monitoring
- **Day 4**: Redis integration
- **Day 5**: Cache service implementation

### Week 2
- **Day 1**: LLM response caching
- **Day 2**: Cache warming strategies
- **Day 3**: Error standardization
- **Day 4**: Error context and recovery
- **Day 5**: Testing and documentation

## 🎯 Definition of Done

### Task 5.1 (Database Optimization)
- [ ] All indexes created and verified
- [ ] N+1 queries eliminated
- [ ] Connection pooling configured
- [ ] Query monitoring active
- [ ] Performance targets met

### Task 5.2 (Caching Strategy)
- [ ] Redis integrated successfully
- [ ] Cache service fully functional
- [ ] LLM responses cached
- [ ] Cache warming implemented
- [ ] 80% API call reduction achieved

### Task 5.3 (Error Handling)
- [ ] Error types standardized
- [ ] Context tracking implemented
- [ ] Recovery patterns in place
- [ ] Monitoring configured
- [ ] All tests passing

### Overall Phase 5
- [ ] Performance benchmarks met
- [ ] Reliability targets achieved
- [ ] Documentation updated
- [ ] Load testing completed
- [ ] Code review passed
- [ ] Merged to main branch

---

*Phase Start: After Phase 4*  
*Estimated Duration: 1-2 weeks*  
*Next Phase: Observability & Documentation*