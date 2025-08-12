import Testing
import Vapor
import Logging
@testable import App

/// Comprehensive tests for GetCacheStatsUseCase demonstrating Administrative Query patterns.
///
/// This test suite validates cache monitoring queries including statistics retrieval,
/// performance metrics, and administrative data access patterns.
final class GetCacheStatsUseCaseTests {
    
    /// Test successful cache statistics retrieval.
    @Test("Get cache stats returns comprehensive cache metrics")
    func testSuccessfulCacheStatsRetrieval() async throws {
        // Arrange
        let mockCacheService = MockAICacheService()
        let mockLogger = TestLogger()
        let useCase = GetCacheStatsUseCase(
            aiCacheService: mockCacheService,
            logger: mockLogger
        )
        
        // Configure mock cache statistics
        mockCacheService.mockStats = CacheStats(
            totalKeys: 150,
            memoryUsage: 2048576, // 2MB
            hitRate: 0.85,
            missRate: 0.15,
            oldestEntry: Date().addingTimeInterval(-86400), // 24 hours ago
            newestEntry: Date().addingTimeInterval(-300) // 5 minutes ago
        )
        
        let adminUser = UserAccountModel(
            email: "admin@example.com",
            password: "hashed",
            isAdmin: true,
            isEmailVerified: true
        )
        adminUser.id = UUID()
        
        // Act
        let result = try await useCase.execute(GetCacheStatsUseCase.Request(
            adminUser: adminUser
        ))
        
        // Assert - Response Structure
        #expect(result.stats.totalKeys == 150)
        #expect(result.stats.memoryUsage == 2048576)
        #expect(result.stats.hitRate == 0.85)
        #expect(result.stats.missRate == 0.15)
        #expect(result.stats.oldestEntry != nil)
        #expect(result.stats.newestEntry != nil)
        
        // Assert - Query Characteristics
        #expect(result.retrievedAt != nil)
        let retrievalTime = Date().timeIntervalSince(result.retrievedAt!)
        #expect(retrievalTime < 1.0) // Should be recent
        
        // Assert - Cache Service Called
        #expect(mockCacheService.statsCallCount == 1)
        
        // Assert - No Audit Logging for Read Operations
        #expect(mockLogger.loggedMessages.isEmpty) // Queries typically don't log
    }
    
