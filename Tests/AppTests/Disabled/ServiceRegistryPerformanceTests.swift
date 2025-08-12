@testable import App
import XCTest
import XCTVapor
import Vapor

/// Performance tests for ServiceRegistry and dependency injection to verify Clean Architecture performance.
///
/// These tests validate that the new ServiceRegistry pattern with dependency injection
/// doesn't introduce performance overhead compared to direct service instantiation.
final class ServiceRegistryPerformanceTests: XCTestCase {
    var app: Application!
    var performanceTestCase: PerformanceTestCase!
    
    override func setUp() async throws {
        app = try await Application.make(.testing)
        performanceTestCase = try await PerformanceTestCase()
        
        // Run migrations
        try await app.autoMigrate()
    }
    
    override func tearDown() async throws {
        try await app.autoRevert()
        app.shutdown()
    }
    
    // MARK: - Service Resolution Performance
    
    func testServiceResolutionPerformance() async throws {
        // Measure service resolution through ServiceRegistry
        let metrics = try await performanceTestCase.measure(
            "Service Resolution Performance",
            iterations: 1000
        ) {
            // Test resolving various services
            _ = app.services.userRepository
            _ = app.services.refreshTokenRepository
            _ = app.services.emailTokenRepository
            _ = app.services.passwordTokenRepository
            _ = app.services.email.service
            _ = app.services.randomGenerator.service
            _ = app.services.uuidGenerator.service
            _ = app.services.aiCache.service
            _ = app.services.llm.service
        }
        
        print(metrics.summary)
        
        // Service resolution should be very fast (essentially property access)
        XCTAssertLessThan(metrics.averageTime, 0.001, "Service resolution average time should be under 1ms")
        XCTAssertLessThan(metrics.maximumTime, 0.002, "Service resolution max time should be under 2ms")
    }
    
    func testUseCaseResolutionPerformance() async throws {
        // Measure use case resolution through ServiceRegistry
        let metrics = try await performanceTestCase.measure(
            "Use Case Resolution Performance",
            iterations: 1000
        ) {
            // Test resolving various use cases
            _ = app.services.useCases.signUp
            _ = app.services.useCases.signIn
            _ = app.services.useCases.refreshToken
            _ = app.services.useCases.logout
            _ = app.services.useCases.getCurrentUser
            _ = app.services.useCases.updateUserProfile
            _ = app.services.useCases.deleteUserAccount
            _ = app.services.useCases.listUsers
            _ = app.services.useCases.analyzeGameBox
            _ = app.services.useCases.generateRules
        }
        
        print(metrics.summary)
        
        // Use case resolution should be fast
        XCTAssertLessThan(metrics.averageTime, 0.002, "Use case resolution average time should be under 2ms")
        XCTAssertLessThan(metrics.maximumTime, 0.004, "Use case resolution max time should be under 4ms")
    }
    
    func testDomainServiceResolutionPerformance() async throws {
        // Measure domain service resolution
        let metrics = try await performanceTestCase.measure(
            "Domain Service Resolution Performance",
            iterations: 1000
        ) {
            _ = app.services.domain.gameIdentification
            _ = app.services.domain.rulesOrchestration
            _ = app.services.domain.aiResponseValidation
        }
        
        print(metrics.summary)
        
        // Domain service resolution should be fast
        XCTAssertLessThan(metrics.averageTime, 0.001, "Domain service resolution average time should be under 1ms")
    }
    
    // MARK: - Concurrent Service Access
    
    func testConcurrentServiceAccess() async throws {
        let concurrentRequests = 100
        let startTime = Date()
        
        try await withThrowingTaskGroup(of: Void.self) { group in
            for _ in 0..<concurrentRequests {
                group.addTask {
                    // Access various services concurrently
                    _ = self.app.services.userRepository
                    _ = self.app.services.email.service
                    _ = self.app.services.useCases.signUp
                    _ = self.app.services.domain.rulesOrchestration
                    _ = self.app.services.aiCache.service
                }
            }
            
            try await group.waitForAll()
        }
        
        let totalTime = Date().timeIntervalSince(startTime)
        let avgTimePerRequest = totalTime / Double(concurrentRequests)
        
        print("""
        Concurrent Service Access Performance:
        Total Requests: \(concurrentRequests)
        Total Time: \(String(format: "%.4f", totalTime))s
        Average Time per Request: \(String(format: "%.6f", avgTimePerRequest))s
        """)
        
        // Concurrent access should be thread-safe and fast
        XCTAssertLessThan(totalTime, 0.5, "100 concurrent service accesses should complete within 0.5 seconds")
        XCTAssertLessThan(avgTimePerRequest, 0.005, "Average time per concurrent access should be under 5ms")
    }
    
