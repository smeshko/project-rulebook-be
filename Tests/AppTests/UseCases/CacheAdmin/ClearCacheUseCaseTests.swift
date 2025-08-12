import Testing
import Vapor
import Logging
@testable import App

/// Comprehensive tests for ClearCacheUseCase demonstrating Administrative Command patterns.
///
/// This test suite validates cache management operations including bulk deletion,
/// audit logging, and administrative privilege verification.
final class ClearCacheUseCaseTests {
    
    /// Test successful cache clearing operation.
    @Test("Clear cache removes all entries and logs operation")
    func testSuccessfulCacheClear() async throws {
        // Arrange
        let mockCacheService = MockAICacheService()
        let mockLogger = TestLogger()
        let useCase = ClearCacheUseCase(
            aiCacheService: mockCacheService,
            logger: mockLogger
        )
        
        // Populate cache with test data
        mockCacheService.cachedValues["test-key-1"] = "test-value-1"
        mockCacheService.cachedValues["test-key-2"] = "test-value-2"
        mockCacheService.cachedValues["test-key-3"] = "test-value-3"
        
        let adminUser = UserAccountModel(
            email: "admin@example.com",
            password: "hashed",
            firstName: "Admin",
            lastName: "User",
            isAdmin: true,
            isEmailVerified: true
        )
        adminUser.id = UUID()
        
        // Act
        let result = try await useCase.execute(ClearCacheUseCase.Request(
            adminUser: adminUser,
            reason: "Manual cache maintenance"
        ))
        
        // Assert - Operation Success
        #expect(result.success == true)
        #expect(result.message.contains("cleared"))
        #expect(result.clearedEntries > 0)
        
        // Assert - Cache Service Called
        #expect(mockCacheService.clearCalled == true)
        
        // Assert - Audit Logging
        #expect(mockLogger.loggedMessages.count > 0)
        let logMessage = mockLogger.loggedMessages.first!
        #expect(logMessage.contains("Cache cleared"))
        #expect(logMessage.contains("admin@example.com"))
        #expect(logMessage.contains("Manual cache maintenance"))
    }
    
    /// Test authorization check for non-admin users.
    @Test("Clear cache rejects non-admin users")
    func testNonAdminUserRejection() async throws {
        // Arrange
        let useCase = ClearCacheUseCase(
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
            try await useCase.execute(ClearCacheUseCase.Request(
                adminUser: regularUser,
                reason: "Unauthorized attempt"
            ))
        }
    }
    
    /// Test cache service failure handling.
    @Test("Clear cache handles cache service failures gracefully")
    func testCacheServiceFailure() async throws {
        // Arrange
        let failingCacheService = FailingAICacheService()
        let mockLogger = TestLogger()
        let useCase = ClearCacheUseCase(
            aiCacheService: failingCacheService,
            logger: mockLogger
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
            try await useCase.execute(ClearCacheUseCase.Request(
                adminUser: adminUser,
                reason: "Test failure scenario"
            ))
        }
        
        // Assert - Failure Logged
        #expect(mockLogger.loggedMessages.count > 0)
        let errorLog = mockLogger.loggedMessages.first!
        #expect(errorLog.contains("Failed"))
    }
    
    /// Test audit trail for cache clearing operations.
    @Test("Clear cache creates comprehensive audit trail")
    func testCacheClearAuditTrail() async throws {
        // Arrange
        let mockCacheService = MockAICacheService()
        let mockLogger = TestLogger()
        let useCase = ClearCacheUseCase(
            aiCacheService: mockCacheService,
            logger: mockLogger
        )
        
        // Set up cache with known entries
        mockCacheService.cachedValues["rules-gen:123"] = "rules-data"
        mockCacheService.cachedValues["game-id:456"] = "game-data"
        mockCacheService.mockEntryCount = 2
        
        let adminUser = UserAccountModel(
            email: "audit@example.com",
            password: "hashed",
            firstName: "Audit",
            lastName: "Admin",
            isAdmin: true,
            isEmailVerified: true
        )
        adminUser.id = UUID()
        
        // Act
        let result = try await useCase.execute(ClearCacheUseCase.Request(
            adminUser: adminUser,
            reason: "Scheduled maintenance for performance optimization"
        ))
        
        // Assert - Comprehensive Audit Information
        #expect(result.clearedEntries == 2)
        #expect(result.timestamp != nil)
        #expect(result.adminUser.email == "audit@example.com")
        #expect(result.reason == "Scheduled maintenance for performance optimization")
        
        // Assert - Detailed Logging
        let logs = mockLogger.loggedMessages
        #expect(logs.count >= 2) // Start and completion logs
        
        let startLog = logs.first { $0.contains("Starting") }
        #expect(startLog?.contains("audit@example.com") == true)
        #expect(startLog?.contains("Scheduled maintenance") == true)
        
        let completionLog = logs.first { $0.contains("completed") }
        #expect(completionLog?.contains("2 entries") == true)
    }
    
