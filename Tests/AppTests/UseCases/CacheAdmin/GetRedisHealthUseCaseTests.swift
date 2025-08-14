import Testing
import Vapor
import Logging
@testable import App

/// Comprehensive tests for GetRedisHealthUseCase demonstrating Redis connectivity testing.
///
/// This test suite validates Redis health monitoring queries including connectivity tests,
/// performance metrics, and graceful failure handling.
final class GetRedisHealthUseCaseTests: Sendable {
    
    /// Test successful Redis health check.
    @Test("Get Redis health returns healthy status when Redis is working")
    func testSuccessfulRedisHealthCheck() async throws {
        // Arrange
        let app = try await Application.make(.testing)
        
        let mockCacheService = MockCacheService()
        let mockLogger = Logger(label: "test-logger")
        let useCase = GetRedisHealthUseCase(
            cacheService: mockCacheService,
            logger: mockLogger
        )
        
        // Configure mock to simulate healthy Redis
        mockCacheService.simulateHealthyState()
        
        // Act
        let result = try await useCase.execute(GetRedisHealthUseCase.Request(
            clientIP: "127.0.0.1"
        ))
        
        try await app.asyncShutdown()
        
        // Assert - Healthy State
        #expect(result.status == .healthy)
        #expect(result.connected == true)
        #expect(result.latencyMs != nil)
        #expect(result.latencyMs! < 100) // Should be fast for healthy state
        #expect(result.issues.isEmpty)
        
        // Assert - Response Structure
        #expect(result.timestamp != nil)
        let checkTime = Date().timeIntervalSince(result.timestamp)
        #expect(checkTime < 1.0) // Should be recent
    }
    
    /// Test Redis health check with warning status for high latency.
    @Test("Get Redis health returns warning status for high latency")
    func testHighLatencyWarning() async throws {
        // Arrange
        let app = try await Application.make(.testing)
        
        let mockCacheService = MockCacheService()
        let mockLogger = Logger(label: "test-logger")
        let useCase = GetRedisHealthUseCase(
            cacheService: mockCacheService,
            logger: mockLogger
        )
        
        // Configure mock to simulate high latency
        mockCacheService.simulateHighLatency(150) // 150ms latency
        
        // Act
        let result = try await useCase.execute(GetRedisHealthUseCase.Request(
            clientIP: "127.0.0.1"
        ))
        
        try await app.asyncShutdown()
        
        // Assert - Warning State
        #expect(result.status == .warning)
        #expect(result.connected == true)
        #expect(result.latencyMs != nil)
        #expect(result.latencyMs! >= 100) // High latency
        #expect(result.issues.count == 1)
        #expect(result.issues[0].contains("High Redis latency"))
    }
    
    /// Test Redis health check with critical status for connection failure.
    @Test("Get Redis health returns critical status when Redis is unavailable")
    func testRedisConnectionFailure() async throws {
        // Arrange
        let app = try await Application.make(.testing)
        
        let mockCacheService = MockCacheService()
        let mockLogger = Logger(label: "test-logger")
        let useCase = GetRedisHealthUseCase(
            cacheService: mockCacheService,
            logger: mockLogger
        )
        
        // Configure mock to simulate connection failure
        mockCacheService.simulateConnectionFailure()
        
        // Act
        let result = try await useCase.execute(GetRedisHealthUseCase.Request(
            clientIP: "127.0.0.1"
        ))
        
        try await app.asyncShutdown()
        
        // Assert - Critical State
        #expect(result.status == .critical)
        #expect(result.connected == false)
        #expect(result.latencyMs != nil) // Should still measure attempt time
        #expect(result.issues.count == 1)
        #expect(result.issues[0].contains("Redis connection failed"))
    }
    
    /// Test Redis health check with data integrity failure.
    @Test("Get Redis health returns critical status for data integrity issues")
    func testDataIntegrityFailure() async throws {
        // Arrange
        let app = try await Application.make(.testing)
        
        let mockCacheService = MockCacheService()
        let mockLogger = Logger(label: "test-logger")
        let useCase = GetRedisHealthUseCase(
            cacheService: mockCacheService,
            logger: mockLogger
        )
        
        // Configure mock to simulate data integrity failure
        mockCacheService.simulateDataIntegrityFailure()
        
        // Act
        let result = try await useCase.execute(GetRedisHealthUseCase.Request(
            clientIP: "127.0.0.1"
        ))
        
        try await app.asyncShutdown()
        
        // Assert - Critical State
        #expect(result.status == .critical)
        #expect(result.connected == true) // Connection works but data is corrupted
        #expect(result.issues.count == 1)
        #expect(result.issues[0].contains("data integrity test failed"))
    }
    