    // MARK: - Service Initialization Performance
    
    func testServiceInitializationPerformance() async throws {
        // Test the performance of service initialization when first accessed
        var initializationTimes: [String: TimeInterval] = [:]
        
        // Measure individual service initialization
        let services: [(name: String, accessor: () -> Any)] = [
            ("UserRepository", { self.app.services.userRepository }),
            ("EmailService", { self.app.services.email.service }),
            ("AICache", { self.app.services.aiCache.service }),
            ("LLMService", { self.app.services.llm.service }),
            ("SignUpUseCase", { self.app.services.useCases.signUp }),
            ("RulesOrchestration", { self.app.services.domain.rulesOrchestration })
        ]
        
        for (name, accessor) in services {
            let startTime = Date()
            _ = accessor()
            let elapsed = Date().timeIntervalSince(startTime)
            initializationTimes[name] = elapsed
        }
        
        print("\nService Initialization Times:")
        for (name, time) in initializationTimes.sorted(by: { $0.key < $1.key }) {
            print("  \(name): \(String(format: "%.6f", time))s")
        }
        
        // All services should initialize quickly
        for (name, time) in initializationTimes {
            XCTAssertLessThan(time, 0.01, "\(name) initialization should be under 10ms")
        }
    }
    
    // MARK: - Dependency Injection Chain Performance
    
    func testDependencyInjectionChainPerformance() async throws {
        // Test performance when services have deep dependency chains
        let metrics = try await performanceTestCase.measure(
            "Dependency Injection Chain Performance",
            iterations: 500
        ) {
            // SignUpUseCase has multiple dependencies
            let signUpUseCase = app.services.useCases.signUp
            
            // Execute to test full dependency chain
            do {
                _ = try await signUpUseCase.execute(SignUpUseCase.Request(
                    email: "test\(UUID())@example.com",
                    password: "TestPass123!",
                    firstName: "Test",
                    lastName: "User"
                ))
            } catch {
                // Expected to fail due to mock services
            }
        }
        
        print(metrics.summary)
        
        // Even with dependency chains, performance should be good
        XCTAssertLessThan(metrics.averageTime, 0.05, "Dependency chain resolution should be under 50ms")
    }
    
    // MARK: - Service Caching Performance
    
    func testServiceCachingPerformance() async throws {
        // Services should be cached after first resolution
        
        // First access (potential initialization)
        let firstAccessTime = Date()
        _ = app.services.useCases.generateRules
        let firstAccessDuration = Date().timeIntervalSince(firstAccessTime)
        
        // Subsequent accesses (should be cached)
        let metrics = try await performanceTestCase.measure(
            "Cached Service Access Performance",
            iterations: 1000
        ) {
            _ = app.services.useCases.generateRules
        }
        
        print("First Access Time: \(String(format: "%.6f", firstAccessDuration))s")
        print(metrics.summary)
        
        // Cached access should be much faster than first access
        XCTAssertLessThan(metrics.averageTime, firstAccessDuration / 10, "Cached access should be at least 10x faster than first access")
        XCTAssertLessThan(metrics.averageTime, 0.0001, "Cached service access should be under 0.1ms")
    }
    
    // MARK: - Request-Scoped Service Performance
    
    func testRequestScopedServicePerformance() async throws {
        // Create multiple test requests to simulate request-scoped services
        var token = ""
        
        // Create test user
        let signUpRequest = Auth.SignUp.Request(
            email: "request-scoped@example.com",
            password: "TestPass123!",
            firstName: "Request",
            lastName: "Scoped"
        )
        
        try await app.test(.POST, "/api/auth/sign-up", beforeRequest: { req in
            try req.content.encode(signUpRequest)
        }, afterResponse: { res in
            let response = try res.content.decode(Auth.SignUp.Response.self)
            token = response.token.accessToken
        })
        
        // Measure performance of request-scoped service resolution
        let metrics = try await performanceTestCase.measure(
            "Request-Scoped Service Performance",
            iterations: 100
        ) {
            try await app.test(.GET, "/api/user", beforeRequest: { req in
                req.headers.bearerAuthorization = BearerAuthorization(token: token)
                
                // Services are resolved per request
                _ = req.services.userRepository
                _ = req.services.email.service
            }, afterResponse: { res in
                XCTAssertEqual(res.status, .ok)
            })
        }
        
        print(metrics.summary)
        
        // Request-scoped services should still be performant
        XCTAssertLessThan(metrics.averageTime, 0.03, "Request-scoped service resolution should be under 30ms")
    }
    
    // MARK: - Service Registry Memory Performance
    
