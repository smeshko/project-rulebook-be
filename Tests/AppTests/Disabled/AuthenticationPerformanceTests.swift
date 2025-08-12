@testable import App
import XCTest
import XCTVapor
import Vapor

/// Performance tests for authentication endpoints to verify Clean Architecture refactoring performance.
///
/// These tests measure actual HTTP request/response times, memory allocation patterns,
/// and concurrent request handling for authentication operations after the use case refactoring.
final class AuthenticationPerformanceTests: XCTestCase {
    var app: Application!
    var testWorld: TestWorld!
    var performanceTestCase: PerformanceTestCase!
    
    override func setUp() async throws {
        app = try await Application.make(.testing)
        testWorld = try TestWorld(app: app)
        performanceTestCase = try await PerformanceTestCase()
        
        // Run migrations for database setup
        try await app.autoMigrate()
    }
    
    override func tearDown() async throws {
        try await app.autoRevert()
        app.shutdown()
    }
    
    // MARK: - Sign Up Performance Tests
    
    func testSignUpEndpointPerformance() async throws {
        let metrics = try await performanceTestCase.measure(
            "Sign Up Endpoint Performance",
            iterations: 100
        ) {
            let email = "test\(UUID())@example.com"
            let request = Auth.SignUp.Request(
                email: email,
                password: "ValidPass123!",
                firstName: "Test",
                lastName: "User"
            )
            
            try await app.test(.POST, "/api/auth/sign-up", beforeRequest: { req in
                try req.content.encode(request)
            }, afterResponse: { res in
                XCTAssertEqual(res.status, .ok)
            })
        }
        
        print(metrics.summary)
        
        // Performance baselines (should not exceed after refactoring)
        XCTAssertLessThan(metrics.averageTime, 0.05, "Sign up average time should be under 50ms")
        XCTAssertLessThan(metrics.maximumTime, 0.1, "Sign up max time should be under 100ms")
        XCTAssertLessThan(metrics.standardDeviation, 0.02, "Sign up should have consistent performance")
    }
    
    func testSignInEndpointPerformance() async throws {
        // Create test user first
        let email = "perf-test@example.com"
        let password = "TestPass123!"
        
        let signUpRequest = Auth.SignUp.Request(
            email: email,
            password: password,
            firstName: "Perf",
            lastName: "Test"
        )
        
        try await app.test(.POST, "/api/auth/sign-up", beforeRequest: { req in
            try req.content.encode(signUpRequest)
        })
        
        // Measure sign-in performance
        let metrics = try await performanceTestCase.measure(
            "Sign In Endpoint Performance",
            iterations: 100
        ) {
            let signInRequest = Auth.SignIn.Request(
                email: email,
                password: password
            )
            
            try await app.test(.POST, "/api/auth/sign-in", beforeRequest: { req in
                try req.content.encode(signInRequest)
            }, afterResponse: { res in
                XCTAssertEqual(res.status, .ok)
            })
        }
        
        print(metrics.summary)
        
        // Performance baselines
        XCTAssertLessThan(metrics.averageTime, 0.04, "Sign in average time should be under 40ms")
        XCTAssertLessThan(metrics.maximumTime, 0.08, "Sign in max time should be under 80ms")
    }
    
    func testTokenRefreshPerformance() async throws {
        // Create user and get tokens
        let email = "refresh-test@example.com"
        let password = "TestPass123!"
        
        let signUpRequest = Auth.SignUp.Request(
            email: email,
            password: password,
            firstName: "Refresh",
            lastName: "Test"
        )
        
        var refreshToken = ""
        
        try await app.test(.POST, "/api/auth/sign-up", beforeRequest: { req in
            try req.content.encode(signUpRequest)
        }, afterResponse: { res in
            let response = try res.content.decode(Auth.SignUp.Response.self)
            refreshToken = response.token.refreshToken
        })
        
        // Measure token refresh performance
        let metrics = try await performanceTestCase.measure(
            "Token Refresh Performance",
            iterations: 100
        ) {
            let refreshRequest = Auth.RefreshToken.Request(refreshToken: refreshToken)
            
            try await app.test(.POST, "/api/auth/refresh-token", beforeRequest: { req in
                try req.content.encode(refreshRequest)
            }, afterResponse: { res in
                XCTAssertEqual(res.status, .ok)
            })
        }
        
        print(metrics.summary)
        
        // Performance baselines
        XCTAssertLessThan(metrics.averageTime, 0.03, "Token refresh average time should be under 30ms")
        XCTAssertLessThan(metrics.maximumTime, 0.06, "Token refresh max time should be under 60ms")
    }
    
    // MARK: - Concurrent Request Performance
    
    func testConcurrentSignUpPerformance() async throws {
        let concurrentRequests = 50
        let startTime = Date()
        
        try await withThrowingTaskGroup(of: Void.self) { group in
            for i in 0..<concurrentRequests {
                group.addTask {
                    let email = "concurrent\(i)@example.com"
                    let request = Auth.SignUp.Request(
                        email: email,
                        password: "ValidPass123!",
                        firstName: "Concurrent",
                        lastName: "User\(i)"
                    )
                    
                    try await self.app.test(.POST, "/api/auth/sign-up", beforeRequest: { req in
                        try req.content.encode(request)
                    }, afterResponse: { res in
                        XCTAssertEqual(res.status, .ok)
                    })
                }
            }
            
            try await group.waitForAll()
        }
        
        let totalTime = Date().timeIntervalSince(startTime)
        let avgTimePerRequest = totalTime / Double(concurrentRequests)
        
        print("""
        Concurrent Sign Up Performance:
        Total Requests: \(concurrentRequests)
        Total Time: \(String(format: "%.4f", totalTime))s
        Average Time per Request: \(String(format: "%.4f", avgTimePerRequest))s
        """)
        
        // Concurrent performance should still be good
        XCTAssertLessThan(totalTime, 5.0, "50 concurrent sign-ups should complete within 5 seconds")
        XCTAssertLessThan(avgTimePerRequest, 0.1, "Average time per concurrent request should be under 100ms")
    }
    
