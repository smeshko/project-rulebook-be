# Task 2: Security Hardening

**Branch:** `feature/security-hardening`  
**Effort:** 3-4 days | **Priority:** 🔴 CRITICAL  
**Dependencies:** Task 1 (Configuration Management)

## 🎯 Objective

Implement comprehensive security middleware to protect against common web vulnerabilities including CORS issues, rate limiting, security headers, and request validation.

## 🔍 Current Security Issues

### Critical Vulnerabilities
1. **No CORS Configuration** - Potential for cross-origin attacks
2. **No Rate Limiting** - Vulnerable to DDoS and brute force attacks
3. **Missing Security Headers** - No HSTS, CSP, X-Frame-Options protection
4. **No Request Validation** - Potential for injection attacks
5. **No IP-based Protection** - Authentication endpoints unprotected

### Risk Assessment
- **CORS:** HIGH - Enables unauthorized cross-origin requests
- **Rate Limiting:** HIGH - Service vulnerable to abuse and attacks
- **Security Headers:** MEDIUM - Missing browser security protections
- **Input Validation:** MEDIUM - Potential for injection attacks

## 🏗 Security Architecture

### Middleware Stack (Order Matters)
1. **Security Headers Middleware** - First line of defense
2. **CORS Middleware** - Cross-origin protection
3. **Rate Limiting Middleware** - Request throttling
4. **Request Validation Middleware** - Input sanitization
5. **Existing Middlewares** - Error handling, authentication, etc.

## 📋 Implementation Steps

### Step 1: Security Headers Middleware

**File:** `Sources/App/Middlewares/SecurityHeadersMiddleware.swift`

```swift
import Vapor

struct SecurityHeadersMiddleware: AsyncMiddleware {
    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        let response = try await next.respond(to: request)
        
        // HSTS - Force HTTPS
        if request.application.environment.isRelease {
            response.headers.replaceOrAdd(name: "Strict-Transport-Security", 
                                        value: "max-age=31536000; includeSubDomains")
        }
        
        // Content Security Policy
        response.headers.replaceOrAdd(name: "Content-Security-Policy", 
                                    value: "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'")
        
        // X-Frame-Options - Prevent clickjacking
        response.headers.replaceOrAdd(name: "X-Frame-Options", value: "DENY")
        
        // X-Content-Type-Options - Prevent MIME sniffing
        response.headers.replaceOrAdd(name: "X-Content-Type-Options", value: "nosniff")
        
        // X-XSS-Protection
        response.headers.replaceOrAdd(name: "X-XSS-Protection", value: "1; mode=block")
        
        // Referrer Policy
        response.headers.replaceOrAdd(name: "Referrer-Policy", value: "strict-origin-when-cross-origin")
        
        // Remove server information
        response.headers.remove(name: "Server")
        
        return response
    }
}
```

### Step 2: CORS Middleware

**File:** `Sources/App/Middlewares/CORSMiddleware.swift`