    /// Test Redis health check with different client IPs.
    @Test("Get Redis health accepts different client IP addresses")
    func testDifferentClientIPs() async throws {
        // Arrange
        let app = try await Application.make(.testing)
        
        let mockCacheService = MockCacheService()
        let useCase = GetRedisHealthUseCase(
            cacheService: mockCacheService,
            logger: Logger(label: "test-logger")
        )
        
        mockCacheService.simulateHealthyState()
        
        // Act
        let result1 = try await useCase.execute(GetRedisHealthUseCase.Request(
            clientIP: "192.168.1.100"
        ))
        let result2 = try await useCase.execute(GetRedisHealthUseCase.Request(
            clientIP: "10.0.0.1"
        ))
        
        try await app.asyncShutdown()
        
        // Assert - Both requests succeed
        #expect(result1.status == .healthy)
        #expect(result2.status == .healthy)
        #expect(result1.timestamp != result2.timestamp)
    }
    
    /// Test concurrent Redis health checks.
    @Test("Get Redis health handles concurrent checks efficiently")
    func testConcurrentHealthChecks() async throws {
        // Arrange
        let app = try await Application.make(.testing)
        
        let mockCacheService = MockCacheService()
        let useCase = GetRedisHealthUseCase(
            cacheService: mockCacheService,
            logger: Logger(label: "test-logger")
        )
        
        mockCacheService.simulateHealthyState()
        
        // Act - Concurrent health checks
        async let result1 = useCase.execute(GetRedisHealthUseCase.Request(clientIP: "192.168.1.1"))
        async let result2 = useCase.execute(GetRedisHealthUseCase.Request(clientIP: "192.168.1.2"))
        async let result3 = useCase.execute(GetRedisHealthUseCase.Request(clientIP: "192.168.1.3"))
        
        let (res1, res2, res3) = try await (result1, result2, result3)
        
        try await app.asyncShutdown()
        
        // Assert - All Checks Succeed
        #expect(res1.status == .healthy)
        #expect(res2.status == .healthy)
        #expect(res3.status == .healthy)
        #expect(res1.connected == true)
        #expect(res2.connected == true)
        #expect(res3.connected == true)
    }
    
    /// Test performance characteristics for health checks.
    @Test("Get Redis health executes quickly for monitoring")
    func testHealthCheckPerformance() async throws {
        // Arrange
        let app = try await Application.make(.testing)
        
        let mockCacheService = MockCacheService()
        let useCase = GetRedisHealthUseCase(
            cacheService: mockCacheService,
            logger: Logger(label: "test-logger")
        )
        
        mockCacheService.simulateHealthyState()
        let request = GetRedisHealthUseCase.Request(clientIP: "127.0.0.1")
        
        // Act & Assert - Performance Test
        let startTime = Date()
        
        // Execute multiple times to test consistent performance
        for _ in 1...5 {
            _ = try await useCase.execute(request)
        }
        
        let executionTime = Date().timeIntervalSince(startTime)
        
        try await app.asyncShutdown()
        
        // Should complete quickly for monitoring usage
        #expect(executionTime < 1.0)
    }
}

// MARK: - Mock CacheService for Testing

/// Mock implementation of CacheService for testing Redis health checks.
final class MockCacheService: CacheService, @unchecked Sendable {
    
    private enum MockState {
        case healthy
        case highLatency(Double)
        case connectionFailure
        case dataIntegrityFailure
    }
    
    private var state: MockState = .healthy
    
    func simulateHealthyState() {
        state = .healthy
    }
    
    func simulateHighLatency(_ latencyMs: Double) {
        state = .highLatency(latencyMs)
    }
    
    func simulateConnectionFailure() {
        state = .connectionFailure
    }
    
    func simulateDataIntegrityFailure() {
        state = .dataIntegrityFailure
    }
    