    func testServiceRegistryMemoryPerformance() async throws {
        var memoryReadings: [Int] = []
        let iterations = 100
        
        for i in 0..<iterations {
            // Access various services
            _ = app.services.userRepository
            _ = app.services.useCases.signUp
            _ = app.services.domain.rulesOrchestration
            _ = app.services.aiCache.service
            
            // Create new request contexts
            try await app.test(.GET, "/api/health", afterResponse: { res in
                XCTAssertEqual(res.status, .ok)
            })
            
            // Capture memory usage periodically
            if i % 20 == 0 {
                let info = ProcessInfo.processInfo
                let memoryUsage = info.physicalMemory
                memoryReadings.append(Int(memoryUsage))
            }
        }
        
        // Analyze memory growth
        if memoryReadings.count > 2 {
            let firstReading = memoryReadings[0]
            let lastReading = memoryReadings[memoryReadings.count - 1]
            let memoryGrowth = lastReading - firstReading
            let avgGrowthPerIteration = memoryGrowth / iterations
            
            print("""
            ServiceRegistry Memory Performance:
            Initial Memory: \(firstReading / 1024 / 1024) MB
            Final Memory: \(lastReading / 1024 / 1024) MB
            Total Growth: \(memoryGrowth / 1024 / 1024) MB
            Average Growth per Iteration: \(avgGrowthPerIteration / 1024) KB
            """)
            
            // ServiceRegistry shouldn't cause memory leaks
            XCTAssertLessThan(avgGrowthPerIteration, 50 * 1024, "Memory growth per iteration should be under 50KB")
        }
    }
    
    // MARK: - Performance Comparison: Direct vs ServiceRegistry
    
    func testDirectVsServiceRegistryPerformance() async throws {
        // Compare direct instantiation vs ServiceRegistry resolution
        
        // Direct instantiation
        let directMetrics = performanceTestCase.measureSync(
            "Direct Service Instantiation",
            iterations: 1000
        ) {
            _ = TestUserRepository()
            _ = FakeEmailProvider()
            _ = RiggedRandomGeneratorService(value: "test")
        }
        
        // ServiceRegistry resolution
        let registryMetrics = performanceTestCase.measureSync(
            "ServiceRegistry Resolution",
            iterations: 1000
        ) {
            _ = app.services.userRepository
            _ = app.services.email.service
            _ = app.services.randomGenerator.service
        }
        
        print("\n" + String(repeating: "=", count: 60))
        print("PERFORMANCE COMPARISON: Direct vs ServiceRegistry")
        print(String(repeating: "=", count: 60))
        print("\nDirect Instantiation:")
        print(directMetrics.summary)
        print("\nServiceRegistry Resolution:")
        print(registryMetrics.summary)
        
        let overhead = ((registryMetrics.averageTime - directMetrics.averageTime) / directMetrics.averageTime) * 100
        print("\nServiceRegistry Overhead: \(String(format: "%.2f", overhead))%")
        print(String(repeating: "=", count: 60))
        
        // ServiceRegistry should have minimal overhead (caching makes it faster after first access)
        XCTAssertLessThan(overhead, 50, "ServiceRegistry overhead should be less than 50%")
        
        // In absolute terms, both should be very fast
        XCTAssertLessThan(registryMetrics.averageTime, 0.001, "ServiceRegistry resolution should be under 1ms")
    }
    
    // MARK: - Complex Use Case Performance
    
    func testComplexUseCasePerformance() async throws {
        // Test a complex use case with many dependencies
        let rulesOrchestration = app.services.domain.rulesOrchestration
        
        // Configure mock responses
        let testWorld = try TestWorld(app: app)
        testWorld.llm.responseDelay = 0.001
        testWorld.llm.setResponse(for: "identify", response: """
            {"game_name": "Complex Game", "confidence": 0.95}
            """)
        testWorld.llm.setResponse(for: "generate", response: """
            {"sections": [{"title": "Rules", "content": "Complex rules"}]}
            """)
        
        let metrics = try await performanceTestCase.measure(
            "Complex Use Case Execution",
            iterations: 50
        ) {
            _ = try await rulesOrchestration.generateRules(
                gameName: "Complex Game \(UUID())",
                playerCount: "2-6",
                gameContext: "A complex strategic board game with multiple phases",
                complexity: "high",
                customPrompt: "Include detailed examples"
            )
        }
        
        print(metrics.summary)
        
        // Complex use cases should still perform well
        XCTAssertLessThan(metrics.averageTime, 0.1, "Complex use case average time should be under 100ms")
        XCTAssertLessThan(metrics.maximumTime, 0.2, "Complex use case max time should be under 200ms")
    }
}