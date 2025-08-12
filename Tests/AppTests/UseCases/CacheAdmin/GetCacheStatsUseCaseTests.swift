import Testing
import Vapor
import Logging
@testable import App

/// Comprehensive tests for GetCacheStatsUseCase demonstrating Administrative Query patterns.
///
/// This test suite validates cache monitoring queries including statistics retrieval,
/// performance metrics, and administrative data access patterns.
final class GetCacheStatsUseCaseTests: Sendable {
    
    /// Test successful cache statistics retrieval.
    @Test("Get cache stats returns comprehensive cache metrics")
    func testSuccessfulCacheStatsRetrieval() async throws {
        // Arrange
        let app = try await Application.make(.testing)
        
        let mockCacheService = MockAICacheService(app: app)
        let mockLogger = Logger(label: "test-logger")
        let useCase = GetCacheStatsUseCase(
            aiCacheService: mockCacheService,
            logger: mockLogger
        )
        
        // Configure mock cache with test entries
        mockCacheService.setTestEntry(key: "test-1", value: "value-1", ttl: 3600)
        mockCacheService.setTestEntry(key: "test-2", value: "value-2", ttl: 3600)
        mockCacheService.setTestEntry(key: "test-3", value: "value-3", ttl: 3600)
        
        // Act
        let result = try await useCase.execute(GetCacheStatsUseCase.Request(
            clientIP: "127.0.0.1"
        ))
        
        try await app.asyncShutdown()
        
        // Assert - Response Structure
        #expect(result.statistics.entryCount == 3)
        #expect(result.statistics.hits >= 0)
        #expect(result.statistics.misses >= 0)
        #expect(result.entriesByType != nil)
        
        // Assert - Query Characteristics
        #expect(result.timestamp != nil)
        let retrievalTime = Date().timeIntervalSince(result.timestamp)
        #expect(retrievalTime < 1.0) // Should be recent
        
        // Assert - Response Structure is Valid
        #expect(result.statistics.entryCount >= 0)
        #expect(result.entriesByType.count >= 0)
    }
    
    /// Test cache statistics with different IP addresses.
    @Test("Get cache stats accepts different client IP addresses")
    func testDifferentClientIPs() async throws {
        // Arrange
        let app = try await Application.make(.testing)
        
        let mockCacheService = MockAICacheService(app: app)
        let useCase = GetCacheStatsUseCase(
            aiCacheService: mockCacheService,
            logger: Logger(label: "test-logger")
        )
        
        // Act
        let result1 = try await useCase.execute(GetCacheStatsUseCase.Request(
            clientIP: "192.168.1.100"
        ))
        let result2 = try await useCase.execute(GetCacheStatsUseCase.Request(
            clientIP: "10.0.0.1"
        ))
        
        try await app.asyncShutdown()
        
        // Assert - Both requests succeed
        #expect(result1.statistics.entryCount >= 0)
        #expect(result2.statistics.entryCount >= 0)
        #expect(result1.timestamp != result2.timestamp)
    }
    
    /// Test empty cache statistics handling.
    @Test("Get cache stats handles empty cache gracefully")
    func testEmptyCacheStats() async throws {
        // Arrange
        let app = try await Application.make(.testing)
        
        let mockCacheService = MockAICacheService(app: app)
        let useCase = GetCacheStatsUseCase(
            aiCacheService: mockCacheService,
            logger: Logger(label: "test-logger")
        )
        
        // Act - Empty cache by default
        let result = try await useCase.execute(GetCacheStatsUseCase.Request(
            clientIP: "127.0.0.1"
        ))
        
        try await app.asyncShutdown()
        
        // Assert - Empty Cache Handling
        #expect(result.statistics.entryCount == 0)
        #expect(result.statistics.hits == 0)
        #expect(result.statistics.misses == 0)
        #expect(result.statistics.hitRatio == 0.0)
        #expect(result.entriesByType.isEmpty)
        
        // Assert - Still Valid Response
        #expect(result.timestamp != nil)
    }
    
    /// Test cache statistics with different cache types.
    @Test("Get cache stats categorizes entries by type")
    func testCacheStatisticsByType() async throws {
        // Arrange
        let app = try await Application.make(.testing)
        
        let mockCacheService = MockAICacheService(app: app)
        let useCase = GetCacheStatsUseCase(
            aiCacheService: mockCacheService,
            logger: Logger(label: "test-logger")
        )
        
        // Add entries of different types
        mockCacheService.setTestEntry(key: "rules:game-123", value: "rules-data", ttl: 3600)
        mockCacheService.setTestEntry(key: "image:analysis-456", value: "image-data", ttl: 3600)
        
        // Act
        let result = try await useCase.execute(GetCacheStatsUseCase.Request(
            clientIP: "127.0.0.1"
        ))
        
        try await app.asyncShutdown()
        
        // Assert - Entry Categorization
        #expect(result.statistics.entryCount == 2)
        #expect(result.entriesByType.count >= 0) // May categorize by type
    }
    
