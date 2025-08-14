@testable import App
import XCTest
import XCTVapor
import Vapor
import Testing

/// Comprehensive load testing framework for Phase 5 performance validation
/// 
/// Tests API endpoints under realistic load conditions to validate P95 response time
/// targets and overall system performance with caching optimizations.
final class APILoadTests: PerformanceTestCase {
    
    var testWorld: TestWorld!
    var testUser: UserWithTokens!
    
    override func setUp() async throws {
        try await super.setUp()
        testWorld = try TestWorld(app: application)
        testWorld.configureForAITesting()
        
        // Create authenticated test user
        testUser = try testWorld.createUserWithTokens()
    }
    
    override func tearDown() async throws {
        await testWorld.resetAll()
        try await super.tearDown()
    }
    
    // MARK: - Rules Generation Load Tests
    
    @Test("Rules generation endpoint performance under load")
    func testRulesGenerationLoadPerformance() async throws {
        let requests = 100
        let concurrency = 10
        var responseTimes: [TimeInterval] = []
        var successCount = 0
        var errorCount = 0
        
        // Test payload
        let requestBody = GenerateRulesRequest(
            gameTitle: "Medieval Strategy Game",
            gameDescription: "A strategic board game set in medieval times",
            playerCount: "2-4",
            playTime: "60-90 minutes",
            gameComponents: ["board", "cards", "tokens", "dice"],
            gameTheme: "medieval",
            complexityLevel: "medium"
        )
        
        print("=== Rules Generation Load Test ===")
        print("Requests: \(requests), Concurrency: \(concurrency)")
        
        // Run load test
        let startTime = Date()
        let batches = (requests + concurrency - 1) / concurrency
        
        for batch in 0..<batches {
            let batchStart = batch * concurrency
            let batchEnd = min(batchStart + concurrency, requests)
            let batchSize = batchEnd - batchStart
            
            await withTaskGroup(of: (TimeInterval, Bool).self) { group in
                for _ in 0..<batchSize {
                    group.addTask {
                        let requestStartTime = Date()
                        
                        do {
                            try await self.application.test(.POST, "/api/rules/generate") { request in
                                request.headers.bearerAuthorization = BearerAuthorization(token: self.testUser.accessToken)
                                try request.content.encode(requestBody)
                            } content: { response in
                                let responseTime = Date().timeIntervalSince(requestStartTime)
                                
                                if response.status == .ok {
                                    return (responseTime, true)
                                } else {
                                    return (responseTime, false)
                                }
                            }
                        } catch {
                            let responseTime = Date().timeIntervalSince(requestStartTime)
                            return (responseTime, false)
                        }
                    }
                }
                
                for await (responseTime, success) in group {
                    responseTimes.append(responseTime)
                    if success {
                        successCount += 1
                    } else {
                        errorCount += 1
                    }
                }
            }
            
            // Brief pause between batches to avoid overwhelming the system
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }
        
        let totalDuration = Date().timeIntervalSince(startTime)
        
        let loadResults = PerformanceTestUtilities.LoadTestResults(
            testName: "Rules Generation Load Test",
            totalRequests: requests,
            concurrentUsers: concurrency,
            duration: totalDuration,
            successfulRequests: successCount,
            failedRequests: errorCount,
            responseTimes: responseTimes,
            throughput: Double(successCount) / totalDuration,
            errorRate: Double(errorCount) / Double(requests) * 100.0,
            cacheHitRate: await getCacheHitRate()
        )
        
        print(loadResults.summary)
        
        // Assert performance requirements
        PerformanceTestUtilities.assertP95ResponseTime(loadResults.p95ResponseTime)
        PerformanceTestUtilities.assertThroughput(loadResults.throughput, minimum: 5.0)
        XCTAssertLessThan(loadResults.errorRate, 5.0, "Error rate should be under 5%")
        XCTAssertGreaterThan(loadResults.successRate, 95.0, "Success rate should exceed 95%")
    }
    
