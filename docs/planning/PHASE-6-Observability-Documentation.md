# Phase 6: Observability & Documentation

**Status**: 📋 PLANNED  
**Timeline**: 1 week  
**Priority**: P3 (Medium)  
**Prerequisites**: Phase 5 (Performance & Reliability)

## 🎯 Objective

Establish comprehensive monitoring and observability infrastructure, create complete API documentation with OpenAPI/Swagger, and optimize deployment processes for production readiness.

## 📋 Task 6.1: Monitoring & Observability

**Timeline**: 3-4 days | **Complexity**: Medium

### Current State
- Basic logging to console
- No structured logging format
- No metrics collection
- No distributed tracing
- No health check endpoints

### Implementation Plan

#### Step 1: Structured Logging
```swift
// Configure structured JSON logging
import Logging

extension Logger {
    static func structured(label: String) -> Logger {
        var logger = Logger(label: label)
        logger.logLevel = .info
        
        // JSON output for production
        if Environment.get("LOG_FORMAT") == "json" {
            LoggingSystem.bootstrap { label in
                JSONLogHandler(label: label)
            }
        }
        
        return logger
    }
}

// Enhanced logging with metadata
extension Request {
    var structuredLogger: Logger {
        var logger = self.logger
        logger[metadataKey: "correlation_id"] = .string(correlationID)
        logger[metadataKey: "user_id"] = .string(auth.userID?.uuidString ?? "anonymous")
        logger[metadataKey: "path"] = .string(url.path)
        logger[metadataKey: "method"] = .string(method.string)
        return logger
    }
}
```

#### Step 2: Metrics Collection (Prometheus)
```swift
// Package.swift
.package(url: "https://github.com/swift-server/swift-prometheus.git", from: "1.0.0")

// Metrics configuration
import Prometheus

final class MetricsService {
    let requestCounter = Counter(
        label: "http_requests_total",
        dimensions: [("method", ""), ("path", ""), ("status", "")]
    )
    
    let requestDuration = Histogram(
        label: "http_request_duration_seconds",
        dimensions: [("method", ""), ("path", "")],
        buckets: [0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10]
    )
    
    let activeConnections = Gauge(label: "http_connections_active")
    
    let dbQueryDuration = Histogram(
        label: "db_query_duration_seconds",
        dimensions: [("query_type", "")],
        buckets: [0.001, 0.005, 0.01, 0.05, 0.1, 0.5, 1]
    )
    
    func middleware() -> AsyncMiddleware {
        MetricsMiddleware(metrics: self)
    }
}

struct MetricsMiddleware: AsyncMiddleware {
    let metrics: MetricsService
    
    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        metrics.activeConnections.inc()
        let start = Date()
        
        defer {
            metrics.activeConnections.dec()
        }
        
        do {
            let response = try await next.respond(to: request)
            let duration = Date().timeIntervalSince(start)
            
            metrics.requestCounter.inc([
                ("method", request.method.string),
                ("path", request.route?.path ?? "unknown"),
                ("status", "\(response.status.code)")
            ])
            
            metrics.requestDuration.observe(duration, [
                ("method", request.method.string),
                ("path", request.route?.path ?? "unknown")
            ])
            
            return response
        } catch {
            metrics.requestCounter.inc([
                ("method", request.method.string),
                ("path", request.route?.path ?? "unknown"),
                ("status", "500")
            ])
            throw error
        }
    }
}
```

#### Step 3: Health Check Endpoints
```swift
struct HealthController {
    // Basic liveness probe
    func alive(_ req: Request) async throws -> HealthResponse {
        HealthResponse(status: "alive", timestamp: Date())
    }
    
    // Readiness probe with dependency checks
    func ready(_ req: Request) async throws -> ReadinessResponse {
        var checks: [String: HealthCheck] = [:]
        
        // Database check
        checks["database"] = await checkDatabase(req)
        
        // Redis check
        checks["cache"] = await checkRedis(req)
        
        // External services check
        checks["openai"] = await checkOpenAI(req)
        
        let allHealthy = checks.values.allSatisfy { $0.status == "healthy" }
        
        return ReadinessResponse(
            status: allHealthy ? "ready" : "degraded",
            checks: checks,
            timestamp: Date()
        )
    }
    
    private func checkDatabase(_ req: Request) async -> HealthCheck {
        do {
            _ = try await req.db.raw("SELECT 1").all()
            return HealthCheck(status: "healthy", responseTime: 0.001)
        } catch {
            return HealthCheck(status: "unhealthy", error: error.localizedDescription)
        }
    }
}
```