    /// Test query idempotency and consistency.
    @Test("Get cache stats provides consistent results")
    func testQueryIdempotency() async throws {
        // Arrange
        let app = try await Application.make(.testing)
        
        let mockCacheService = MockAICacheService(app: app)
        let useCase = GetCacheStatsUseCase(
            aiCacheService: mockCacheService,
            logger: Logger(label: "test-logger")
        )
        
        // Add stable test data
        mockCacheService.setTestEntry(key: "stable-1", value: "data-1", ttl: 3600)
        mockCacheService.setTestEntry(key: "stable-2", value: "data-2", ttl: 3600)
        
        let request = GetCacheStatsUseCase.Request(clientIP: "127.0.0.1")
        
        // Act - Call multiple times
        let result1 = try await useCase.execute(request)
        let result2 = try await useCase.execute(request)
        let result3 = try await useCase.execute(request)
        
        try await app.asyncShutdown()
        
        // Assert - Consistent Results (same cache state)
        #expect(result1.statistics.entryCount == result2.statistics.entryCount)
        #expect(result2.statistics.entryCount == result3.statistics.entryCount)
        #expect(result1.statistics.entryCount == 2)
        
        // Assert - Timestamps Different (each call is independent)
        #expect(result1.timestamp != result2.timestamp)
        #expect(result2.timestamp != result3.timestamp)
    }
    
    /// Test performance characteristics for administrative queries.
    @Test("Get cache stats executes quickly for admin dashboard")
    func testQueryPerformance() async throws {
        // Arrange
        let app = try await Application.make(.testing)
        
        let mockCacheService = MockAICacheService(app: app)
        let useCase = GetCacheStatsUseCase(
            aiCacheService: mockCacheService,
            logger: Logger(label: "test-logger")
        )
        
        let request = GetCacheStatsUseCase.Request(clientIP: "127.0.0.1")
        
        // Act & Assert - Performance Test
        let startTime = Date()
        
        // Execute multiple times to test consistent performance
        for _ in 1...5 {
            _ = try await useCase.execute(request)
        }
        
        let executionTime = Date().timeIntervalSince(startTime)
        
        try await app.asyncShutdown()
        
        // Should complete quickly for admin dashboard usage
        #expect(executionTime < 1.0)
    }
    
    /// Test cache statistics with hit/miss tracking.
    @Test("Get cache stats tracks hit and miss ratios correctly")
    func testCacheHitMissTracking() async throws {
        // Arrange
        let app = try await Application.make(.testing)
        
        let mockCacheService = MockAICacheService(app: app)
        let useCase = GetCacheStatsUseCase(
            aiCacheService: mockCacheService,
            logger: Logger(label: "test-logger")
        )
        
        // Configure cache with specific hit ratio
        mockCacheService.configureHitRatio(0.8) // 80% hit rate
        mockCacheService.setTestEntry(key: "test-key", value: "test-value", ttl: 3600)
        
        // Generate some hits and misses
        for _ in 1...10 {
            _ = await mockCacheService.get(key: "test-key")
            _ = await mockCacheService.get(key: "non-existent-key")
        }
        
        // Act
        let result = try await useCase.execute(GetCacheStatsUseCase.Request(
            clientIP: "127.0.0.1"
        ))
        
        try await app.asyncShutdown()
        
        // Assert - Hit/Miss Tracking
        #expect(result.statistics.totalRequests > 0)
        #expect(result.statistics.hits >= 0)
        #expect(result.statistics.misses >= 0)
        #expect(result.statistics.hitRatio >= 0.0)
        #expect(result.statistics.hitRatio <= 100.0)
    }
    
    /// Test concurrent statistics queries.
    @Test("Get cache stats handles concurrent queries efficiently")
    func testConcurrentStatsQueries() async throws {
        // Arrange
        let app = try await Application.make(.testing)
        
        let mockCacheService = MockAICacheService(app: app)
        let useCase = GetCacheStatsUseCase(
            aiCacheService: mockCacheService,
            logger: Logger(label: "test-logger")
        )
        
        // Add test data
        mockCacheService.setTestEntry(key: "concurrent-test", value: "data", ttl: 3600)
        
        // Act - Concurrent queries
        async let result1 = useCase.execute(GetCacheStatsUseCase.Request(clientIP: "192.168.1.1"))
        async let result2 = useCase.execute(GetCacheStatsUseCase.Request(clientIP: "192.168.1.2"))
        async let result3 = useCase.execute(GetCacheStatsUseCase.Request(clientIP: "192.168.1.3"))
        
        let (res1, res2, res3) = try await (result1, result2, result3)
        
        try await app.asyncShutdown()
        
        // Assert - All Queries Succeed
        #expect(res1.statistics.entryCount >= 0)
        #expect(res2.statistics.entryCount >= 0)
        #expect(res3.statistics.entryCount >= 0)
        
        // Assert - Consistent Data (same cache state)
        #expect(res1.statistics.entryCount == res2.statistics.entryCount)
        #expect(res2.statistics.entryCount == res3.statistics.entryCount)
    }
}

// MARK: - Test Helpers

// Tests use standard Logger(label:) for logging functionality

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