    @Test("Game box analysis endpoint performance under load")
    func testGameBoxAnalysisLoadPerformance() async throws {
        let requests = 50 // Fewer requests for image processing
        let concurrency = 5
        
        // Test payload with mock image data
        let requestBody = AnalyzeGameBoxRequest(
            imageData: generateMockImageData(),
            analysisType: "components"
        )
        
        let loadResults = try await runAPILoadTest(
            endpoint: "/api/rules/analyze-box",
            method: .POST,
            requestBody: requestBody,
            requests: requests,
            concurrency: concurrency,
            testName: "Game Box Analysis"
        )
        
        print("=== Game Box Analysis Load Test Results ===")
        print(loadResults.summary)
        
        // Image processing has higher latency expectations
        PerformanceTestUtilities.assertP95ResponseTime(
            loadResults.p95ResponseTime,
            target: PerformanceTestUtilities.PerformanceTargets.p95UncachedResponseTime
        )
        
        PerformanceTestUtilities.assertThroughput(loadResults.throughput, minimum: 2.0)
        XCTAssertLessThan(loadResults.errorRate, 10.0, "Error rate should be under 10% for image processing")
    }
    
    // MARK: - Authentication Load Tests
    
    @Test("Authentication endpoints performance under load")
    func testAuthenticationLoadPerformance() async throws {
        let requests = 200
        let concurrency = 20
        
        // Test user registration under load
        let signupResults = try await runAuthenticationLoadTest(
            requests: requests / 2,
            concurrency: concurrency,
            testName: "User Registration"
        )
        
        print("=== Authentication Load Test Results ===")
        print(signupResults.summary)
        
        // Authentication should be fast
        PerformanceTestUtilities.assertP95ResponseTime(signupResults.p95ResponseTime, target: 0.500)
        PerformanceTestUtilities.assertThroughput(signupResults.throughput, minimum: 20.0)
        XCTAssertLessThan(signupResults.errorRate, 2.0, "Auth error rate should be under 2%")
    }
    
    @Test("User profile endpoints performance under load")
    func testUserProfileLoadPerformance() async throws {
        let requests = 300
        let concurrency = 15
        
        let profileResults = try await runAPILoadTest(
            endpoint: "/api/users/current",
            method: .GET,
            requestBody: EmptyContent(),
            requests: requests,
            concurrency: concurrency,
            testName: "User Profile Retrieval"
        )
        
        print("=== User Profile Load Test Results ===")
        print(profileResults.summary)
        
        // Profile retrieval should be very fast (cached data)
        PerformanceTestUtilities.assertP95ResponseTime(profileResults.p95ResponseTime, target: 0.100)
        PerformanceTestUtilities.assertThroughput(profileResults.throughput, minimum: 50.0)
        XCTAssertLessThan(profileResults.errorRate, 1.0, "Profile retrieval error rate should be under 1%")
    }
    
    // MARK: - Cache Admin Load Tests
    
    @Test("Cache admin endpoints performance under load")
    func testCacheAdminLoadPerformance() async throws {
        let requests = 100
        let concurrency = 10
        
        // Test cache statistics endpoint
        let cacheStatsResults = try await runAPILoadTest(
            endpoint: "/api/cache/stats",
            method: .GET,
            requestBody: EmptyContent(),
            requests: requests,
            concurrency: concurrency,
            testName: "Cache Statistics"
        )
        
        // Test cache health endpoint  
        let cacheHealthResults = try await runAPILoadTest(
            endpoint: "/api/cache/health",
            method: .GET,
            requestBody: EmptyContent(),
            requests: requests,
            concurrency: concurrency,
            testName: "Cache Health Check"
        )
        
        print("=== Cache Admin Load Test Results ===")
        print("Cache Statistics:")
        print(cacheStatsResults.summary)
        print("\nCache Health:")
        print(cacheHealthResults.summary)
        
        // Cache admin endpoints should be very fast
        PerformanceTestUtilities.assertP95ResponseTime(cacheStatsResults.p95ResponseTime, target: 0.050)
        PerformanceTestUtilities.assertP95ResponseTime(cacheHealthResults.p95ResponseTime, target: 0.050)
        
        // High throughput for simple endpoints
        PerformanceTestUtilities.assertThroughput(cacheStatsResults.throughput, minimum: 100.0)
        PerformanceTestUtilities.assertThroughput(cacheHealthResults.throughput, minimum: 100.0)
    }
    
