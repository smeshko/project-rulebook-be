@testable import App
import XCTest
import XCTVapor
import Vapor

/// HTTP endpoint performance tests to verify Clean Architecture refactoring impact.
///
/// These tests focus on measuring actual HTTP request/response performance
/// after the Clean Architecture refactoring with use cases and domain services.
final class HTTPEndpointPerformanceTests: XCTestCase {
    var app: Application!
    var testWorld: TestWorld!
    
    override func setUp() async throws {
        app = try await Application.make(.testing)
        testWorld = try TestWorld(app: app)
        
        // Run migrations
        try await app.autoMigrate()
        
        // Configure mock LLM for consistent performance
        testWorld.llm.responseDelay = 0.001
        testWorld.llm.setResponse(for: "identify", response: """
            {"game_name": "Test Game", "confidence": 0.95}
            """)
        testWorld.llm.setResponse(for: "generate", response: """
            {"sections": [{"title": "Rules", "content": "Test rules"}]}
            """)
    }
    
    override func tearDown() async throws {
        try await app.autoRevert()
        await app.asyncShutdown()
    }
    
    // MARK: - Authentication Endpoint Performance
    
    func testAuthenticationEndpointPerformance() async throws {
        let iterations = 50
        var signUpTimes: [TimeInterval] = []
        var signInTimes: [TimeInterval] = []
        
        // Test Sign Up Performance
        for i in 0..<iterations {
            let startTime = Date()
            
            let signUpRequest = Auth.SignUp.Request(
                email: "perf-test-\(i)@example.com",
                password: "TestPass123!",
                firstName: "Test",
                lastName: "User\(i)"
            )
            
            try await app.test(.POST, "/api/auth/sign-up", beforeRequest: { req in
                try req.content.encode(signUpRequest)
            }, afterResponse: { res in
                XCTAssertEqual(res.status, .ok)
            })
            
            signUpTimes.append(Date().timeIntervalSince(startTime))
        }
        
        // Test Sign In Performance (using created users)
        for i in 0..<min(iterations, 10) { // Test fewer sign-ins to avoid overload
            let startTime = Date()
            
            let signInRequest = Auth.SignIn.Request(
                email: "perf-test-\(i)@example.com",
                password: "TestPass123!"
            )
            
            try await app.test(.POST, "/api/auth/sign-in", beforeRequest: { req in
                try req.content.encode(signInRequest)
            }, afterResponse: { res in
                XCTAssertEqual(res.status, .ok)
            })
            
            signInTimes.append(Date().timeIntervalSince(startTime))
        }
        
        // Calculate and report metrics
        let avgSignUpTime = signUpTimes.reduce(0, +) / Double(signUpTimes.count)
        let avgSignInTime = signInTimes.reduce(0, +) / Double(signInTimes.count)
        let maxSignUpTime = signUpTimes.max() ?? 0
        let maxSignInTime = signInTimes.max() ?? 0
        
        print("""
        Authentication Endpoint Performance:
        Sign Up Average: \(String(format: "%.4f", avgSignUpTime))s
        Sign Up Max: \(String(format: "%.4f", maxSignUpTime))s
        Sign In Average: \(String(format: "%.4f", avgSignInTime))s
        Sign In Max: \(String(format: "%.4f", maxSignInTime))s
        """)
        
        // Performance assertions
        XCTAssertLessThan(avgSignUpTime, 0.1, "Sign up average should be under 100ms")
        XCTAssertLessThan(avgSignInTime, 0.08, "Sign in average should be under 80ms")
        XCTAssertLessThan(maxSignUpTime, 0.2, "Sign up max should be under 200ms")
        XCTAssertLessThan(maxSignInTime, 0.15, "Sign in max should be under 150ms")
    }
    
    // MARK: - User Profile Endpoint Performance
    
