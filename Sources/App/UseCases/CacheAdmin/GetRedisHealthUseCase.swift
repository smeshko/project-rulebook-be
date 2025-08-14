import Foundation
import Vapor

/// Use case for retrieving Redis health status and connectivity information.
///
/// Handles the business logic for Redis health assessment, including:
/// - Redis connection status verification
/// - Basic connectivity testing with latency measurement
/// - Error handling for connection failures
/// - Security logging for admin access
///
/// This use case tests the Redis cache service health independently from the AI cache
/// to provide specific diagnostic information about Redis connectivity and performance.
struct GetRedisHealthUseCase: Query {
    
    /// Request parameters for getting Redis health.
    struct Request {
        /// Client IP address for security logging
        let clientIP: String
        
        init(clientIP: String) {
            self.clientIP = clientIP
        }
    }
    
    /// Response from get Redis health operation.
    typealias Response = CacheAdmin.RedisHealth.Response
    
    // Dependencies
    let cacheService: CacheService
    let logger: Logger
    
    /// Initializes the use case with required dependencies.
    ///
    /// - Parameters:
    ///   - cacheService: Redis cache service for connectivity testing
    ///   - logger: Logger for security audit trail
    init(cacheService: CacheService, logger: Logger) {
        self.cacheService = cacheService
        self.logger = logger
    }
    
    /// Executes the get Redis health use case.
    ///
    /// This method contains the pure business logic for Redis health assessment:
    /// 1. Log admin access for security audit
    /// 2. Test Redis connectivity with a simple operation
    /// 3. Measure response latency
    /// 4. Handle connection failures gracefully
    /// 5. Return comprehensive health status
    ///
    /// - Parameter request: Contains client IP for logging
    /// - Returns: Redis health status with connectivity information
    /// - Throws: Never throws - all errors are captured in the response
    func execute(_ request: Request) async throws -> Response {
        // Security logging: Log admin Redis health request
        logger.info("Admin Redis health request", metadata: [
            "endpoint": "getRedisHealth",
            "client_ip": .string(request.clientIP)
        ])
        
        let startTime = Date()
        var status: CacheAdmin.RedisHealth.Status
        var issues: [String] = []
        var latencyMs: Double? = nil
        var connected = false
        
        do {
            // Test Redis connectivity with a simple ping operation
            // We'll use a health check key that doesn't interfere with application data
            let healthCheckKey = "redis:health:check:\(UUID().uuidString)"
            let testValue = "test_value_for_health_check"
            
            // Test write operation
            try await cacheService.set(healthCheckKey, value: testValue, ttl: 5.0) // 5 second TTL
            
            // Test read operation
            let retrievedValue: String? = try await cacheService.get(healthCheckKey, as: String.self)
            
            // Calculate latency
            let endTime = Date()
            latencyMs = endTime.timeIntervalSince(startTime) * 1000
            
            // If we got here, connection succeeded
            connected = true
            
            // Verify the test succeeded
            if retrievedValue == testValue {
                status = latencyMs! < 100 ? .healthy : .warning
                
                if latencyMs! >= 100 {
                    issues.append("High Redis latency (\(String(format: "%.1f", latencyMs!))ms)")
                }
                
                // Clean up test key
                try? await cacheService.delete(healthCheckKey)
                
                logger.info("Redis health check successful", metadata: [
                    "latency_ms": .string(String(format: "%.2f", latencyMs!)),
                    "status": .string(status.rawValue)
                ])
            } else {
                status = .critical
                issues.append("Redis data integrity test failed - retrieved value doesn't match written value")
                
                logger.warning("Redis health check failed - data integrity issue", metadata: [
                    "expected": .string(testValue),
                    "received": .string(retrievedValue ?? "nil")
                ])
            }
            
        } catch {
            // Redis connection failed
            status = .critical
            issues.append("Redis connection failed: \(error.localizedDescription)")
            
            let endTime = Date()
            latencyMs = endTime.timeIntervalSince(startTime) * 1000
            
            logger.error("Redis health check failed", metadata: [
                "error": .string(error.localizedDescription),
                "attempt_duration_ms": .string(String(format: "%.2f", latencyMs!))
            ])
        }
        
        return CacheAdmin.RedisHealth.Response(
            status: status,
            connected: connected,
            latencyMs: latencyMs,
            issues: issues,
            timestamp: Date()
        )
    }
}