#### Step 4: Distributed Tracing
```swift
// OpenTelemetry integration
import OpenTelemetryApi
import OpenTelemetrySdk

final class TracingService {
    let tracer: Tracer
    
    init() {
        let provider = TracerProviderBuilder()
            .add(spanProcessor: BatchSpanProcessor(spanExporter: JaegerExporter()))
            .build()
        
        OpenTelemetry.registerTracerProvider(tracerProvider: provider)
        self.tracer = OpenTelemetry.instance.tracerProvider.get(instrumentationName: "project-rulebook")
    }
    
    func startSpan(_ name: String, request: Request) -> Span {
        let span = tracer.spanBuilder(spanName: name)
            .setSpanKind(spanKind: .server)
            .setAttribute(key: "http.method", value: request.method.string)
            .setAttribute(key: "http.url", value: request.url.string)
            .setAttribute(key: "correlation.id", value: request.correlationID)
            .startSpan()
        
        return span
    }
}
```

### Success Criteria
- ✅ Structured JSON logging in production
- ✅ Prometheus metrics exposed at /metrics
- ✅ Health check endpoints operational
- ✅ Distributed tracing for all requests
- ✅ Monitoring dashboard configured

---

## 📋 Task 6.2: API Documentation & Validation

**Timeline**: 2-3 days | **Complexity**: Low

### Current State
- No API documentation
- No request/response validation
- No API versioning strategy
- No client SDK generation

### Implementation Plan

#### Step 1: OpenAPI Documentation Generation
```swift
// Package.swift
.package(url: "https://github.com/vapor/vapor-openapi.git", from: "1.0.0")

// OpenAPI configuration
import VaporOpenAPI

extension Application {
    func configureOpenAPI() {
        let openAPI = OpenAPIBuilder()
            .title("Project Rulebook API")
            .version("1.0.0")
            .description("Board game rules generation and management API")
            .server(url: configuration.api.baseURL, description: "Production")
            .contact(name: "API Support", email: "api@projectrulebook.com")
            .license(name: "MIT")
            .build()
        
        // Register all endpoints
        openAPI.register(AuthEndpoints.self)
        openAPI.register(UserEndpoints.self)
        openAPI.register(RulesEndpoints.self)
        
        // Serve documentation
        routes.get("docs", "openapi.json") { req in
            openAPI.document()
        }
        
        // Swagger UI
        routes.get("docs") { req in
            SwaggerUI.html(specURL: "/docs/openapi.json")
        }
    }
}
```

#### Step 2: Request/Response Validation
```swift
// Automatic validation from OpenAPI schema
protocol ValidatedEndpoint {
    associatedtype Request: Codable, Validatable
    associatedtype Response: Codable
    
    static var path: String { get }
    static var method: HTTPMethod { get }
    static var summary: String { get }
    static var tags: [String] { get }
}

extension ValidatedEndpoint {
    static func document() -> OpenAPIOperation {
        OpenAPIOperation(
            summary: summary,
            tags: tags,
            requestBody: OpenAPIRequestBody(content: Request.schema),
            responses: [
                200: OpenAPIResponse(description: "Success", content: Response.schema),
                400: OpenAPIResponse(description: "Validation Error", content: ErrorResponse.schema)
            ]
        )
    }
}
```