    // MARK: - Mixed Workload Load Tests
    
    @Test("Mixed realistic workload performance")
    func testMixedWorkloadPerformance() async throws {
        let totalRequests = 200
        let concurrency = 15
        let testDuration: TimeInterval = 60.0 // 1 minute test
        
        var responseTimes: [TimeInterval] = []
        var successCount = 0
        var errorCount = 0
        var operationCounts: [String: Int] = [:]
        
        print("=== Mixed Workload Load Test ===")
        print("Duration: \(Int(testDuration))s, Concurrency: \(concurrency)")
        
        let startTime = Date()
        let endTime = startTime.addingTimeInterval(testDuration)
        
        await withTaskGroup(of: (String, TimeInterval, Bool).self) { group in
            
            // Spawn concurrent workers
            for workerIndex in 0..<concurrency {
                group.addTask {
                    var localResponseTimes: [(String, TimeInterval, Bool)] = []
                    
                    while Date() < endTime {
                        let operation = self.selectRandomOperation()
                        let requestStartTime = Date()
                        
                        let success = await self.executeOperation(operation)
                        let responseTime = Date().timeIntervalSince(requestStartTime)
                        
                        localResponseTimes.append((operation, responseTime, success))
                        
                        // Small delay between requests per worker
                        try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
                    }
                    
                    return localResponseTimes
                }
            }
            
            // Wait for all workers to complete and collect results
            for await workerResults in group {
                if let results = workerResults as? [(String, TimeInterval, Bool)] {
                    for (operation, responseTime, success) in results {
                        responseTimes.append(responseTime)
                        operationCounts[operation, default: 0] += 1
                        
                        if success {
                            successCount += 1
                        } else {
                            errorCount += 1
                        }
                    }
                }
            }
        }
        
        let actualDuration = Date().timeIntervalSince(startTime)
        let totalOperations = successCount + errorCount
        
        let mixedResults = PerformanceTestUtilities.LoadTestResults(
            testName: "Mixed Workload",
            totalRequests: totalOperations,
            concurrentUsers: concurrency,
            duration: actualDuration,
            successfulRequests: successCount,
            failedRequests: errorCount,
            responseTimes: responseTimes,
            throughput: Double(successCount) / actualDuration,
            errorRate: Double(errorCount) / Double(totalOperations) * 100.0,
            cacheHitRate: await getCacheHitRate()
        )
        
        print(mixedResults.summary)
        print("\nOperation Distribution:")
        for (operation, count) in operationCounts.sorted(by: { $0.key < $1.key }) {
            print("  \(operation): \(count)")
        }
        
        // Assert mixed workload performance
        PerformanceTestUtilities.assertP95ResponseTime(mixedResults.p95ResponseTime, target: 1.0) // Higher target for mixed
        PerformanceTestUtilities.assertThroughput(mixedResults.throughput, minimum: 10.0)
        XCTAssertLessThan(mixedResults.errorRate, 5.0, "Mixed workload error rate should be under 5%")
        XCTAssertGreaterThan(mixedResults.cacheHitRate, 0.5, "Mixed workload should benefit from caching")
    }
    
    // MARK: - Stress Testing
    
    @Test("System stress test with high concurrency")
    func testHighConcurrencyStress() async throws {
        let requests = 500
        let concurrency = 50 // High concurrency to stress test
        
        let stressResults = try await runAPILoadTest(
            endpoint: "/api/users/current", // Simple endpoint for stress testing
            method: .GET,
            requestBody: EmptyContent(),
            requests: requests,
            concurrency: concurrency,
            testName: "High Concurrency Stress Test"
        )
        
        print("=== High Concurrency Stress Test Results ===")
        print(stressResults.summary)
        
        // Under stress, we allow higher response times but require stability
        XCTAssertLessThan(stressResults.p95ResponseTime, 2.0, "P95 should be under 2s even under stress")
        XCTAssertLessThan(stressResults.errorRate, 10.0, "Error rate should be under 10% under stress")
        XCTAssertGreaterThan(stressResults.successRate, 90.0, "Success rate should be above 90% under stress")
    }
    
