@testable import App
import XCTest
import XCTVapor
import Vapor

/// Performance tests for rules generation endpoints to verify Clean Architecture refactoring performance.
///
/// These tests validate that the domain services and use cases for AI operations
/// maintain or improve performance compared to the previous implementation.
final class RulesGenerationPerformanceTests: XCTestCase {
    var app: Application!
    var testWorld: TestWorld!
    var performanceTestCase: PerformanceTestCase!
    var testUserToken: String = ""
    
    override func setUp() async throws {
        app = try await Application.make(.testing)
        testWorld = try TestWorld(app: app)
        performanceTestCase = try await PerformanceTestCase()
        
        // Run migrations
        try await app.autoMigrate()
        
        // Create a test user for authenticated requests
        let signUpRequest = Auth.SignUp.Request(
            email: "rules-test@example.com",
            password: "TestPass123!",
            firstName: "Rules",
            lastName: "Test"
        )
        
        try await app.test(.POST, "/api/auth/sign-up", beforeRequest: { req in
            try req.content.encode(signUpRequest)
        }, afterResponse: { res in
            let response = try res.content.decode(Auth.SignUp.Response.self)
            testUserToken = response.token.accessToken
        })
        
        // Configure mock LLM service for predictable responses
        configureMockLLMResponses()
    }
    
    override func tearDown() async throws {
        try await app.autoRevert()
        app.shutdown()
    }
    
    private func configureMockLLMResponses() {
        // Configure fake LLM service to return fast, predictable responses
        testWorld.llm.responseDelay = 0.001 // Minimal delay for performance testing
        
        // Configure game identification response
        testWorld.llm.setResponse(
            for: "identify",
            response: """
            {
                "game_name": "Test Game",
                "confidence": 0.95,
                "players": "2-4",
                "age_range": "10+",
                "playing_time": "30-45 minutes",
                "categories": ["Strategy", "Card Game"]
            }
            """
        )
        
        // Configure rules generation response
        testWorld.llm.setResponse(
            for: "generate",
            response: """
            {
                "sections": [
                    {
                        "title": "Objective",
                        "content": "Be the first player to reach 10 points."
                    },
                    {
                        "title": "Setup",
                        "content": "Shuffle the deck and deal 7 cards to each player."
                    },
                    {
                        "title": "Gameplay",
                        "content": "Players take turns playing cards and drawing from the deck."
                    }
                ],
                "quick_start": "Deal 7 cards to each player and take turns playing cards to reach 10 points.",
                "complexity": "medium"
            }
            """
        )
    }
    
    // MARK: - Analyze Game Box Performance
    
    func testAnalyzeGameBoxPerformance() async throws {
        let metrics = try await performanceTestCase.measure(
            "Analyze Game Box Performance",
            iterations: 100
        ) {
            let request = AnalyzeGameBox.Request(
                imageData: Data("mock-image-data".utf8),
                prompt: "Identify this board game"
            )
            
            try await app.test(.POST, "/api/rules/analyze", beforeRequest: { req in
                req.headers.bearerAuthorization = BearerAuthorization(token: testUserToken)
                try req.content.encode(request)
            }, afterResponse: { res in
                XCTAssertEqual(res.status, .ok)
            })
        }
        
        print(metrics.summary)
        
        // Performance baselines (with mocked LLM service)
        XCTAssertLessThan(metrics.averageTime, 0.05, "Analyze game box average time should be under 50ms")
        XCTAssertLessThan(metrics.maximumTime, 0.1, "Analyze game box max time should be under 100ms")
        XCTAssertLessThan(metrics.standardDeviation, 0.02, "Should have consistent performance")
    }
    
    func testGenerateRulesPerformance() async throws {
        let metrics = try await performanceTestCase.measure(
            "Generate Rules Performance",
            iterations: 100
        ) {
            let request = GenerateRules.Request(
                gameName: "Test Game \(UUID())",
                playerCount: "2-4",
                gameContext: "A strategic card game",
                complexity: "medium",
                customPrompt: nil
            )
            
            try await app.test(.POST, "/api/rules/generate", beforeRequest: { req in
                req.headers.bearerAuthorization = BearerAuthorization(token: testUserToken)
                try req.content.encode(request)
            }, afterResponse: { res in
                XCTAssertEqual(res.status, .ok)
            })
        }
        
        print(metrics.summary)
        
        // Performance baselines
        XCTAssertLessThan(metrics.averageTime, 0.06, "Generate rules average time should be under 60ms")
        XCTAssertLessThan(metrics.maximumTime, 0.12, "Generate rules max time should be under 120ms")
    }
    
    // MARK: - Cache Performance Tests
    