    func get<T>(_ key: String, as type: T.Type) async throws -> T? where T: Codable {
        let currentState = state
        
        switch currentState {
        case .healthy:
            // Simulate healthy Redis with normal latency
            try await Task.sleep(nanoseconds: 10_000_000) // 10ms
            
            if key.contains("redis:health:check") {
                // For healthy state, we need to return the exact value that was set
                // Since we can't access the actual stored value, we'll return a consistent test value
                return "test_value_for_health_check" as? T
            }
            return nil
            
        case .highLatency(let latencyMs):
            // Simulate high latency
            let nanoseconds = UInt64(latencyMs * 1_000_000) // Convert ms to nanoseconds
            try await Task.sleep(nanoseconds: nanoseconds)
            
            if key.contains("redis:health:check") {
                return "test_value_for_health_check" as? T
            }
            return nil
            
        case .connectionFailure:
            // Simulate connection failure
            try await Task.sleep(nanoseconds: 50_000_000) // 50ms attempt time
            throw CacheError.retrievalFailed(NSError(domain: "Redis", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Connection to Redis server failed"
            ]))
            
        case .dataIntegrityFailure:
            // Simulate successful connection but wrong data
            try await Task.sleep(nanoseconds: 10_000_000) // 10ms
            
            if key.contains("redis:health:check") {
                return "corrupted_data" as? T // Return wrong value to trigger integrity failure
            }
            return nil
        }
    }
    
    func set<T>(_ key: String, value: T, ttl: TimeInterval?) async throws where T: Codable {
        let currentState = state
        
        switch currentState {
        case .healthy:
            try await Task.sleep(nanoseconds: 5_000_000) // 5ms
            
        case .highLatency(let latencyMs):
            let nanoseconds = UInt64(latencyMs * 1_000_000)
            try await Task.sleep(nanoseconds: nanoseconds)
            
        case .connectionFailure:
            try await Task.sleep(nanoseconds: 50_000_000) // 50ms attempt time
            throw CacheError.storageFailed(NSError(domain: "Redis", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Connection to Redis server failed"
            ]))
            
        case .dataIntegrityFailure:
            try await Task.sleep(nanoseconds: 5_000_000) // 5ms - appears to work
        }
    }
    
    func delete(_ key: String) async throws {
        let currentState = state
        
        switch currentState {
        case .healthy, .highLatency, .dataIntegrityFailure:
            try await Task.sleep(nanoseconds: 5_000_000) // 5ms
            
        case .connectionFailure:
            throw CacheError.deletionFailed(NSError(domain: "Redis", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Connection to Redis server failed"
            ]))
        }
    }
    
    func flush() async throws {
        let currentState = state
        
        switch currentState {
        case .healthy, .highLatency, .dataIntegrityFailure:
            try await Task.sleep(nanoseconds: 10_000_000) // 10ms
            
        case .connectionFailure:
            throw CacheError.flushFailed(NSError(domain: "Redis", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Connection to Redis server failed"
            ]))
        }
    }
    
    func exists(_ key: String) async throws -> Bool {
        let currentState = state
        
        switch currentState {
        case .healthy:
            try await Task.sleep(nanoseconds: 5_000_000) // 5ms
            return key.contains("redis:health:check")
            
        case .highLatency(let latencyMs):
            let nanoseconds = UInt64(latencyMs * 1_000_000)
            try await Task.sleep(nanoseconds: nanoseconds)
            return key.contains("redis:health:check")
            
        case .connectionFailure:
            try await Task.sleep(nanoseconds: 50_000_000) // 50ms attempt time
            throw CacheError.queryFailed(NSError(domain: "Redis", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Connection to Redis server failed"
            ]))
            
        case .dataIntegrityFailure:
            try await Task.sleep(nanoseconds: 5_000_000) // 5ms
            return key.contains("redis:health:check")
        }
    }
}

// MARK: - Redis Health Testing Pattern Note

/*
This test demonstrates Redis Health Monitoring testing patterns:

1. **Connection Testing**: Testing Redis connectivity and failure scenarios
2. **Performance Monitoring**: Testing latency measurement and warning thresholds
3. **Data Integrity**: Testing that Redis correctly stores and retrieves data
4. **Graceful Degradation**: Testing behavior when Redis is unavailable
5. **Concurrent Monitoring**: Testing multiple simultaneous health checks
6. **Response Consistency**: Testing reliable health status reporting

Key characteristics of Redis health testing:
- Connection failure simulation for resilience testing
- Latency measurement for performance monitoring
- Data integrity verification for reliability assurance
- Graceful error handling for operational stability
- Quick execution for real-time monitoring dashboards
- Consistent response structure for monitoring systems

These patterns ensure Redis health monitoring is:
- Reliable in detecting actual Redis issues
- Fast enough for frequent health check polling
- Informative with specific issue identification
- Resilient against transient network issues
- Suitable for automated monitoring systems
*/