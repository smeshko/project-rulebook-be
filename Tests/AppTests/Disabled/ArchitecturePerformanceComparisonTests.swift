@testable import App
import XCTest
import XCTVapor
import Vapor

/// Comprehensive performance comparison tests to verify Clean Architecture refactoring impact.
///
/// These tests establish performance baselines and verify that the architectural improvements
/// (use cases, domain services, CQRS, ServiceRegistry) maintain or improve performance metrics.
final class ArchitecturePerformanceComparisonTests: XCTestCase {
    var app: Application!
    var testWorld: TestWorld!
    var performanceTestCase: PerformanceTestCase!
    
    override func setUp() async throws {
        app = try await Application.make(.testing)
        testWorld = try TestWorld(app: app)
        performanceTestCase = try await PerformanceTestCase()
        
        // Run migrations
        try await app.autoMigrate()
    }
    
    override func tearDown() async throws {
        try await app.autoRevert()
        app.shutdown()
    }
    
    // MARK: - Performance Baseline Definitions
    
    struct PerformanceBaseline {
        let operation: String
        let maxAverageTime: TimeInterval  // Maximum acceptable average time
        let maxP95Time: TimeInterval      // Maximum 95th percentile time
        let maxP99Time: TimeInterval      // Maximum 99th percentile time
        let minThroughput: Double         // Minimum requests per second
    }
    
    // Define performance baselines based on pre-refactoring measurements
    let performanceBaselines = [
        PerformanceBaseline(
            operation: "User Sign Up",
            maxAverageTime: 0.05,    // 50ms average
            maxP95Time: 0.08,        // 80ms P95
            maxP99Time: 0.1,         // 100ms P99
            minThroughput: 20        // 20 req/s
        ),
        PerformanceBaseline(
            operation: "User Sign In",
            maxAverageTime: 0.04,    // 40ms average
            maxP95Time: 0.06,        // 60ms P95
            maxP99Time: 0.08,        // 80ms P99
            minThroughput: 25        // 25 req/s
        ),
        PerformanceBaseline(
            operation: "Get Current User",
            maxAverageTime: 0.02,    // 20ms average
            maxP95Time: 0.03,        // 30ms P95
            maxP99Time: 0.04,        // 40ms P99
            minThroughput: 50        // 50 req/s
        ),
        PerformanceBaseline(
            operation: "Generate Rules",
            maxAverageTime: 0.06,    // 60ms average (with mock LLM)
            maxP95Time: 0.1,         // 100ms P95
            maxP99Time: 0.12,        // 120ms P99
            minThroughput: 15        // 15 req/s
        ),
        PerformanceBaseline(
            operation: "Cache Hit",
            maxAverageTime: 0.01,    // 10ms average
            maxP95Time: 0.015,       // 15ms P95
            maxP99Time: 0.02,        // 20ms P99
            minThroughput: 100       // 100 req/s
        )
    ]
    
    // MARK: - Comprehensive Performance Test Suite
    
    func testComprehensivePerformanceBaseline() async throws {
        var results: [(operation: String, metrics: ExtendedPerformanceMetrics)] = []
        
        // 1. Test Authentication Performance
        results.append(("User Sign Up", try await measureSignUpPerformance()))
        results.append(("User Sign In", try await measureSignInPerformance()))
        
        // 2. Test User Operations Performance
        results.append(("Get Current User", try await measureGetCurrentUserPerformance()))
        results.append(("Update Profile", try await measureUpdateProfilePerformance()))
        
        // 3. Test AI Operations Performance
        results.append(("Generate Rules", try await measureGenerateRulesPerformance()))
        results.append(("Analyze Game Box", try await measureAnalyzeGameBoxPerformance()))
        
        // 4. Test Cache Performance
        results.append(("Cache Hit", try await measureCacheHitPerformance()))
        results.append(("Cache Miss", try await measureCacheMissPerformance()))
        
        // Generate comprehensive performance report
        generatePerformanceReport(results: results)
        
        // Verify against baselines
        for (operation, metrics) in results {
            if let baseline = performanceBaselines.first(where: { $0.operation == operation }) {
                XCTAssertLessThanOrEqual(
                    metrics.averageTime,
                    baseline.maxAverageTime,
                    "\(operation): Average time (\(metrics.averageTime)s) exceeds baseline (\(baseline.maxAverageTime)s)"
                )
                
                XCTAssertLessThanOrEqual(
                    metrics.p95Time,
                    baseline.maxP95Time,
                    "\(operation): P95 time (\(metrics.p95Time)s) exceeds baseline (\(baseline.maxP95Time)s)"
                )
                
                XCTAssertGreaterThanOrEqual(
                    metrics.throughput,
                    baseline.minThroughput,
                    "\(operation): Throughput (\(metrics.throughput) req/s) below baseline (\(baseline.minThroughput) req/s)"
                )
            }
        }
    }
    
