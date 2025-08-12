@testable import App
import XCTest
import XCTVapor
import Vapor

/// Performance tests for cache admin endpoints to verify Clean Architecture refactoring performance.
///
/// These tests validate that the cache management operations maintain good performance
/// after the introduction of use cases and improved caching strategies.
final class CacheAdminPerformanceTests: XCTestCase {
    var app: Application!
    var testWorld: TestWorld!
    var performanceTestCase: PerformanceTestCase!
    var adminToken: String = ""
    
    override func setUp() async throws {
        app = try await Application.make(.testing)
        testWorld = try TestWorld(app: app)
        performanceTestCase = try await PerformanceTestCase()
        
        // Run migrations
        try await app.autoMigrate()
        
        // Create admin user
        let adminEmail = "cache-admin@example.com"
        let adminPassword = "AdminPass123!"
        
        let adminSignUp = Auth.SignUp.Request(
            email: adminEmail,
            password: adminPassword,
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
            .filter(\.$email == adminEmail)
            .first()
        user?.isAdmin = true
        try await user?.save(on: app.db)
        
        // Populate cache with test data
        await populateTestCache()
    }
    
    override func tearDown() async throws {
        try await app.autoRevert()
        app.shutdown()
    }
    
    private func populateTestCache() async {
        // Add various cache entries for testing
        for i in 0..<100 {
            testWorld.aiCache.setCacheEntry(
                key: "test-key-\(i)",
                value: "Test cached value \(i) with some content",
                type: i % 2 == 0 ? .gameIdentification : .rulesGeneration
            )
        }
    }
    
    // MARK: - Get Cache Stats Performance
    
    func testGetCacheStatsPerformance() async throws {
        let metrics = try await performanceTestCase.measure(
            "Get Cache Stats Performance",
            iterations: 200
        ) {
            try await app.test(.GET, "/api/admin/cache/stats", beforeRequest: { req in
                req.headers.bearerAuthorization = BearerAuthorization(token: adminToken)
            }, afterResponse: { res in
                XCTAssertEqual(res.status, .ok)
            })
        }
        
        print(metrics.summary)
        
        // Cache stats should be very fast to retrieve
        XCTAssertLessThan(metrics.averageTime, 0.005, "Get cache stats average time should be under 5ms")
        XCTAssertLessThan(metrics.maximumTime, 0.01, "Get cache stats max time should be under 10ms")
        XCTAssertLessThan(metrics.standardDeviation, 0.003, "Should have very consistent performance")
    }
    
    func testGetCacheHealthPerformance() async throws {
        let metrics = try await performanceTestCase.measure(
            "Get Cache Health Performance",
            iterations: 200
        ) {
            try await app.test(.GET, "/api/admin/cache/health", beforeRequest: { req in
                req.headers.bearerAuthorization = BearerAuthorization(token: adminToken)
            }, afterResponse: { res in
                XCTAssertEqual(res.status, .ok)
            })
        }
        
        print(metrics.summary)
        
        // Health checks should be extremely fast
        XCTAssertLessThan(metrics.averageTime, 0.003, "Get cache health average time should be under 3ms")
        XCTAssertLessThan(metrics.maximumTime, 0.006, "Get cache health max time should be under 6ms")
    }
    
    func testGetCacheEntriesPerformance() async throws {
        // Add more entries for pagination testing
        for i in 100..<500 {
            testWorld.aiCache.setCacheEntry(
                key: "pagination-test-\(i)",
                value: "Pagination test value \(i)",
                type: .rulesGeneration
            )
        }
        
        let metrics = try await performanceTestCase.measure(
            "Get Cache Entries Performance",
            iterations: 100
        ) {
            try await app.test(.GET, "/api/admin/cache/entries?page=1&per=50", beforeRequest: { req in
                req.headers.bearerAuthorization = BearerAuthorization(token: adminToken)
            }, afterResponse: { res in
                XCTAssertEqual(res.status, .ok)
            })
        }
        
        print(metrics.summary)
        
        // Retrieving 50 entries should still be fast
        XCTAssertLessThan(metrics.averageTime, 0.01, "Get cache entries average time should be under 10ms")
        XCTAssertLessThan(metrics.maximumTime, 0.02, "Get cache entries max time should be under 20ms")
    }
    
    // MARK: - Clear Cache Performance
    
    func testClearCachePerformance() async throws {
        // Measure clearing different cache types
        let cacheTypes = ["game-identification", "rules-generation", "all"]
        var totalTime: TimeInterval = 0
        
        for cacheType in cacheTypes {
            // Repopulate cache before each clear
            await populateTestCache()
            
            let startTime = Date()
            
            try await app.test(.POST, "/api/admin/cache/clear", beforeRequest: { req in
                req.headers.bearerAuthorization = BearerAuthorization(token: adminToken)
                req.headers.contentType = .json
                try req.content.encode(["type": cacheType])
            }, afterResponse: { res in
                XCTAssertEqual(res.status, .ok)
            })
            
            let elapsed = Date().timeIntervalSince(startTime)
            totalTime += elapsed
            
            print("Clear cache (\(cacheType)) time: \(String(format: "%.4f", elapsed))s")
        }
        
        let avgTime = totalTime / Double(cacheTypes.count)
        
        print("""
        Clear Cache Performance:
        Total Time: \(String(format: "%.4f", totalTime))s
        Average Time: \(String(format: "%.4f", avgTime))s
        """)
        
        // Clearing cache should be fast even with many entries
        XCTAssertLessThan(avgTime, 0.02, "Average clear cache time should be under 20ms")
    }
    
    func testManualCleanupPerformance() async throws {
        // Add some expired entries
        for i in 0..<50 {
            testWorld.aiCache.setCacheEntry(
                key: "expired-\(i)",
                value: "Expired value \(i)",
                type: .gameIdentification,
                ttl: -1 // Already expired
            )
        }
        
        let metrics = try await performanceTestCase.measure(
            "Manual Cleanup Performance",
            iterations: 50
        ) {
            try await app.test(.POST, "/api/admin/cache/cleanup", beforeRequest: { req in
                req.headers.bearerAuthorization = BearerAuthorization(token: adminToken)
            }, afterResponse: { res in
                XCTAssertEqual(res.status, .ok)
            })
        }
        
        print(metrics.summary)
        
        // Cleanup should be efficient
        XCTAssertLessThan(metrics.averageTime, 0.015, "Manual cleanup average time should be under 15ms")
        XCTAssertLessThan(metrics.maximumTime, 0.03, "Manual cleanup max time should be under 30ms")
    }
    
    // MARK: - Concurrent Cache Operations
    
    func testConcurrentCacheStatsAccess() async throws {
        let concurrentRequests = 100
        let startTime = Date()
        
        try await withThrowingTaskGroup(of: Void.self) { group in
            for _ in 0..<concurrentRequests {
                group.addTask {
                    try await self.app.test(.GET, "/api/admin/cache/stats", beforeRequest: { req in
                        req.headers.bearerAuthorization = BearerAuthorization(token: self.adminToken)
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
        Concurrent Cache Stats Access:
        Total Requests: \(concurrentRequests)
        Total Time: \(String(format: "%.4f", totalTime))s
        Requests per Second: \(String(format: "%.2f", requestsPerSecond))
        """)
        
        XCTAssertLessThan(totalTime, 2.0, "100 concurrent stats requests should complete within 2 seconds")
        XCTAssertGreaterThan(requestsPerSecond, 50, "Should handle at least 50 stats requests per second")
    }
    
    func testConcurrentCacheModification() async throws {
        let concurrentOperations = 50
        let startTime = Date()
        
        try await withThrowingTaskGroup(of: Void.self) { group in
            for i in 0..<concurrentOperations {
                group.addTask {
                    if i % 3 == 0 {
                        // Clear specific cache type
                        try await self.app.test(.POST, "/api/admin/cache/clear", beforeRequest: { req in
                            req.headers.bearerAuthorization = BearerAuthorization(token: self.adminToken)
                            req.headers.contentType = .json
                            try req.content.encode(["type": "game-identification"])
                        })
                    } else if i % 3 == 1 {
                        // Manual cleanup
                        try await self.app.test(.POST, "/api/admin/cache/cleanup", beforeRequest: { req in
                            req.headers.bearerAuthorization = BearerAuthorization(token: self.adminToken)
                        })
                    } else {
                        // Get stats (read operation)
                        try await self.app.test(.GET, "/api/admin/cache/stats", beforeRequest: { req in
                            req.headers.bearerAuthorization = BearerAuthorization(token: self.adminToken)
                        })
                    }
                }
            }
            
            try await group.waitForAll()
        }
        
        let totalTime = Date().timeIntervalSince(startTime)
        
        print("""
        Concurrent Cache Modification Performance:
        Total Operations: \(concurrentOperations)
        Total Time: \(String(format: "%.4f", totalTime))s
        Average Time per Operation: \(String(format: "%.4f", totalTime / Double(concurrentOperations)))s
        """)
        
        XCTAssertLessThan(totalTime, 3.0, "50 concurrent cache operations should complete within 3 seconds")
    }
    
    // MARK: - Large Dataset Performance
    
    func testLargeCacheDatasetPerformance() async throws {
        // Clear existing cache
        testWorld.aiCache.clearAll()
        
        // Add a large number of cache entries
        let entryCount = 1000
        for i in 0..<entryCount {
            testWorld.aiCache.setCacheEntry(
                key: "large-dataset-\(i)",
                value: String(repeating: "Data ", count: 100), // ~500 bytes per entry
                type: i % 3 == 0 ? .gameIdentification : .rulesGeneration
            )
        }
        
        // Test stats performance with large dataset
        let statsMetrics = try await performanceTestCase.measure(
            "Large Dataset Stats Performance",
            iterations: 50
        ) {
            try await app.test(.GET, "/api/admin/cache/stats", beforeRequest: { req in
                req.headers.bearerAuthorization = BearerAuthorization(token: adminToken)
            }, afterResponse: { res in
                XCTAssertEqual(res.status, .ok)
            })
        }
        
        print("Large Dataset (1000 entries) - " + statsMetrics.summary)
        
        // Test entries retrieval with large dataset
        let entriesMetrics = try await performanceTestCase.measure(
            "Large Dataset Entries Retrieval",
            iterations: 30
        ) {
            try await app.test(.GET, "/api/admin/cache/entries?page=1&per=100", beforeRequest: { req in
                req.headers.bearerAuthorization = BearerAuthorization(token: adminToken)
            }, afterResponse: { res in
                XCTAssertEqual(res.status, .ok)
            })
        }
        
        print("Large Dataset Entries - " + entriesMetrics.summary)
        
        // Performance should still be good with large datasets
        XCTAssertLessThan(statsMetrics.averageTime, 0.01, "Stats should remain fast with 1000 entries")
        XCTAssertLessThan(entriesMetrics.averageTime, 0.02, "Entry retrieval should be under 20ms for 100 entries")
    }
    
    // MARK: - Cache Efficiency Metrics
    
    func testCacheHitRatioPerformance() async throws {
        // Simulate cache hits and misses
        testWorld.aiCache.recordHit()
        testWorld.aiCache.recordHit()
        testWorld.aiCache.recordMiss()
        testWorld.aiCache.recordHit()
        
        let metrics = try await performanceTestCase.measure(
            "Cache Hit Ratio Calculation Performance",
            iterations: 500
        ) {
            try await app.test(.GET, "/api/admin/cache/stats", beforeRequest: { req in
                req.headers.bearerAuthorization = BearerAuthorization(token: adminToken)
            }, afterResponse: { res in
                XCTAssertEqual(res.status, .ok)
                let stats = try res.content.decode(CacheStatistics.self)
                XCTAssertGreaterThan(stats.hitRate ?? 0, 0)
            })
        }
        
        print(metrics.summary)
        
        // Hit ratio calculation should add minimal overhead
        XCTAssertLessThan(metrics.averageTime, 0.006, "Hit ratio calculation should be under 6ms")
    }
    
    // MARK: - Memory Usage Tests
    
    func testCacheMemoryUsageTracking() async throws {
        var memoryReadings: [Int] = []
        
        // Add entries and track memory
        for i in 0..<200 {
            testWorld.aiCache.setCacheEntry(
                key: "memory-test-\(i)",
                value: String(repeating: "Memory test data ", count: 50),
                type: .rulesGeneration
            )
            
            if i % 20 == 0 {
                try await app.test(.GET, "/api/admin/cache/stats", beforeRequest: { req in
                    req.headers.bearerAuthorization = BearerAuthorization(token: adminToken)
                }, afterResponse: { res in
                    let stats = try res.content.decode(CacheStatistics.self)
                    memoryReadings.append(stats.totalSize)
                })
            }
        }
        
        // Memory usage should grow predictably
        let expectedGrowthPerEntry = 850 // ~850 bytes per entry
        let actualGrowth = memoryReadings.last! - memoryReadings.first!
        let actualGrowthPerEntry = actualGrowth / 200
        
        print("""
        Cache Memory Usage Tracking:
        Initial Size: \(memoryReadings.first!) bytes
        Final Size: \(memoryReadings.last!) bytes
        Total Growth: \(actualGrowth) bytes
        Average per Entry: \(actualGrowthPerEntry) bytes
        """)
        
        // Memory tracking should be accurate within 20%
        let deviation = abs(actualGrowthPerEntry - expectedGrowthPerEntry)
        let deviationPercent = Double(deviation) / Double(expectedGrowthPerEntry) * 100
        XCTAssertLessThan(deviationPercent, 20, "Memory tracking should be accurate within 20%")
    }
}