    /// Test authorization check for non-admin users.
    @Test("Get cache stats rejects non-admin users")
    func testNonAdminUserRejection() async throws {
        // Arrange
        let useCase = GetCacheStatsUseCase(
            aiCacheService: MockAICacheService(),
            logger: TestLogger()
        )
        
        let regularUser = UserAccountModel(
            email: "user@example.com",
            password: "hashed",
            isAdmin: false, // Not an admin
            isEmailVerified: true
        )
        regularUser.id = UUID()
        
        // Act & Assert
        await #expect(throws: AdminError.insufficientPrivileges) {
            try await useCase.execute(GetCacheStatsUseCase.Request(
                adminUser: regularUser
            ))
        }
    }
    
    /// Test empty cache statistics handling.
    @Test("Get cache stats handles empty cache gracefully")
    func testEmptyCacheStats() async throws {
        // Arrange
        let mockCacheService = MockAICacheService()
        let useCase = GetCacheStatsUseCase(
            aiCacheService: mockCacheService,
            logger: TestLogger()
        )
        
        // Configure empty cache stats
        mockCacheService.mockStats = CacheStats(
            totalKeys: 0,
            memoryUsage: 0,
            hitRate: 0.0,
            missRate: 0.0,
            oldestEntry: nil,
            newestEntry: nil
        )
        
        let adminUser = UserAccountModel(
            email: "admin@example.com",
            password: "hashed",
            isAdmin: true,
            isEmailVerified: true
        )
        adminUser.id = UUID()
        
        // Act
        let result = try await useCase.execute(GetCacheStatsUseCase.Request(
            adminUser: adminUser
        ))
        
        // Assert - Empty Cache Handling
        #expect(result.stats.totalKeys == 0)
        #expect(result.stats.memoryUsage == 0)
        #expect(result.stats.hitRate == 0.0)
        #expect(result.stats.missRate == 0.0)
        #expect(result.stats.oldestEntry == nil)
        #expect(result.stats.newestEntry == nil)
        
        // Assert - Still Valid Response
        #expect(result.retrievedAt != nil)
    }
    
    /// Test cache service failure handling.
    @Test("Get cache stats handles cache service failures gracefully")
    func testCacheServiceFailure() async throws {
        // Arrange
        let failingCacheService = FailingAICacheService()
        let useCase = GetCacheStatsUseCase(
            aiCacheService: failingCacheService,
            logger: TestLogger()
        )
        
        let adminUser = UserAccountModel(
            email: "admin@example.com",
            password: "hashed",
            isAdmin: true,
            isEmailVerified: true
        )
        adminUser.id = UUID()
        
        // Act & Assert
        await #expect(throws: CacheError.operationFailed) {
            try await useCase.execute(GetCacheStatsUseCase.Request(
                adminUser: adminUser
            ))
        }
    }
    
    /// Test query idempotency and consistency.
    @Test("Get cache stats is idempotent and provides consistent results")
    func testQueryIdempotency() async throws {
        // Arrange
        let stableCacheService = StableMockAICacheService()
        let useCase = GetCacheStatsUseCase(
            aiCacheService: stableCacheService,
            logger: TestLogger()
        )
        
        let adminUser = UserAccountModel(
            email: "admin@example.com",
            password: "hashed",
            isAdmin: true,
            isEmailVerified: true
        )
        adminUser.id = UUID()
        
        let request = GetCacheStatsUseCase.Request(adminUser: adminUser)
        
        // Act - Call multiple times
        let result1 = try await useCase.execute(request)
        let result2 = try await useCase.execute(request)
        let result3 = try await useCase.execute(request)
        
        // Assert - Consistent Results (same cache state)
        #expect(result1.stats.totalKeys == result2.stats.totalKeys)
        #expect(result2.stats.totalKeys == result3.stats.totalKeys)
        #expect(result1.stats.memoryUsage == result2.stats.memoryUsage)
        #expect(result2.stats.memoryUsage == result3.stats.memoryUsage)
        #expect(result1.stats.hitRate == result2.stats.hitRate)
        
        // Assert - Multiple Service Calls (no caching at use case level)
        #expect(stableCacheService.statsCallCount == 3)
        
        // Assert - Timestamps Different (each call is independent)
        #expect(result1.retrievedAt != result2.retrievedAt)
        #expect(result2.retrievedAt != result3.retrievedAt)
    }
    
    /// Test performance characteristics for administrative queries.
    @Test("Get cache stats executes quickly for admin dashboard")
    func testQueryPerformance() async throws {
        // Arrange
        let fastCacheService = MockAICacheService()
        let useCase = GetCacheStatsUseCase(
            aiCacheService: fastCacheService,
            logger: TestLogger()
        )
        
        let adminUser = UserAccountModel(
            email: "perf@example.com",
            password: "hashed",
            isAdmin: true,
            isEmailVerified: true
        )
        adminUser.id = UUID()
        
        let request = GetCacheStatsUseCase.Request(adminUser: adminUser)
        
        // Act & Assert - Performance Test
        let startTime = Date()
        
        // Execute multiple times to test consistent performance
        for _ in 1...10 {
            _ = try await useCase.execute(request)
        }
        
        let executionTime = Date().timeIntervalSince(startTime)
        
        // Should complete quickly for admin dashboard usage
        #expect(executionTime < 1.0)
        #expect(fastCacheService.statsCallCount == 10)
    }
    
    /// Test rich cache statistics with complex data.
    @Test("Get cache stats handles complex cache metrics correctly")
    func testComplexCacheStatistics() async throws {
        // Arrange
        let mockCacheService = MockAICacheService()
        let useCase = GetCacheStatsUseCase(
            aiCacheService: mockCacheService,
            logger: TestLogger()
        )
        
        // Configure comprehensive cache statistics
        let oldestDate = Date().addingTimeInterval(-604800) // 7 days ago
        let newestDate = Date().addingTimeInterval(-60) // 1 minute ago
        
        mockCacheService.mockStats = CacheStats(
            totalKeys: 5000, // Large cache
            memoryUsage: 52428800, // 50MB
            hitRate: 0.92, // High hit rate
            missRate: 0.08, // Low miss rate
            oldestEntry: oldestDate,
            newestEntry: newestDate,
            avgKeySize: 128.5,
            avgValueSize: 2048.7,
            totalHits: 45000,
            totalMisses: 3900,
            evictionCount: 150
        )
        
        let adminUser = UserAccountModel(
            email: "stats@example.com",
            password: "hashed",
            isAdmin: true,
            isEmailVerified: true
        )
        adminUser.id = UUID()
        
        // Act
        let result = try await useCase.execute(GetCacheStatsUseCase.Request(
            adminUser: adminUser
        ))
        
        // Assert - Complex Statistics Handling
        #expect(result.stats.totalKeys == 5000)
        #expect(result.stats.memoryUsage == 52428800)
        #expect(result.stats.hitRate == 0.92)
        #expect(result.stats.missRate == 0.08)
        
        // Assert - Date Handling
        #expect(result.stats.oldestEntry == oldestDate)
        #expect(result.stats.newestEntry == newestDate)
        
        // Assert - Extended Metrics (if available)
        if let avgKeySize = result.stats.avgKeySize {
            #expect(avgKeySize == 128.5)
        }
        if let totalHits = result.stats.totalHits {
            #expect(totalHits == 45000)
        }
    }
    
    /// Test concurrent statistics queries.
    @Test("Get cache stats handles concurrent queries efficiently")
    func testConcurrentStatsQueries() async throws {
        // Arrange
        let threadSafeCacheService = ThreadSafeMockAICacheService()
        let useCase = GetCacheStatsUseCase(
            aiCacheService: threadSafeCacheService,
            logger: TestLogger()
        )
        
        let admin1 = UserAccountModel(
            email: "admin1@example.com",
            password: "hashed",
            isAdmin: true,
            isEmailVerified: true
        )
        admin1.id = UUID()
        
        let admin2 = UserAccountModel(
            email: "admin2@example.com",
            password: "hashed",
            isAdmin: true,
            isEmailVerified: true
        )
        admin2.id = UUID()
        
        // Act - Concurrent queries
        async let result1 = useCase.execute(GetCacheStatsUseCase.Request(adminUser: admin1))
        async let result2 = useCase.execute(GetCacheStatsUseCase.Request(adminUser: admin2))
        async let result3 = useCase.execute(GetCacheStatsUseCase.Request(adminUser: admin1))
        
        let (res1, res2, res3) = try await (result1, result2, result3)
        
        // Assert - All Queries Succeed
        #expect(res1.stats.totalKeys >= 0)
        #expect(res2.stats.totalKeys >= 0)
        #expect(res3.stats.totalKeys >= 0)
        
        // Assert - Consistent Data (same cache state)
        #expect(res1.stats.totalKeys == res2.stats.totalKeys)
        #expect(res2.stats.totalKeys == res3.stats.totalKeys)
        
        // Assert - Multiple Service Calls
        let totalCalls = await threadSafeCacheService.getStatsCallCount()
        #expect(totalCalls == 3)
    }
}