    // MARK: - Individual Performance Measurements
    
    private func measureSignUpPerformance() async throws -> ExtendedPerformanceMetrics {
        var times: [TimeInterval] = []
        let iterations = 100
        
        for i in 0..<iterations {
            let startTime = Date()
            
            let request = Auth.SignUp.Request(
                email: "perf-test-\(i)@example.com",
                password: "TestPass123!",
                firstName: "Test",
                lastName: "User\(i)"
            )
            
            try await app.test(.POST, "/api/auth/sign-up", beforeRequest: { req in
                try req.content.encode(request)
            }, afterResponse: { res in
                XCTAssertEqual(res.status, .ok)
            })
            
            times.append(Date().timeIntervalSince(startTime))
        }
        
        return ExtendedPerformanceMetrics(times: times)
    }
    
    private func measureSignInPerformance() async throws -> ExtendedPerformanceMetrics {
        // Create test user
        let email = "signin-perf@example.com"
        let password = "TestPass123!"
        
        let signUpRequest = Auth.SignUp.Request(
            email: email,
            password: password,
            firstName: "SignIn",
            lastName: "Test"
        )
        
        try await app.test(.POST, "/api/auth/sign-up", beforeRequest: { req in
            try req.content.encode(signUpRequest)
        })
        
        // Measure sign-in
        var times: [TimeInterval] = []
        let iterations = 100
        
        for _ in 0..<iterations {
            let startTime = Date()
            
            let signInRequest = Auth.SignIn.Request(email: email, password: password)
            
            try await app.test(.POST, "/api/auth/sign-in", beforeRequest: { req in
                try req.content.encode(signInRequest)
            }, afterResponse: { res in
                XCTAssertEqual(res.status, .ok)
            })
            
            times.append(Date().timeIntervalSince(startTime))
        }
        
        return ExtendedPerformanceMetrics(times: times)
    }
    
    private func measureGetCurrentUserPerformance() async throws -> ExtendedPerformanceMetrics {
        // Create test user and get token
        var token = ""
        let signUpRequest = Auth.SignUp.Request(
            email: "current-user-perf@example.com",
            password: "TestPass123!",
            firstName: "Current",
            lastName: "User"
        )
        
        try await app.test(.POST, "/api/auth/sign-up", beforeRequest: { req in
            try req.content.encode(signUpRequest)
        }, afterResponse: { res in
            let response = try res.content.decode(Auth.SignUp.Response.self)
            token = response.token.accessToken
        })
        
        // Measure get current user
        var times: [TimeInterval] = []
        let iterations = 200
        
        for _ in 0..<iterations {
            let startTime = Date()
            
            try await app.test(.GET, "/api/user", beforeRequest: { req in
                req.headers.bearerAuthorization = BearerAuthorization(token: token)
            }, afterResponse: { res in
                XCTAssertEqual(res.status, .ok)
            })
            
            times.append(Date().timeIntervalSince(startTime))
        }
        
        return ExtendedPerformanceMetrics(times: times)
    }
    