```swift
import Vapor

struct CORSConfiguration {
    let allowedOrigins: [String]
    let allowedMethods: [HTTPMethod]
    let allowedHeaders: [String]
    let allowCredentials: Bool
    let maxAge: Int
    
    static func development() -> CORSConfiguration {
        CORSConfiguration(
            allowedOrigins: ["http://localhost:3000", "http://localhost:8080"],
            allowedMethods: [.GET, .POST, .PUT, .DELETE, .OPTIONS],
            allowedHeaders: ["Content-Type", "Authorization"],
            allowCredentials: true,
            maxAge: 86400
        )
    }
    
    static func production() -> CORSConfiguration {
        CORSConfiguration(
            allowedOrigins: [], // Will be set from configuration service
            allowedMethods: [.GET, .POST, .PUT, .DELETE, .OPTIONS],
            allowedHeaders: ["Content-Type", "Authorization"],
            allowCredentials: true,
            maxAge: 86400
        )
    }
}

struct CORSMiddleware: AsyncMiddleware {
    private let configuration: CORSConfiguration
    
    init(configuration: CORSConfiguration) {
        self.configuration = configuration
    }
    
    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        let origin = request.headers.first(name: "Origin")
        
        // Handle preflight requests
        if request.method == .OPTIONS {
            let response = Response(status: .noContent)
            addCORSHeaders(to: response, origin: origin)
            return response
        }
        
        let response = try await next.respond(to: request)
        addCORSHeaders(to: response, origin: origin)
        return response
    }
    
    private func addCORSHeaders(to response: Response, origin: String?) {
        // Set allowed origins
        if let origin = origin, isOriginAllowed(origin) {
            response.headers.replaceOrAdd(name: "Access-Control-Allow-Origin", value: origin)
        } else if configuration.allowedOrigins.contains("*") {
            response.headers.replaceOrAdd(name: "Access-Control-Allow-Origin", value: "*")
        }
        
        // Set other CORS headers
        response.headers.replaceOrAdd(name: "Access-Control-Allow-Methods", 
                                    value: configuration.allowedMethods.map(\.string).joined(separator: ", "))
        response.headers.replaceOrAdd(name: "Access-Control-Allow-Headers", 
                                    value: configuration.allowedHeaders.joined(separator: ", "))
        
        if configuration.allowCredentials {
            response.headers.replaceOrAdd(name: "Access-Control-Allow-Credentials", value: "true")
        }
        
        response.headers.replaceOrAdd(name: "Access-Control-Max-Age", value: "\(configuration.maxAge)")
    }
    
    private func isOriginAllowed(_ origin: String) -> Bool {
        return configuration.allowedOrigins.contains(origin) || configuration.allowedOrigins.contains("*")
    }
}
```

### Step 3: Rate Limiting Middleware

**File:** `Sources/App/Middlewares/RateLimitMiddleware.swift`

```swift
import Vapor

struct RateLimitConfiguration {
    let requests: Int
    let per: TimeInterval
    let identifier: KeyPath<Request, String?>
    
    static func general() -> RateLimitConfiguration {
        RateLimitConfiguration(requests: 100, per: 60, identifier: \.remoteAddress?.hostname)
    }
    
    static func authentication() -> RateLimitConfiguration {
        RateLimitConfiguration(requests: 5, per: 60, identifier: \.remoteAddress?.hostname)
    }
}

actor RateLimitStore {
    private var requests: [String: [Date]] = [:]
    
    func checkLimit(for identifier: String, config: RateLimitConfiguration) -> Bool {
        let now = Date()
        let windowStart = now.addingTimeInterval(-config.per)
        
        // Clean old requests
        requests[identifier] = requests[identifier]?.filter { $0 > windowStart } ?? []
        
        let currentCount = requests[identifier]?.count ?? 0
        
        if currentCount >= config.requests {
            return false // Rate limit exceeded
        }
        
        // Add current request
        requests[identifier, default: []].append(now)
        return true
    }
}

struct RateLimitMiddleware: AsyncMiddleware {
    private let configuration: RateLimitConfiguration
    private let store = RateLimitStore()
    
    init(configuration: RateLimitConfiguration) {
        self.configuration = configuration
    }
    
    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        guard let identifierValue = request[keyPath: configuration.identifier] else {
            // If we can't identify the request, allow it but log
            request.logger.warning("Rate limiting: Unable to identify request source")
            return try await next.respond(to: request)
        }
        
        let allowed = await store.checkLimit(for: identifierValue, config: configuration)
        
        if !allowed {
            request.logger.warning("Rate limit exceeded for: \(identifierValue)")
            throw Abort(.tooManyRequests, reason: "Rate limit exceeded. Try again later.")
        }
        
        return try await next.respond(to: request)
    }
}
```

### Step 4: Request Validation Middleware

**File:** `Sources/App/Middlewares/RequestValidationMiddleware.swift`