// MARK: - Test Helpers

/// Stable mock cache service for consistency testing.
private class StableMockAICacheService: AICacheServiceInterface {
    var statsCallCount = 0
    private let stableStats = CacheStats(
        totalKeys: 100,
        memoryUsage: 1024000,
        hitRate: 0.80,
        missRate: 0.20
    )
    
    func get<T>(_ key: String, as type: T.Type) async throws -> T? where T : Codable {
        return nil
    }
    
    func set<T>(_ key: String, value: T, ttl: TimeInterval) async throws where T : Codable {
        // Mock implementation
    }
    
    func delete(_ key: String) async throws {
        // Mock implementation
    }
    
    func clear() async throws {
        // Mock implementation
    }
    
    func stats() async throws -> CacheStats {
        statsCallCount += 1
        return stableStats
    }
    
    func cleanup() async throws {
        // Mock implementation
    }
    
    func entries() async throws -> [CacheEntry] {
        return []
    }
}

/// Thread-safe mock cache service for concurrent testing.
private actor ThreadSafeMockAICacheService: AICacheServiceInterface {
    private var statsCallCount = 0
    private let stats = CacheStats(
        totalKeys: 50,
        memoryUsage: 512000,
        hitRate: 0.75,
        missRate: 0.25
    )
    
    func get<T>(_ key: String, as type: T.Type) async throws -> T? where T : Codable {
        return nil
    }
    
    func set<T>(_ key: String, value: T, ttl: TimeInterval) async throws where T : Codable {
        // Mock implementation
    }
    
    func delete(_ key: String) async throws {
        // Mock implementation
    }
    
    func clear() async throws {
        // Mock implementation
    }
    
    func stats() async throws -> CacheStats {
        statsCallCount += 1
        return stats
    }
    
    func cleanup() async throws {
        // Mock implementation
    }
    
    func entries() async throws -> [CacheEntry] {
        return []
    }
    
    func getStatsCallCount() -> Int {
        return statsCallCount
    }
}

// MARK: - Administrative Query Testing Pattern Note

/*
This test demonstrates Administrative Query testing patterns:

1. **Authorization Validation**: Testing admin-only query access
2. **Performance Optimization**: Testing query speed for dashboard usage
3. **Data Accuracy**: Testing correct statistics retrieval and formatting  
4. **Concurrent Access**: Testing multi-admin query scenarios
5. **Service Integration**: Testing cache service integration without side effects
6. **Empty State Handling**: Testing graceful handling of empty/minimal data

Key characteristics of administrative query testing:
- Authorization checks for admin privileges
- Performance focus for real-time dashboard usage
- Data consistency across multiple calls (idempotency)
- Thread safety for concurrent administrative access
- Graceful handling of edge cases (empty cache, service failures)
- No audit logging (read-only operations)

These patterns ensure administrative queries are:
- Fast and responsive for dashboard usage
- Secure and properly authorized
- Reliable in concurrent multi-admin environments
- Accurate in data representation
- Resilient against service failures
*/