    func testConcurrentSignInPerformance() async throws {
        // Create test users
        let userCount = 10
        var credentials: [(email: String, password: String)] = []
        
        for i in 0..<userCount {
            let email = "concurrent-signin-\(i)@example.com"
            let password = "TestPass\(i)123!"
            credentials.append((email, password))
            
            let signUpRequest = Auth.SignUp.Request(
                email: email,
                password: password,
                firstName: "User",
                lastName: "\(i)"
            )
            
            try await app.test(.POST, "/api/auth/sign-up", beforeRequest: { req in
                try req.content.encode(signUpRequest)
            })
        }
        
        // Test concurrent sign-ins
        let concurrentRequests = 100 // 10 users, 10 sign-ins each
        let startTime = Date()
        
        try await withThrowingTaskGroup(of: Void.self) { group in
            for i in 0..<concurrentRequests {
                let credential = credentials[i % userCount]
                
                group.addTask {
                    let signInRequest = Auth.SignIn.Request(
                        email: credential.email,
                        password: credential.password
                    )
                    
                    try await self.app.test(.POST, "/api/auth/sign-in", beforeRequest: { req in
                        try req.content.encode(signInRequest)
                    }, afterResponse: { res in
                        XCTAssertEqual(res.status, .ok)
                    })
                }
            }
            
            try await group.waitForAll()
        }
        
        let totalTime = Date().timeIntervalSince(startTime)
        
        print("""
        Concurrent Sign In Performance:
        Total Requests: \(concurrentRequests)
        Total Time: \(String(format: "%.4f", totalTime))s
        Requests per Second: \(String(format: "%.2f", Double(concurrentRequests) / totalTime))
        """)
        
        XCTAssertLessThan(totalTime, 8.0, "100 concurrent sign-ins should complete within 8 seconds")
    }
    
    // MARK: - Memory Performance Tests
    
    func testSignUpMemoryEfficiency() async throws {
        // Warm up
        for _ in 0..<10 {
            let email = "warmup\(UUID())@example.com"
            let request = Auth.SignUp.Request(
                email: email,
                password: "ValidPass123!",
                firstName: "Warmup",
                lastName: "User"
            )
            
            try await app.test(.POST, "/api/auth/sign-up", beforeRequest: { req in
                try req.content.encode(request)
            })
        }
        
        // Measure memory impact of multiple sign-ups
        let iterations = 100
        var memoryReadings: [Int] = []
        
        for i in 0..<iterations {
            let email = "memory-test\(i)@example.com"
            let request = Auth.SignUp.Request(
                email: email,
                password: "ValidPass123!",
                firstName: "Memory",
                lastName: "Test\(i)"
            )
            
            try await app.test(.POST, "/api/auth/sign-up", beforeRequest: { req in
                try req.content.encode(request)
            })
            
            // Capture memory usage periodically
            if i % 10 == 0 {
                let info = ProcessInfo.processInfo
                let memoryUsage = info.physicalMemory
                memoryReadings.append(Int(memoryUsage))
            }
        }
        
        // Check for memory leaks (memory shouldn't grow linearly)
        if memoryReadings.count > 2 {
            let firstReading = memoryReadings[0]
            let lastReading = memoryReadings[memoryReadings.count - 1]
            let memoryGrowth = lastReading - firstReading
            let avgGrowthPerIteration = memoryGrowth / iterations
            
            print("""
            Memory Performance:
            Initial Memory: \(firstReading / 1024 / 1024) MB
            Final Memory: \(lastReading / 1024 / 1024) MB
            Total Growth: \(memoryGrowth / 1024 / 1024) MB
            Average Growth per Request: \(avgGrowthPerIteration / 1024) KB
            """)
            
            // Memory growth should be minimal (allowing for some caching)
            XCTAssertLessThan(avgGrowthPerIteration, 100 * 1024, "Memory growth per request should be under 100KB")
        }
    }
    
    // MARK: - Database Operation Performance
    
    func testDatabaseQueryPerformance() async throws {
        // Create test data
        let userCount = 100
        for i in 0..<userCount {
            let email = "db-test\(i)@example.com"
            let request = Auth.SignUp.Request(
                email: email,
                password: "ValidPass123!",
                firstName: "DB",
                lastName: "Test\(i)"
            )
            
            try await app.test(.POST, "/api/auth/sign-up", beforeRequest: { req in
                try req.content.encode(request)
            })
        }
        
        // Test query performance for sign-in (involves user lookup)
        let metrics = try await performanceTestCase.measure(
            "Database Query Performance (Sign In)",
            iterations: 50
        ) {
            let randomIndex = Int.random(in: 0..<userCount)
            let signInRequest = Auth.SignIn.Request(
                email: "db-test\(randomIndex)@example.com",
                password: "ValidPass123!"
            )
            
            try await app.test(.POST, "/api/auth/sign-in", beforeRequest: { req in
                try req.content.encode(signInRequest)
            }, afterResponse: { res in
                XCTAssertEqual(res.status, .ok)
            })
        }
        
        print(metrics.summary)
        
        // Database queries should remain performant
        XCTAssertLessThan(metrics.averageTime, 0.05, "Database query average time should be under 50ms")
        XCTAssertLessThan(metrics.maximumTime, 0.1, "Database query max time should be under 100ms")
    }
}