    // MARK: - Helper Methods
    
    private func runAPILoadTest<T: Codable>(
        endpoint: String,
        method: HTTPMethod,
        requestBody: T,
        requests: Int,
        concurrency: Int,
        testName: String
    ) async throws -> PerformanceTestUtilities.LoadTestResults {
        
        var responseTimes: [TimeInterval] = []
        var successCount = 0
        var errorCount = 0
        
        let startTime = Date()
        let batches = (requests + concurrency - 1) / concurrency
        
        for batch in 0..<batches {
            let batchStart = batch * concurrency
            let batchEnd = min(batchStart + concurrency, requests)
            let batchSize = batchEnd - batchStart
            
            await withTaskGroup(of: (TimeInterval, Bool).self) { group in
                for _ in 0..<batchSize {
                    group.addTask {
                        await self.executeHTTPRequest(
                            endpoint: endpoint,
                            method: method,
                            requestBody: requestBody
                        )
                    }
                }
                
                for await (responseTime, success) in group {
                    responseTimes.append(responseTime)
                    if success {
                        successCount += 1
                    } else {
                        errorCount += 1
                    }
                }
            }
            
            // Brief pause between batches
            try await Task.sleep(nanoseconds: 50_000_000) // 50ms
        }
        
        let totalDuration = Date().timeIntervalSince(startTime)
        
        return PerformanceTestUtilities.LoadTestResults(
            testName: testName,
            totalRequests: requests,
            concurrentUsers: concurrency,
            duration: totalDuration,
            successfulRequests: successCount,
            failedRequests: errorCount,
            responseTimes: responseTimes,
            throughput: Double(successCount) / totalDuration,
            errorRate: Double(errorCount) / Double(requests) * 100.0,
            cacheHitRate: await getCacheHitRate()
        )
    }
    
    private func executeHTTPRequest<T: Codable>(
        endpoint: String,
        method: HTTPMethod,
        requestBody: T
    ) async -> (TimeInterval, Bool) {
        let requestStartTime = Date()
        
        do {
            try await application.test(method, endpoint) { request in
                request.headers.bearerAuthorization = BearerAuthorization(token: testUser.accessToken)
                if !(requestBody is EmptyContent) {
                    try request.content.encode(requestBody)
                }
            } content: { response in
                let responseTime = Date().timeIntervalSince(requestStartTime)
                return (responseTime, response.status.code >= 200 && response.status.code < 300)
            }
        } catch {
            let responseTime = Date().timeIntervalSince(requestStartTime)
            return (responseTime, false)
        }
    }
    
    private func runAuthenticationLoadTest(
        requests: Int,
        concurrency: Int,
        testName: String
    ) async throws -> PerformanceTestUtilities.LoadTestResults {
        
        var responseTimes: [TimeInterval] = []
        var successCount = 0
        var errorCount = 0
        
        let startTime = Date()
        let batches = (requests + concurrency - 1) / concurrency
        
        for batch in 0..<batches {
            let batchStart = batch * concurrency
            let batchEnd = min(batchStart + concurrency, requests)
            let batchSize = batchEnd - batchStart
            
            await withTaskGroup(of: (TimeInterval, Bool).self) { group in
                for i in 0..<batchSize {
                    group.addTask {
                        let requestStartTime = Date()
                        let uniqueEmail = "loadtest_user_\(batch)_\(i)_\(UUID().uuidString.prefix(8))@example.com"
                        
                        let signupRequest = SignUpRequest(
                            name: "Load Test User",
                            email: uniqueEmail,
                            password: "StrongPassword123!",
                            confirmPassword: "StrongPassword123!"
                        )
                        
                        do {
                            try await self.application.test(.POST, "/api/auth/signup") { request in
                                try request.content.encode(signupRequest)
                            } content: { response in
                                let responseTime = Date().timeIntervalSince(requestStartTime)
                                return (responseTime, response.status == .created)
                            }
                        } catch {
                            let responseTime = Date().timeIntervalSince(requestStartTime)
                            return (responseTime, false)
                        }
                    }
                }
                
                for await (responseTime, success) in group {
                    responseTimes.append(responseTime)
                    if success {
                        successCount += 1
                    } else {
                        errorCount += 1
                    }
                }
            }
        }
        
        let totalDuration = Date().timeIntervalSince(startTime)
        
        return PerformanceTestUtilities.LoadTestResults(
            testName: testName,
            totalRequests: requests,
            concurrentUsers: concurrency,
            duration: totalDuration,
            successfulRequests: successCount,
            failedRequests: errorCount,
            responseTimes: responseTimes,
            throughput: Double(successCount) / totalDuration,
            errorRate: Double(errorCount) / Double(requests) * 100.0,
            cacheHitRate: 0.0 // No caching for auth operations
        )
    }
    