```swift
import Vapor

struct RequestValidationMiddleware: AsyncMiddleware {
    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        // Validate request size
        try validateRequestSize(request)
        
        // Validate content type
        try validateContentType(request)
        
        // Validate headers
        try validateHeaders(request)
        
        return try await next.respond(to: request)
    }
    
    private func validateRequestSize(_ request: Request) throws {
        // Already handled by Vapor's defaultMaxBodySize, but add custom logic if needed
        if let contentLength = request.headers.first(name: .contentLength),
           let length = Int(contentLength),
           length > 50_000_000 { // 50MB custom limit
            throw Abort(.payloadTooLarge, reason: "Request too large")
        }
    }
    
    private func validateContentType(_ request: Request) throws {
        // Validate content type for POST/PUT requests
        if [.POST, .PUT, .PATCH].contains(request.method) {
            guard request.headers.contentType != nil else {
                throw Abort(.badRequest, reason: "Content-Type header required")
            }
        }
    }
    
    private func validateHeaders(_ request: Request) throws {
        // Check for suspicious headers
        let suspiciousHeaders = ["X-Forwarded-Host", "X-Original-URL", "X-Rewrite-URL"]
        for header in suspiciousHeaders {
            if request.headers.contains(name: header) {
                request.logger.warning("Suspicious header detected: \(header)")
            }
        }
        
        // Validate Host header
        if let host = request.headers.first(name: .host) {
            // Add host validation logic based on your domains
            let allowedHosts = ["localhost:8080", "your-domain.com", "staging.your-domain.com"]
            if !allowedHosts.contains(host) {
                request.logger.warning("Unknown host header: \(host)")
            }
        }
    }
}
```

### Step 5: Integration with Application Setup

**File:** `Sources/App/Entrypoint/Application-Setup.swift` (Modify)

```swift
extension Application {
    func setupMiddleware() {
        middleware = .init()
        
        // Security middleware (order matters!)
        middleware.use(SecurityHeadersMiddleware())
        
        // CORS configuration based on environment
        let corsConfig = environment.isRelease ? 
            CORSConfiguration.production() : 
            CORSConfiguration.development()
        middleware.use(CORSMiddleware(configuration: corsConfig))
        
        // Rate limiting
        middleware.use(RateLimitMiddleware(configuration: .general()))
        
        // Request validation
        middleware.use(RequestValidationMiddleware())
        
        // File serving
        let file = FileMiddleware(publicDirectory: directory.publicDirectory)
        middleware.use(file)
        
        // Body size limit
        routes.defaultMaxBodySize = "10mb"
        
        // Error handling
        middleware.use(ErrorMiddleware.custom(environment: environment))
        
        // Authentication
        middleware.use(UserPayloadAuthenticator())
    }
    
    func setupAuthenticationRateLimit() {
        // Apply stricter rate limiting to auth routes
        let authLimiter = RateLimitMiddleware(configuration: .authentication())
        
        // Apply to specific route groups
        routes.group("api", "auth") { auth in
            auth.grouped(authLimiter).post("sign-in") { req in
                // Auth controller logic
            }
            auth.grouped(authLimiter).post("sign-up") { req in
                // Auth controller logic
            }
        }
    }
}
```

### Step 6: Configuration Integration

**File:** Add to Configuration Service (from Task 1)

```swift
struct SecurityConfig {
    let baseURL: String
    let appIdentifier: String
    let jwtKey: String
    let allowedOrigins: [String]
    let rateLimitEnabled: Bool
    let securityHeadersEnabled: Bool
    
    static func development() -> SecurityConfig {
        SecurityConfig(
            // ... existing properties
            allowedOrigins: ["http://localhost:3000", "http://localhost:8080"],
            rateLimitEnabled: false, // Disabled for development
            securityHeadersEnabled: true
        )
    }
    
    static func production() -> SecurityConfig {
        SecurityConfig(
            // ... existing properties
            allowedOrigins: [], // Set from environment
            rateLimitEnabled: true,
            securityHeadersEnabled: true
        )
    }
}
```

## 🧪 Testing Strategy

### Unit Tests

**File:** `Tests/AppTests/Middlewares/SecurityMiddlewareTests.swift`