    private func measureUpdateProfilePerformance() async throws -> ExtendedPerformanceMetrics {
        // Create test user and get token
        var token = ""
        let signUpRequest = Auth.SignUp.Request(
            email: "update-profile-perf@example.com",
            password: "TestPass123!",
            firstName: "Update",
            lastName: "Profile"
        )
        
        try await app.test(.POST, "/api/auth/sign-up", beforeRequest: { req in
            try req.content.encode(signUpRequest)
        }, afterResponse: { res in
            let response = try res.content.decode(Auth.SignUp.Response.self)
            token = response.token.accessToken
        })
        
        // Measure profile updates
        var times: [TimeInterval] = []
        let iterations = 100
        
        for i in 0..<iterations {
            let startTime = Date()
            
            let updateRequest = User.Patch.Request(
                firstName: "Updated\(i)",
                lastName: "Name\(i)"
            )
            
            try await app.test(.PATCH, "/api/user", beforeRequest: { req in
                req.headers.bearerAuthorization = BearerAuthorization(token: token)
                try req.content.encode(updateRequest)
            }, afterResponse: { res in
                XCTAssertEqual(res.status, .ok)
            })
            
            times.append(Date().timeIntervalSince(startTime))
        }
        
        return ExtendedPerformanceMetrics(times: times)
    }
    
    private func measureGenerateRulesPerformance() async throws -> ExtendedPerformanceMetrics {
        // Setup mock LLM service
        testWorld.llm.responseDelay = 0.001
        testWorld.llm.setResponse(for: "generate", response: """
            {"sections": [{"title": "Rules", "content": "Test rules"}]}
            """)
        
        // Create test user and get token
        var token = ""
        let signUpRequest = Auth.SignUp.Request(
            email: "rules-perf@example.com",
            password: "TestPass123!",
            firstName: "Rules",
            lastName: "Test"
        )
        
        try await app.test(.POST, "/api/auth/sign-up", beforeRequest: { req in
            try req.content.encode(signUpRequest)
        }, afterResponse: { res in
            let response = try res.content.decode(Auth.SignUp.Response.self)
            token = response.token.accessToken
        })
        
        // Measure rules generation
        var times: [TimeInterval] = []
        let iterations = 100
        
        for i in 0..<iterations {
            let startTime = Date()
            
            let request = GenerateRules.Request(
                gameName: "Test Game \(i)",
                playerCount: "2-4",
                gameContext: "Test context",
                complexity: "medium",
                customPrompt: nil
            )
            
            try await app.test(.POST, "/api/rules/generate", beforeRequest: { req in
                req.headers.bearerAuthorization = BearerAuthorization(token: token)
                try req.content.encode(request)
            }, afterResponse: { res in
                XCTAssertEqual(res.status, .ok)
            })
            
            times.append(Date().timeIntervalSince(startTime))
        }
        
        return ExtendedPerformanceMetrics(times: times)
    }
    
    private func measureAnalyzeGameBoxPerformance() async throws -> ExtendedPerformanceMetrics {
        // Setup mock LLM service
        testWorld.llm.responseDelay = 0.001
        testWorld.llm.setResponse(for: "identify", response: """
            {"game_name": "Test Game", "confidence": 0.95}
            """)
        
        // Create test user and get token
        var token = ""
        let signUpRequest = Auth.SignUp.Request(
            email: "analyze-perf@example.com",
            password: "TestPass123!",
            firstName: "Analyze",
            lastName: "Test"
        )
        
        try await app.test(.POST, "/api/auth/sign-up", beforeRequest: { req in
            try req.content.encode(signUpRequest)
        }, afterResponse: { res in
            let response = try res.content.decode(Auth.SignUp.Response.self)
            token = response.token.accessToken
        })
        
        // Measure game box analysis
        var times: [TimeInterval] = []
        let iterations = 100
        
        for i in 0..<iterations {
            let startTime = Date()
            
            let request = AnalyzeGameBox.Request(
                imageData: Data("test-image-\(i)".utf8),
                prompt: "Analyze game"
            )
            
            try await app.test(.POST, "/api/rules/analyze", beforeRequest: { req in
                req.headers.bearerAuthorization = BearerAuthorization(token: token)
                try req.content.encode(request)
            }, afterResponse: { res in
                XCTAssertEqual(res.status, .ok)
            })
            
            times.append(Date().timeIntervalSince(startTime))
        }
        
        return ExtendedPerformanceMetrics(times: times)
    }
    