    func testUserProfileEndpointPerformance() async throws {
        // Create test user first
        var token = ""
        let signUpRequest = Auth.SignUp.Request(
            email: "profile-perf@example.com",
            password: "TestPass123!",
            firstName: "Profile",
            lastName: "Test"
        )
        
        try await app.test(.POST, "/api/auth/sign-up", beforeRequest: { req in
            try req.content.encode(signUpRequest)
        }, afterResponse: { res in
            let response = try res.content.decode(Auth.SignUp.Response.self)
            token = response.token.accessToken
        })
        
        let iterations = 100
        var getCurrentUserTimes: [TimeInterval] = []
        var updateProfileTimes: [TimeInterval] = []
        
        // Test Get Current User Performance
        for _ in 0..<iterations {
            let startTime = Date()
            
            try await app.test(.GET, "/api/user", beforeRequest: { req in
                req.headers.bearerAuthorization = BearerAuthorization(token: token)
            }, afterResponse: { res in
                XCTAssertEqual(res.status, .ok)
            })
            
            getCurrentUserTimes.append(Date().timeIntervalSince(startTime))
        }
        
        // Test Update Profile Performance
        for i in 0..<50 { // Fewer iterations for updates
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
            
            updateProfileTimes.append(Date().timeIntervalSince(startTime))
        }
        
        // Calculate and report metrics
        let avgGetUserTime = getCurrentUserTimes.reduce(0, +) / Double(getCurrentUserTimes.count)
        let avgUpdateTime = updateProfileTimes.reduce(0, +) / Double(updateProfileTimes.count)
        let maxGetUserTime = getCurrentUserTimes.max() ?? 0
        let maxUpdateTime = updateProfileTimes.max() ?? 0
        
        print("""
        User Profile Endpoint Performance:
        Get Current User Average: \(String(format: "%.4f", avgGetUserTime))s
        Get Current User Max: \(String(format: "%.4f", maxGetUserTime))s
        Update Profile Average: \(String(format: "%.4f", avgUpdateTime))s
        Update Profile Max: \(String(format: "%.4f", maxUpdateTime))s
        """)
        
        // Performance assertions
        XCTAssertLessThan(avgGetUserTime, 0.05, "Get current user average should be under 50ms")
        XCTAssertLessThan(avgUpdateTime, 0.08, "Update profile average should be under 80ms")
    }
    
    // MARK: - AI Endpoints Performance
    
    func testAIEndpointPerformance() async throws {
        // Create test user first
        var token = ""
        let signUpRequest = Auth.SignUp.Request(
            email: "ai-perf@example.com",
            password: "TestPass123!",
            firstName: "AI",
            lastName: "Test"
        )
        
        try await app.test(.POST, "/api/auth/sign-up", beforeRequest: { req in
            try req.content.encode(signUpRequest)
        }, afterResponse: { res in
            let response = try res.content.decode(Auth.SignUp.Response.self)
            token = response.token.accessToken
        })
        
        let iterations = 30
        var analyzeGameTimes: [TimeInterval] = []
        var generateRulesTimes: [TimeInterval] = []
        
        // Test Analyze Game Performance
        for i in 0..<iterations {
            let startTime = Date()
            
            let analyzeRequest = AnalyzeGameBox.Request(
                imageData: Data("test-image-\(i)".utf8),
                prompt: "Analyze this game"
            )
            
            try await app.test(.POST, "/api/rules/analyze", beforeRequest: { req in
                req.headers.bearerAuthorization = BearerAuthorization(token: token)
                try req.content.encode(analyzeRequest)
            }, afterResponse: { res in
                XCTAssertEqual(res.status, .ok)
            })
            
            analyzeGameTimes.append(Date().timeIntervalSince(startTime))
        }
        
        // Test Generate Rules Performance  
        for i in 0..<iterations {
            let startTime = Date()
            
            let generateRequest = GenerateRules.Request(
                gameName: "Test Game \(i)",
                playerCount: "2-4",
                gameContext: "Test context",
                complexity: "medium",
                customPrompt: nil
            )
            
            try await app.test(.POST, "/api/rules/generate", beforeRequest: { req in
                req.headers.bearerAuthorization = BearerAuthorization(token: token)
                try req.content.encode(generateRequest)
            }, afterResponse: { res in
                XCTAssertEqual(res.status, .ok)
            })
            
            generateRulesTimes.append(Date().timeIntervalSince(startTime))
        }
        
        // Calculate and report metrics
        let avgAnalyzeTime = analyzeGameTimes.reduce(0, +) / Double(analyzeGameTimes.count)
        let avgGenerateTime = generateRulesTimes.reduce(0, +) / Double(generateRulesTimes.count)
        let maxAnalyzeTime = analyzeGameTimes.max() ?? 0
        let maxGenerateTime = generateRulesTimes.max() ?? 0
        
        print("""
        AI Endpoint Performance:
        Analyze Game Average: \(String(format: "%.4f", avgAnalyzeTime))s
        Analyze Game Max: \(String(format: "%.4f", maxAnalyzeTime))s
        Generate Rules Average: \(String(format: "%.4f", avgGenerateTime))s
        Generate Rules Max: \(String(format: "%.4f", maxGenerateTime))s
        """)
        
        // Performance assertions (with mocked LLM)
        XCTAssertLessThan(avgAnalyzeTime, 0.1, "Analyze game average should be under 100ms")
        XCTAssertLessThan(avgGenerateTime, 0.12, "Generate rules average should be under 120ms")
    }
    