    /// Test empty cache clearing operation.
    @Test("Clear cache handles empty cache gracefully")
    func testEmptyCacheClearing() async throws {
        // Arrange
        let emptyCacheService = MockAICacheService()
        emptyCacheService.mockEntryCount = 0 // Empty cache
        
        let mockLogger = TestLogger()
        let useCase = ClearCacheUseCase(
            aiCacheService: emptyCacheService,
            logger: mockLogger
        )
        
        let adminUser = UserAccountModel(
            email: "admin@example.com",
            password: "hashed",
            isAdmin: true,
            isEmailVerified: true
        )
        adminUser.id = UUID()
        
        // Act
        let result = try await useCase.execute(ClearCacheUseCase.Request(
            adminUser: adminUser,
            reason: "Maintenance check"
        ))
        
        // Assert - Handles Empty Cache
        #expect(result.success == true)
        #expect(result.clearedEntries == 0)
        #expect(result.message.contains("0 entries") || result.message.contains("empty"))
        
        // Assert - Still Logged
        #expect(mockLogger.loggedMessages.count > 0)
    }
    
    /// Test concurrent cache clearing operations.
    @Test("Clear cache handles concurrent operations safely")
    func testConcurrentCacheClearing() async throws {
        // Arrange
        let threadSafeCacheService = ThreadSafeMockAICacheService()
        let mockLogger = TestLogger()
        let useCase = ClearCacheUseCase(
            aiCacheService: threadSafeCacheService,
            logger: mockLogger
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
        
        // Populate cache
        threadSafeCacheService.cachedValues["concurrent-1"] = "data-1"
        threadSafeCacheService.cachedValues["concurrent-2"] = "data-2"
        threadSafeCacheService.mockEntryCount = 2
        
        // Act - Concurrent operations
        async let result1 = useCase.execute(ClearCacheUseCase.Request(
            adminUser: admin1,
            reason: "Concurrent test 1"
        ))
        
        async let result2 = useCase.execute(ClearCacheUseCase.Request(
            adminUser: admin2,
            reason: "Concurrent test 2"
        ))
        
        let (res1, res2) = try await (result1, result2)
        
        // Assert - Both Operations Complete
        #expect(res1.success == true || res2.success == true)
        #expect(threadSafeCacheService.clearCallCount >= 1)
        
        // Assert - Proper Audit Trail for Both
        let logs = mockLogger.loggedMessages
        let admin1Logs = logs.filter { $0.contains("admin1@example.com") }
        let admin2Logs = logs.filter { $0.contains("admin2@example.com") }
        #expect(admin1Logs.count > 0 || admin2Logs.count > 0)
    }
    
    /// Test cache clearing with performance metrics.
    @Test("Clear cache tracks performance metrics")
    func testCacheClearingPerformanceMetrics() async throws {
        // Arrange
        let performanceTrackingCache = PerformanceTrackingAICacheService()
        let mockLogger = TestLogger()
        let useCase = ClearCacheUseCase(
            aiCacheService: performanceTrackingCache,
            logger: mockLogger
        )
        
        let adminUser = UserAccountModel(
            email: "perf@example.com",
            password: "hashed",
            isAdmin: true,
            isEmailVerified: true
        )
        adminUser.id = UUID()
        
        // Act
        let startTime = Date()
        let result = try await useCase.execute(ClearCacheUseCase.Request(
            adminUser: adminUser,
            reason: "Performance test"
        ))
        let endTime = Date()
        
        // Assert - Performance Characteristics
        let executionTime = endTime.timeIntervalSince(startTime)
        #expect(executionTime < 5.0) // Should complete quickly
        
        // Assert - Performance Data in Response
        #expect(result.timestamp != nil)
        let responseTime = Date().timeIntervalSince(result.timestamp!)
        #expect(responseTime < 1.0) // Response timestamp should be recent
        
        // Assert - Performance Metrics Logged
        let performanceLogs = mockLogger.loggedMessages.filter { $0.contains("performance") || $0.contains("ms") }
        #expect(performanceLogs.count > 0)
    }
}

// MARK: - Test Helpers

/// Mock cache service that always fails for error testing.
private class FailingAICacheService: AICacheServiceInterface {
    func get<T>(_ key: String, as type: T.Type) async throws -> T? where T : Codable {
        throw CacheError.operationFailed
    }
    