    private func measureCacheHitPerformance() async throws -> ExtendedPerformanceMetrics {
        // Setup for cache hits
        testWorld.llm.responseDelay = 0.001
        testWorld.llm.setResponse(for: "generate", response: """
            {"sections": [{"title": "Rules", "content": "Cached rules"}]}
            """)
        
        // Create test user and get token
        var token = ""
        let signUpRequest = Auth.SignUp.Request(
            email: "cache-hit-perf@example.com",
            password: "TestPass123!",
            firstName: "Cache",
            lastName: "Hit"
        )
        
        try await app.test(.POST, "/api/auth/sign-up", beforeRequest: { req in
            try req.content.encode(signUpRequest)
        }, afterResponse: { res in
            let response = try res.content.decode(Auth.SignUp.Response.self)
            token = response.token.accessToken
        })
        
        // Populate cache with initial request
        let request = GenerateRules.Request(
            gameName: "Cached Game",
            playerCount: "2-4",
            gameContext: "Cached context",
            complexity: "medium",
            customPrompt: nil
        )
        
        try await app.test(.POST, "/api/rules/generate", beforeRequest: { req in
            req.headers.bearerAuthorization = BearerAuthorization(token: token)
            try req.content.encode(request)
        })
        
        // Measure cache hits
        var times: [TimeInterval] = []
        let iterations = 200
        
        for _ in 0..<iterations {
            let startTime = Date()
            
            try await app.test(.POST, "/api/rules/generate", beforeRequest: { req in
                req.headers.bearerAuthorization = BearerAuthorization(token: token)
                try req.content.encode(request)
            }, afterResponse: { res in
                XCTAssertEqual(res.status, .ok)
            })
            
            times.append(Date().timeIntervalSince(startTime))
        }
        
        return ExtendedPerformanceMetrics(times: times)
    }
    
    private func measureCacheMissPerformance() async throws -> ExtendedPerformanceMetrics {
        // Setup for cache misses
        testWorld.llm.responseDelay = 0.001
        testWorld.llm.setResponse(for: "generate", response: """
            {"sections": [{"title": "Rules", "content": "New rules"}]}
            """)
        
        // Create test user and get token
        var token = ""
        let signUpRequest = Auth.SignUp.Request(
            email: "cache-miss-perf@example.com",
            password: "TestPass123!",
            firstName: "Cache",
            lastName: "Miss"
        )
        
        try await app.test(.POST, "/api/auth/sign-up", beforeRequest: { req in
            try req.content.encode(signUpRequest)
        }, afterResponse: { res in
            let response = try res.content.decode(Auth.SignUp.Response.self)
            token = response.token.accessToken
        })
        
        // Measure cache misses (unique requests)
        var times: [TimeInterval] = []
        let iterations = 100
        
        for i in 0..<iterations {
            let startTime = Date()
            
            let request = GenerateRules.Request(
                gameName: "Unique Game \(i)",
                playerCount: "2-4",
                gameContext: "Unique context \(i)",
                complexity: "medium",
                customPrompt: nil
            )
            
            try await app.test(.POST, "/api/rules/generate", beforeRequest: { req in
                req.headers.bearerAuthorization = BearerAuthorization(token: token)
                try req.content.encode(request)
            }, afterResponse: { res in
                XCTAssertEqual(res.status, .ok)
            })
            
            times.append(Date().timeIntervalSince(startTime))
        }
        
        return ExtendedPerformanceMetrics(times: times)
    }
    
    // MARK: - Performance Report Generation
    