#### Step 3: API Versioning
```swift
// Version middleware
struct APIVersionMiddleware: AsyncMiddleware {
    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        // Extract version from header or path
        let version = request.headers.first(name: "API-Version") ?? "v1"
        request.storage[APIVersionKey.self] = version
        
        // Route to versioned handler
        switch version {
        case "v1":
            return try await next.respond(to: request)
        case "v2":
            return try await V2Router().respond(to: request)
        default:
            throw Abort(.badRequest, reason: "Unsupported API version")
        }
    }
}

// Versioned routes
func routesV1(_ app: Application) {
    let v1 = app.grouped("api", "v1")
    v1.group("auth") { auth in
        auth.post("sign-up", use: authController.signUpV1)
        auth.post("sign-in", use: authController.signInV1)
    }
}

func routesV2(_ app: Application) {
    let v2 = app.grouped("api", "v2")
    v2.group("auth") { auth in
        auth.post("register", use: authController.signUpV2) // New endpoint name
        auth.post("login", use: authController.signInV2)
    }
}
```

#### Step 4: API Testing Suite
```swift
// Contract testing
final class APIContractTests: IntegrationTestCase {
    func testOpenAPIContract() async throws {
        // Load OpenAPI spec
        let spec = try await app.client.get("/docs/openapi.json").content.decode(OpenAPIDocument.self)
        
        // Test all documented endpoints
        for (path, pathItem) in spec.paths {
            for (method, operation) in pathItem.operations {
                try await validateEndpoint(path: path, method: method, operation: operation)
            }
        }
    }
    
    private func validateEndpoint(path: String, method: HTTPMethod, operation: OpenAPIOperation) async throws {
        // Generate test data from schema
        let testRequest = operation.requestBody?.generateExample()
        
        // Make request
        let response = try await app.test(method, path) { req in
            if let testRequest = testRequest {
                try req.content.encode(testRequest)
            }
        }
        
        // Validate response matches schema
        XCTAssertTrue(operation.responses.keys.contains(Int(response.status.code)))
    }
}
```

### Success Criteria
- ✅ OpenAPI documentation complete
- ✅ Swagger UI accessible at /docs
- ✅ Request validation from schema
- ✅ API versioning implemented
- ✅ Contract tests passing

---

## 📋 Task 6.3: Production Deployment Optimization

**Timeline**: 2 days | **Complexity**: Low

### Current State
- Basic Docker configuration
- No graceful shutdown
- No feature flags
- No rollback strategy

### Implementation Plan

#### Step 1: Optimize Docker Configuration
```dockerfile
# Multi-stage build for smaller image
FROM swift:5.9 as builder
WORKDIR /app
COPY Package.* ./
RUN swift package resolve
COPY . .
RUN swift build -c release --static-swift-stdlib

# Runtime image
FROM swift:5.9-slim
WORKDIR /app
COPY --from=builder /app/.build/release/App /app/App
COPY --from=builder /app/Public /app/Public
COPY --from=builder /app/Resources /app/Resources

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/health/alive || exit 1

EXPOSE 8080
ENTRYPOINT ["./App"]
CMD ["serve", "--env", "production", "--hostname", "0.0.0.0", "--port", "8080"]
```

#### Step 2: Graceful Shutdown
```swift
// Application lifecycle
extension Application {
    func configureLifecycle() {
        lifecycle.use(GracefulShutdownHandler())
    }
}

struct GracefulShutdownHandler: LifecycleHandler {
    func willBoot(_ application: Application) throws {
        application.logger.info("Application starting...")
    }
    
    func didBoot(_ application: Application) throws {
        application.logger.info("Application started successfully")
    }
    
    func shutdown(_ application: Application) {
        application.logger.info("Graceful shutdown initiated...")
        
        // Stop accepting new requests
        application.server.shutdown()
        
        // Wait for ongoing requests to complete (max 30 seconds)
        let deadline = Date().addingTimeInterval(30)
        while application.server.hasActiveConnections && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.1)
        }
        
        // Close database connections
        application.databases.shutdown()
        
        // Close Redis connections
        application.redis.shutdown()
        
        application.logger.info("Graceful shutdown completed")
    }
}
```