    private func selectRandomOperation() -> String {
        let operations = [
            "profile": 40,    // 40% - Most common operation
            "rules": 25,      // 25% - Main feature
            "cache_stats": 15, // 15% - Monitoring
            "analyze": 10,    // 10% - Image analysis
            "health": 10      // 10% - Health checks
        ]
        
        let random = Int.random(in: 1...100)
        var cumulative = 0
        
        for (operation, weight) in operations {
            cumulative += weight
            if random <= cumulative {
                return operation
            }
        }
        
        return "profile" // Default
    }
    
    private func executeOperation(_ operation: String) async -> Bool {
        do {
            switch operation {
            case "profile":
                try await application.test(.GET, "/api/users/current") { request in
                    request.headers.bearerAuthorization = BearerAuthorization(token: testUser.accessToken)
                } content: { response in
                    return response.status == .ok
                }
                
            case "rules":
                let rulesRequest = GenerateRulesRequest(
                    gameTitle: "Test Game \(Int.random(in: 1...1000))",
                    gameDescription: "A test game for load testing",
                    playerCount: "2-4",
                    playTime: "30-60 minutes",
                    gameComponents: ["board", "cards"],
                    gameTheme: "abstract",
                    complexityLevel: "easy"
                )
                
                try await application.test(.POST, "/api/rules/generate") { request in
                    request.headers.bearerAuthorization = BearerAuthorization(token: testUser.accessToken)
                    try request.content.encode(rulesRequest)
                } content: { response in
                    return response.status == .ok
                }
                
            case "cache_stats":
                try await application.test(.GET, "/api/cache/stats") { request in
                    request.headers.bearerAuthorization = BearerAuthorization(token: testUser.accessToken)
                } content: { response in
                    return response.status == .ok
                }
                
            case "analyze":
                let analyzeRequest = AnalyzeGameBoxRequest(
                    imageData: generateMockImageData(),
                    analysisType: "components"
                )
                
                try await application.test(.POST, "/api/rules/analyze-box") { request in
                    request.headers.bearerAuthorization = BearerAuthorization(token: testUser.accessToken)
                    try request.content.encode(analyzeRequest)
                } content: { response in
                    return response.status == .ok
                }
                
            case "health":
                try await application.test(.GET, "/api/cache/health") { request in
                    request.headers.bearerAuthorization = BearerAuthorization(token: testUser.accessToken)
                } content: { response in
                    return response.status == .ok
                }
                
            default:
                return false
            }
            
            return true
        } catch {
            return false
        }
    }
    
    private func generateMockImageData() -> String {
        // Generate mock base64 image data for testing
        let mockImageBytes = (0..<1024).map { _ in UInt8.random(in: 0...255) }
        return Data(mockImageBytes).base64EncodedString()
    }
    
    private func getCacheHitRate() async -> Double {
        let cacheStats = await testWorld.aiCache.getStatistics()
        return cacheStats.hitRatio / 100.0
    }
}

// MARK: - Helper Types

private struct EmptyContent: Codable {}

private struct GenerateRulesRequest: Codable {
    let gameTitle: String
    let gameDescription: String
    let playerCount: String
    let playTime: String
    let gameComponents: [String]
    let gameTheme: String
    let complexityLevel: String
}

private struct AnalyzeGameBoxRequest: Codable {
    let imageData: String
    let analysisType: String
}

private struct SignUpRequest: Codable {
    let name: String
    let email: String
    let password: String
    let confirmPassword: String
}