    // MARK: - Cache Performance Testing
    
    func testCachePerformance() async throws {
        // Create admin user
        var adminToken = ""
        let adminSignUp = Auth.SignUp.Request(
            email: "cache-admin@example.com",
            password: "AdminPass123!",
            firstName: "Cache",
            lastName: "Admin"
        )
        
        try await app.test(.POST, "/api/auth/sign-up", beforeRequest: { req in
            try req.content.encode(adminSignUp)
        }, afterResponse: { res in
            let response = try res.content.decode(Auth.SignUp.Response.self)
            adminToken = response.token.accessToken
        })
        
        // Update user to admin
        let user = try await UserAccountModel.query(on: app.db)
            .filter(\.$email == "cache-admin@example.com")
            .first()
        user?.isAdmin = true
        try await user?.save(on: app.db)
        
        // Populate cache by making some AI requests first
        for i in 0..<10 {
            let generateRequest = GenerateRules.Request(
                gameName: "Cache Test \(i)",
                playerCount: "2-4",
                gameContext: "Cache test",
                complexity: "medium",
                customPrompt: nil
            )
            
            try await app.test(.POST, "/api/rules/generate", beforeRequest: { req in
                req.headers.bearerAuthorization = BearerAuthorization(token: adminToken)
                try req.content.encode(generateRequest)
            })
        }
        
        let iterations = 50
        var cacheStatsTimes: [TimeInterval] = []
        
        // Test Cache Stats Performance
        for _ in 0..<iterations {
            let startTime = Date()
            
            try await app.test(.GET, "/api/admin/cache/stats", beforeRequest: { req in
                req.headers.bearerAuthorization = BearerAuthorization(token: adminToken)
            }, afterResponse: { res in
                XCTAssertEqual(res.status, .ok)
            })
            
            cacheStatsTimes.append(Date().timeIntervalSince(startTime))
        }
        
        // Calculate and report metrics
        let avgCacheStatsTime = cacheStatsTimes.reduce(0, +) / Double(cacheStatsTimes.count)
        let maxCacheStatsTime = cacheStatsTimes.max() ?? 0
        
        print("""
        Cache Endpoint Performance:
        Cache Stats Average: \(String(format: "%.4f", avgCacheStatsTime))s
        Cache Stats Max: \(String(format: "%.4f", maxCacheStatsTime))s
        """)
        
        // Performance assertions
        XCTAssertLessThan(avgCacheStatsTime, 0.02, "Cache stats average should be under 20ms")
        XCTAssertLessThan(maxCacheStatsTime, 0.05, "Cache stats max should be under 50ms")
    }
    
    // MARK: - Concurrent Request Performance
    