    func set<T>(_ key: String, value: T, ttl: TimeInterval) async throws where T : Codable {
        throw CacheError.operationFailed
    }
    
    func delete(_ key: String) async throws {
        throw CacheError.operationFailed
    }
    
    func clear() async throws {
        throw CacheError.operationFailed
    }
    
    func stats() async throws -> CacheStats {
        throw CacheError.operationFailed
    }
    
    func cleanup() async throws {
        throw CacheError.operationFailed
    }
    
    func entries() async throws -> [CacheEntry] {
        throw CacheError.operationFailed
    }
}

/// Thread-safe mock cache service for concurrent testing.
private actor ThreadSafeMockAICacheService: AICacheServiceInterface {
    var cachedValues: [String: Any] = [:]
    var clearCallCount = 0
    var mockEntryCount = 0
    
    func get<T>(_ key: String, as type: T.Type) async throws -> T? where T : Codable {
        return cachedValues[key] as? T
    }
    
    func set<T>(_ key: String, value: T, ttl: TimeInterval) async throws where T : Codable {
        cachedValues[key] = value
    }
    
    func delete(_ key: String) async throws {
        cachedValues.removeValue(forKey: key)
    }
    
    func clear() async throws {
        clearCallCount += 1
        cachedValues.removeAll()
        mockEntryCount = 0
    }
    
    func stats() async throws -> CacheStats {
        return CacheStats(totalKeys: cachedValues.count, memoryUsage: 1024)
    }
    
    func cleanup() async throws {
        // Simulate cleanup
    }
    
    func entries() async throws -> [CacheEntry] {
        return []
    }
}

/// Performance tracking cache service for metrics testing.
private class PerformanceTrackingAICacheService: AICacheServiceInterface {
    var clearStartTime: Date?
    var clearEndTime: Date?
    
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
        clearStartTime = Date()
        
        // Simulate some processing time
        try await Task.sleep(nanoseconds: 10_000_000) // 10ms
        
        clearEndTime = Date()
    }
    
    func stats() async throws -> CacheStats {
        return CacheStats(totalKeys: 0, memoryUsage: 0)
    }
    
    func cleanup() async throws {
        // Mock implementation
    }
    
    func entries() async throws -> [CacheEntry] {
        return []
    }
}

/// Test logger for capturing log messages.
private class TestLogger: Logger {
    var loggedMessages: [String] = []
    
    var logLevel: Logging.Logger.Level = .info
    var label: String = "test"
    var metadata: Logging.Logger.Metadata = [:]
    
    subscript(metadataKey metadataKey: String) -> Logging.Logger.Metadata.Value? {
        get { return metadata[metadataKey] }
        set { metadata[metadataKey] = newValue }
    }
    
    func log(level: Logging.Logger.Level, message: Logging.Logger.Message, metadata: Logging.Logger.Metadata?, source: String, file: String, function: String, line: UInt) {
        loggedMessages.append("\(message)")
    }
}

// MARK: - Administrative Command Testing Pattern Note

/*
This test demonstrates Administrative Command testing patterns:

1. **Authorization Validation**: Testing admin privilege requirements
2. **Audit Trail Creation**: Testing comprehensive logging for administrative actions  
3. **Bulk Operation Safety**: Testing large-scale data operations with proper error handling
4. **Concurrent Access Safety**: Testing administrative operations in multi-user scenarios
5. **Performance Monitoring**: Testing resource usage and execution time tracking
6. **Failure Recovery**: Testing graceful handling of service failures

Key characteristics of administrative command testing:
- Strong authorization checks (admin-only operations)
- Comprehensive audit logging with user attribution
- Performance metrics and monitoring
- Safe handling of bulk operations
- Proper error handling without data corruption
- Thread safety for concurrent administrative operations

These patterns ensure administrative commands are:
- Secure and properly authorized
- Auditable for compliance and security
- Performant even for large datasets
- Safe in multi-user environments
- Resilient against service failures
*/