    func testCacheHitPerformance() async throws {
        // First request to populate cache
        let request = GenerateRules.Request(
            gameName: "Cached Game",
            playerCount: "2-4",
            gameContext: "A strategic card game",
            complexity: "medium",
            customPrompt: nil
        )
        
        try await app.test(.POST, "/api/rules/generate", beforeRequest: { req in
            req.headers.bearerAuthorization = BearerAuthorization(token: testUserToken)
            try req.content.encode(request)
        })
        
        // Measure cache hit performance (should be much faster)
        let metrics = try await performanceTestCase.measure(
            "Cache Hit Performance",
            iterations: 200
        ) {
            try await app.test(.POST, "/api/rules/generate", beforeRequest: { req in
                req.headers.bearerAuthorization = BearerAuthorization(token: testUserToken)
                try req.content.encode(request)
            }, afterResponse: { res in
                XCTAssertEqual(res.status, .ok)
            })
        }
        
        print(metrics.summary)
        
        // Cache hits should be very fast
        XCTAssertLessThan(metrics.averageTime, 0.01, "Cache hit average time should be under 10ms")
        XCTAssertLessThan(metrics.maximumTime, 0.02, "Cache hit max time should be under 20ms")
    }
    
    func testCacheMissPerformance() async throws {
        // Clear cache to ensure misses
        testWorld.aiCache.clearAll()
        
        var requestIndex = 0
        let metrics = try await performanceTestCase.measure(
            "Cache Miss Performance",
            iterations: 50
        ) {
            // Each request is unique to ensure cache miss
            let request = GenerateRules.Request(
                gameName: "Unique Game \(requestIndex)",
                playerCount: "2-4",
                gameContext: "A strategic card game",
                complexity: "medium",
                customPrompt: nil
            )
            requestIndex += 1
            
            try await app.test(.POST, "/api/rules/generate", beforeRequest: { req in
                req.headers.bearerAuthorization = BearerAuthorization(token: testUserToken)
                try req.content.encode(request)
            }, afterResponse: { res in
                XCTAssertEqual(res.status, .ok)
            })
        }
        
        print(metrics.summary)
        
        // Cache misses involve LLM calls (mocked)
        XCTAssertLessThan(metrics.averageTime, 0.08, "Cache miss average time should be under 80ms")
    }
    
    // MARK: - Concurrent AI Request Performance
    