#### Step 3: Feature Flags
```swift
protocol FeatureFlag {
    var key: String { get }
    var defaultValue: Bool { get }
    func isEnabled(for request: Request) async -> Bool
}

struct FeatureFlagService {
    private var flags: [String: FeatureFlag] = [:]
    
    func register(_ flag: FeatureFlag) {
        flags[flag.key] = flag
    }
    
    func isEnabled(_ key: String, for request: Request) async -> Bool {
        guard let flag = flags[key] else { return false }
        
        // Check Redis for override
        if let override = try? await request.redis.get("feature:\(key)", as: Bool.self) {
            return override
        }
        
        // Check user-specific flags
        if let userID = request.auth.userID {
            let userKey = "feature:\(key):user:\(userID)"
            if let userOverride = try? await request.redis.get(userKey, as: Bool.self) {
                return userOverride
            }
        }
        
        return flag.defaultValue
    }
}

// Usage
struct NewRulesEngineFlag: FeatureFlag {
    let key = "new-rules-engine"
    let defaultValue = false
    
    func isEnabled(for request: Request) async -> Bool {
        // Gradual rollout: 10% of users
        if let userID = request.auth.userID {
            return userID.uuidString.hashValue % 10 == 0
        }
        return defaultValue
    }
}
```

#### Step 4: Deployment Strategy
```yaml
# docker-compose.production.yml
version: '3.8'

services:
  app:
    image: project-rulebook:latest
    deploy:
      replicas: 3
      update_config:
        parallelism: 1
        delay: 10s
        failure_action: rollback
      restart_policy:
        condition: on-failure
        delay: 5s
        max_attempts: 3
    environment:
      - LOG_LEVEL=info
      - LOG_FORMAT=json
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health/ready"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
    networks:
      - internal
    depends_on:
      db:
        condition: service_healthy
      redis:
        condition: service_healthy

  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf
      - ./ssl:/etc/nginx/ssl
    depends_on:
      - app
    networks:
      - internal
```

### Success Criteria
- ✅ Docker image < 100MB
- ✅ Graceful shutdown within 30s
- ✅ Feature flags operational
- ✅ Zero-downtime deployments
- ✅ Rollback capability tested

---

## 🎯 Observability & Documentation Goals

### Monitoring Coverage
- **Logs**: 100% structured JSON format
- **Metrics**: All endpoints instrumented
- **Traces**: Full request lifecycle tracked
- **Alerts**: Critical paths monitored

### Documentation Completeness
- **API Docs**: 100% endpoint coverage
- **Examples**: Every endpoint has example
- **SDKs**: Generated for Swift, TypeScript
- **Guides**: Getting started, authentication, errors

### Deployment Reliability
- **Health Checks**: < 1s response time
- **Graceful Shutdown**: < 30s completion
- **Feature Flags**: < 100ms evaluation
- **Rollback Time**: < 5 minutes

## 📊 Implementation Schedule

### Days 1-2: Monitoring Infrastructure
- Structured logging setup
- Prometheus metrics integration
- Health check endpoints

### Days 3-4: Observability & Tracing
- Distributed tracing setup
- Monitoring dashboard creation
- Alert configuration

### Days 5-6: Documentation
- OpenAPI specification
- Swagger UI setup
- API versioning

### Day 7: Deployment
- Docker optimization
- Graceful shutdown
- Feature flags
- Deployment testing

## 🎯 Definition of Done

### Task 6.1 (Monitoring)
- [ ] JSON structured logging active
- [ ] Metrics endpoint operational
- [ ] Health checks passing
- [ ] Tracing configured
- [ ] Dashboard deployed

### Task 6.2 (Documentation)
- [ ] OpenAPI spec complete
- [ ] Swagger UI accessible
- [ ] Validation active
- [ ] Versioning implemented
- [ ] Contract tests passing

### Task 6.3 (Deployment)
- [ ] Docker image optimized
- [ ] Graceful shutdown working
- [ ] Feature flags functional
- [ ] Deployment automated
- [ ] Rollback tested

### Overall Phase 6
- [ ] Monitoring coverage > 95%
- [ ] API documentation 100%
- [ ] Deployment time < 5 min
- [ ] All tests passing
- [ ] Code review completed
- [ ] Merged to main branch

---

*Phase Start: After Phase 5*  
*Estimated Duration: 1 week*  
*Next Phase: Advanced Features*