```swift
final class SecurityMiddlewareTests: XCTestCase {
    func testSecurityHeadersAdded() throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        
        app.middleware.use(SecurityHeadersMiddleware())
        app.get("test") { req in "OK" }
        
        try app.test(.GET, "test") { res in
            XCTAssertEqual(res.headers.first(name: "X-Frame-Options"), "DENY")
            XCTAssertEqual(res.headers.first(name: "X-Content-Type-Options"), "nosniff")
            XCTAssertNotNil(res.headers.first(name: "Content-Security-Policy"))
        }
    }
    
    func testRateLimitingWorks() throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        
        let config = RateLimitConfiguration(requests: 2, per: 60, identifier: \.remoteAddress?.hostname)
        app.middleware.use(RateLimitMiddleware(configuration: config))
        app.get("test") { req in "OK" }
        
        // First two requests should succeed
        try app.test(.GET, "test") { res in
            XCTAssertEqual(res.status, .ok)
        }
        try app.test(.GET, "test") { res in
            XCTAssertEqual(res.status, .ok)
        }
        
        // Third request should be rate limited
        try app.test(.GET, "test") { res in
            XCTAssertEqual(res.status, .tooManyRequests)
        }
    }
    
    func testCORSPreflightRequest() throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        
        let config = CORSConfiguration.development()
        app.middleware.use(CORSMiddleware(configuration: config))
        
        try app.test(.OPTIONS, "test", headers: ["Origin": "http://localhost:3000"]) { res in
            XCTAssertEqual(res.status, .noContent)
            XCTAssertEqual(res.headers.first(name: "Access-Control-Allow-Origin"), "http://localhost:3000")
            XCTAssertNotNil(res.headers.first(name: "Access-Control-Allow-Methods"))
        }
    }
}
```

### Integration Tests

```swift
final class SecurityIntegrationTests: XCTestCase {
    func testCompleteSecurityStack() throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        
        try configure(app) // Full app configuration
        
        try app.test(.GET, "/") { res in
            // Verify all security headers are present
            XCTAssertNotNil(res.headers.first(name: "X-Frame-Options"))
            XCTAssertNotNil(res.headers.first(name: "Content-Security-Policy"))
            XCTAssertNil(res.headers.first(name: "Server")) // Server header removed
        }
    }
    
    func testAuthenticationRateLimit() throws {
        // Test that auth endpoints have stricter rate limiting
    }
}
```

## ✅ Success Criteria

### Security Requirements
- [ ] CORS properly configured for all environments
- [ ] Rate limiting active on all endpoints (100 req/min general, 5 req/min auth)
- [ ] Security headers implemented (HSTS, CSP, X-Frame-Options, etc.)
- [ ] Request validation prevents oversized requests
- [ ] No security scanner warnings
- [ ] All middleware properly ordered

### Functional Requirements
- [ ] All existing functionality preserved
- [ ] No performance degradation
- [ ] Proper error responses for security violations
- [ ] Environment-specific configurations working
- [ ] Logging for security events

### Testing Requirements
- [ ] Unit tests for each middleware (>90% coverage)
- [ ] Integration tests for complete security stack
- [ ] Rate limiting behavior verified
- [ ] CORS preflight and actual requests tested
- [ ] Security headers validated

## 🚀 Implementation Timeline

### Day 1: Infrastructure
- Create middleware base structure
- Implement SecurityHeadersMiddleware
- Basic integration testing

### Day 2: CORS & Rate Limiting
- Implement CORSMiddleware with environment configs
- Implement RateLimitMiddleware with in-memory store
- Unit tests for both middlewares

### Day 3: Request Validation & Integration
- Implement RequestValidationMiddleware
- Integrate all middlewares into Application-Setup
- Environment-specific configurations

### Day 4: Testing & Documentation
- Comprehensive integration tests
- Security testing and validation
- Update documentation
- Performance testing

## 🎯 Definition of Done

- [ ] All middleware implemented and tested
- [ ] Security headers present on all responses
- [ ] CORS working for all environments
- [ ] Rate limiting preventing abuse
- [ ] Request validation blocking suspicious requests
- [ ] All tests passing (unit + integration)
- [ ] Documentation updated
- [ ] Code review completed
- [ ] Security review completed
- [ ] Merged to staging branch

---

*Task created: 2025-01-18*  
*Estimated completion: 2025-01-22*