    func testConcurrentAnalyzeRequests() async throws {
        let concurrentRequests = 50
        let startTime = Date()
        
        try await withThrowingTaskGroup(of: Void.self) { group in
            for i in 0..<concurrentRequests {
                group.addTask {
                    let request = AnalyzeGameBox.Request(
                        imageData: Data("mock-image-\(i)".utf8),
                        prompt: "Identify board game \(i)"
                    )
                    
                    try await self.app.test(.POST, "/api/rules/analyze", beforeRequest: { req in
                        req.headers.bearerAuthorization = BearerAuthorization(token: self.testUserToken)
                        try req.content.encode(request)
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
        Concurrent Analyze Requests Performance:
        Total Requests: \(concurrentRequests)
        Total Time: \(String(format: "%.4f", totalTime))s
        Requests per Second: \(String(format: "%.2f", requestsPerSecond))
        """)
        
        XCTAssertLessThan(totalTime, 3.0, "50 concurrent analyze requests should complete within 3 seconds")
        XCTAssertGreaterThan(requestsPerSecond, 15, "Should handle at least 15 analyze requests per second")
    }
    
    func testConcurrentGenerateRulesRequests() async throws {
        let concurrentRequests = 30
        let startTime = Date()
        
        try await withThrowingTaskGroup(of: Void.self) { group in
            for i in 0..<concurrentRequests {
                group.addTask {
                    let request = GenerateRules.Request(
                        gameName: "Concurrent Game \(i)",
                        playerCount: "2-4",
                        gameContext: "Game context \(i)",
                        complexity: "medium",
                        customPrompt: nil
                    )
                    
                    try await self.app.test(.POST, "/api/rules/generate", beforeRequest: { req in
                        req.headers.bearerAuthorization = BearerAuthorization(token: self.testUserToken)
                        try req.content.encode(request)
                    }, afterResponse: { res in
                        XCTAssertEqual(res.status, .ok)
                    })
                }
            }
            
            try await group.waitForAll()
        }
        
        let totalTime = Date().timeIntervalSince(startTime)
        
        print("""
        Concurrent Generate Rules Performance:
        Total Requests: \(concurrentRequests)
        Total Time: \(String(format: "%.4f", totalTime))s
        Average Time per Request: \(String(format: "%.4f", totalTime / Double(concurrentRequests)))s
        """)
        
        XCTAssertLessThan(totalTime, 4.0, "30 concurrent generate requests should complete within 4 seconds")
    }
    
    // MARK: - Domain Service Performance
    
    func testRulesOrchestrationServicePerformance() async throws {
        // Test the performance of the orchestration service directly
        let orchestrationService = app.services.domain.rulesOrchestration
        
        let startTime = Date()
        var totalOperations = 0
        
        for i in 0..<50 {
            // Test game identification
            _ = try await orchestrationService.identifyGame(
                from: Data("test-image-\(i)".utf8),
                additionalContext: "Test context \(i)"
            )
            totalOperations += 1
            
            // Test rules generation
            _ = try await orchestrationService.generateRules(
                gameName: "Test Game \(i)",
                playerCount: "2-4",
                gameContext: "Context \(i)",
                complexity: "medium",
                customPrompt: nil
            )
            totalOperations += 1
        }
        
        let totalTime = Date().timeIntervalSince(startTime)
        let avgTimePerOperation = totalTime / Double(totalOperations)
        
        print("""
        Rules Orchestration Service Performance:
        Total Operations: \(totalOperations)
        Total Time: \(String(format: "%.4f", totalTime))s
        Average Time per Operation: \(String(format: "%.4f", avgTimePerOperation))s
        """)
        
        XCTAssertLessThan(avgTimePerOperation, 0.05, "Orchestration service should average under 50ms per operation")
    }
    
    // MARK: - Input Validation Performance
    
    func testInputValidationPerformance() async throws {
        // Test with various invalid inputs to measure validation overhead
        let invalidRequests = [
            GenerateRules.Request(gameName: "", playerCount: "2-4", gameContext: "Context", complexity: "medium", customPrompt: nil),
            GenerateRules.Request(gameName: "Game", playerCount: "", gameContext: "Context", complexity: "medium", customPrompt: nil),
            GenerateRules.Request(gameName: "Game", playerCount: "2-4", gameContext: "", complexity: "invalid", customPrompt: nil)
        ]
        
        let metrics = try await performanceTestCase.measure(
            "Input Validation Performance",
            iterations: 100
        ) {
            let request = invalidRequests[Int.random(in: 0..<invalidRequests.count)]
            
            try await app.test(.POST, "/api/rules/generate", beforeRequest: { req in
                req.headers.bearerAuthorization = BearerAuthorization(token: testUserToken)
                try req.content.encode(request)
            }, afterResponse: { res in
                // Expect validation to catch these
                XCTAssertNotEqual(res.status, .ok)
            })
        }
        
        print(metrics.summary)
        
        // Validation should be very fast
        XCTAssertLessThan(metrics.averageTime, 0.005, "Input validation average time should be under 5ms")
        XCTAssertLessThan(metrics.maximumTime, 0.01, "Input validation max time should be under 10ms")
    }
    
    // MARK: - Memory Performance for AI Operations
    
    func testAIOperationMemoryEfficiency() async throws {
        var memoryReadings: [Int] = []
        let iterations = 50
        
        for i in 0..<iterations {
            // Alternate between analyze and generate
            if i % 2 == 0 {
                let request = AnalyzeGameBox.Request(
                    imageData: Data("large-image-data-\(i)".utf8),
                    prompt: "Analyze game \(i)"
                )
                
                try await app.test(.POST, "/api/rules/analyze", beforeRequest: { req in
                    req.headers.bearerAuthorization = BearerAuthorization(token: testUserToken)
                    try req.content.encode(request)
                })
            } else {
                let request = GenerateRules.Request(
                    gameName: "Memory Test Game \(i)",
                    playerCount: "2-4",
                    gameContext: "Memory test context \(i)",
                    complexity: "medium",
                    customPrompt: String(repeating: "Custom prompt ", count: 100)
                )
                
                try await app.test(.POST, "/api/rules/generate", beforeRequest: { req in
                    req.headers.bearerAuthorization = BearerAuthorization(token: testUserToken)
                    try req.content.encode(request)
                })
            }
            
            // Capture memory usage periodically
            if i % 10 == 0 {
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
            AI Operations Memory Performance:
            Initial Memory: \(firstReading / 1024 / 1024) MB
            Final Memory: \(lastReading / 1024 / 1024) MB
            Total Growth: \(memoryGrowth / 1024 / 1024) MB
            Average Growth per Operation: \(avgGrowthPerIteration / 1024) KB
            """)
            
            // Memory growth should be minimal with proper cleanup
            XCTAssertLessThan(avgGrowthPerIteration, 200 * 1024, "Memory growth per AI operation should be under 200KB")
        }
    }
}