    private func generatePerformanceReport(results: [(operation: String, metrics: ExtendedPerformanceMetrics)]) {
        print("\n" + String(repeating: "=", count: 80))
        print("CLEAN ARCHITECTURE PERFORMANCE VERIFICATION REPORT")
        print(String(repeating: "=", count: 80))
        print("Date: \(Date())")
        print("Environment: Testing")
        print("Database: SQLite (In-Memory)")
        print(String(repeating: "-", count: 80))
        
        for (operation, metrics) in results {
            print("\n[\(operation)]")
            print("  Samples: \(metrics.sampleCount)")
            print("  Average: \(String(format: "%.4f", metrics.averageTime))s")
            print("  Median:  \(String(format: "%.4f", metrics.medianTime))s")
            print("  Min:     \(String(format: "%.4f", metrics.minTime))s")
            print("  Max:     \(String(format: "%.4f", metrics.maxTime))s")
            print("  P95:     \(String(format: "%.4f", metrics.p95Time))s")
            print("  P99:     \(String(format: "%.4f", metrics.p99Time))s")
            print("  Std Dev: \(String(format: "%.4f", metrics.standardDeviation))s")
            print("  Throughput: \(String(format: "%.2f", metrics.throughput)) req/s")
            
            // Check against baseline if available
            if let baseline = performanceBaselines.first(where: { $0.operation == operation }) {
                let avgDiff = ((metrics.averageTime - baseline.maxAverageTime) / baseline.maxAverageTime) * 100
                let throughputDiff = ((metrics.throughput - baseline.minThroughput) / baseline.minThroughput) * 100
                
                print("  vs Baseline:")
                print("    Avg Time: \(avgDiff > 0 ? "+" : "")\(String(format: "%.1f", avgDiff))%")
                print("    Throughput: \(throughputDiff > 0 ? "+" : "")\(String(format: "%.1f", throughputDiff))%")
                
                if avgDiff <= 0 && throughputDiff >= 0 {
                    print("    Status: ✅ PASSED (Performance maintained or improved)")
                } else {
                    print("    Status: ⚠️  WARNING (Performance degradation detected)")
                }
            }
        }
        
        print("\n" + String(repeating: "=", count: 80))
        print("SUMMARY")
        print(String(repeating: "=", count: 80))
        
        let passedTests = results.filter { (operation, metrics) in
            if let baseline = performanceBaselines.first(where: { $0.operation == operation }) {
                return metrics.averageTime <= baseline.maxAverageTime && 
                       metrics.throughput >= baseline.minThroughput
            }
            return true
        }.count
        
        print("Total Operations Tested: \(results.count)")
        print("Passed Baseline: \(passedTests)")
        print("Failed Baseline: \(results.count - passedTests)")
        
        if passedTests == results.count {
            print("\n✅ ALL PERFORMANCE BASELINES MET")
            print("The Clean Architecture refactoring has maintained or improved performance.")
        } else {
            print("\n⚠️  SOME PERFORMANCE BASELINES NOT MET")
            print("Review operations that failed baseline requirements.")
        }
        
        print(String(repeating: "=", count: 80) + "\n")
    }
}

// MARK: - Extended Performance Metrics

struct ExtendedPerformanceMetrics {
    let times: [TimeInterval]
    
    var sampleCount: Int { times.count }
    
    var averageTime: TimeInterval {
        times.reduce(0, +) / Double(times.count)
    }
    
    var medianTime: TimeInterval {
        let sorted = times.sorted()
        let mid = sorted.count / 2
        if sorted.count % 2 == 0 {
            return (sorted[mid - 1] + sorted[mid]) / 2
        } else {
            return sorted[mid]
        }
    }
    
    var minTime: TimeInterval {
        times.min() ?? 0
    }
    
    var maxTime: TimeInterval {
        times.max() ?? 0
    }
    
    var p95Time: TimeInterval {
        percentile(95)
    }
    
    var p99Time: TimeInterval {
        percentile(99)
    }
    
    var standardDeviation: TimeInterval {
        let avg = averageTime
        let variance = times.reduce(0) { $0 + pow($1 - avg, 2) } / Double(times.count)
        return sqrt(variance)
    }
    
    var throughput: Double {
        1.0 / averageTime
    }
    
    private func percentile(_ p: Int) -> TimeInterval {
        let sorted = times.sorted()
        let index = Int(Double(sorted.count) * Double(p) / 100.0)
        return sorted[min(index, sorted.count - 1)]
    }
}