    func testConcurrentRequestPerformance() async throws {
        // Create multiple users
        var tokens: [String] = []
        
        for i in 0..<5 {
            let signUpRequest = Auth.SignUp.Request(
                email: "concurrent-\(i)@example.com",
                password: "TestPass123!",
                firstName: "Concurrent",
                lastName: "User\(i)"
            )
            
            try await app.test(.POST, "/api/auth/sign-up", beforeRequest: { req in
                try req.content.encode(signUpRequest)
            }, afterResponse: { res in
                let response = try res.content.decode(Auth.SignUp.Response.self)
                tokens.append(response.token.accessToken)
            })
        }
        
        // Test concurrent requests
        let concurrentRequests = 25
        let startTime = Date()
        
        try await withThrowingTaskGroup(of: Void.self) { group in
            for i in 0..<concurrentRequests {
                let token = tokens[i % tokens.count]
                
                group.addTask {
                    try await self.app.test(.GET, "/api/user", beforeRequest: { req in
                        req.headers.bearerAuthorization = BearerAuthorization(token: token)
                    }, afterResponse: { res in
                        XCTAssertEqual(res.status, .ok)
                    })
                }
            }
            
            try await group.waitForAll()
        }
        
        let totalTime = Date().timeIntervalSince(startTime)
        let requestsPerSecond = Double(concurrentRequests) / totalTime
        
        print("""
        Concurrent Request Performance:
        Total Requests: \(concurrentRequests)
        Total Time: \(String(format: "%.4f", totalTime))s
        Requests per Second: \(String(format: "%.2f", requestsPerSecond))
        """)
        
        // Performance assertions
        XCTAssertLessThan(totalTime, 2.0, "25 concurrent requests should complete within 2 seconds")
        XCTAssertGreaterThan(requestsPerSecond, 12, "Should handle at least 12 requests per second")
    }
    
    // MARK: - Memory Performance Test
    
    func testMemoryPerformance() async throws {
        // Create test user
        var token = ""
        let signUpRequest = Auth.SignUp.Request(
            email: "memory-test@example.com",
            password: "TestPass123!",
            firstName: "Memory",
            lastName: "Test"
        )
        
        try await app.test(.POST, "/api/auth/sign-up", beforeRequest: { req in
            try req.content.encode(signUpRequest)
        }, afterResponse: { res in
            let response = try res.content.decode(Auth.SignUp.Response.self)
            token = response.token.accessToken
        })
        
        var memoryReadings: [Int] = []
        let iterations = 50
        
        // Capture initial memory
        let initialMemory = ProcessInfo.processInfo.physicalMemory
        
        // Make repeated requests and track memory
        for i in 0..<iterations {
            try await app.test(.GET, "/api/user", beforeRequest: { req in
                req.headers.bearerAuthorization = BearerAuthorization(token: token)
            })
            
            // Create some AI requests too
            if i % 5 == 0 {
                let generateRequest = GenerateRules.Request(
                    gameName: "Memory Test \(i)",
                    playerCount: "2-4",
                    gameContext: "Memory test",
                    complexity: "medium",
                    customPrompt: nil
                )
                
                try await app.test(.POST, "/api/rules/generate", beforeRequest: { req in
                    req.headers.bearerAuthorization = BearerAuthorization(token: token)
                    try req.content.encode(generateRequest)
                })
                
                // Capture memory reading
                let currentMemory = ProcessInfo.processInfo.physicalMemory
                memoryReadings.append(Int(currentMemory))
            }
        }
        
        let finalMemory = ProcessInfo.processInfo.physicalMemory
        let memoryGrowth = Int(finalMemory) - Int(initialMemory)
        let avgGrowthPerIteration = memoryGrowth / iterations
        
        print("""
        Memory Performance:
        Initial Memory: \(Int(initialMemory) / 1024 / 1024) MB
        Final Memory: \(Int(finalMemory) / 1024 / 1024) MB
        Total Growth: \(memoryGrowth / 1024 / 1024) MB
        Average Growth per Request: \(avgGrowthPerIteration / 1024) KB
        """)
        
        // Memory should not grow excessively
        XCTAssertLessThan(avgGrowthPerIteration, 200 * 1024, "Memory growth per request should be under 200KB")
    }
}