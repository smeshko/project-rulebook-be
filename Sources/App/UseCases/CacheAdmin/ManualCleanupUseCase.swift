import Foundation
import Vapor

/// Use case for manually triggering cache cleanup of expired entries.
///
/// Handles the business logic for manual cache cleanup operations, including:
/// - Pre-cleanup entry counting
/// - Expired entry cleanup execution
/// - Post-cleanup verification and metrics
/// - Comprehensive security logging
/// - Response formatting with detailed results
///
/// This use case encapsulates the manual cache cleanup administrative logic
/// while maintaining security audit trails and proper metrics collection.
struct ManualCleanupUseCase: Command {
    
    /// Request parameters for manual cache cleanup.
    struct Request {
        /// Client IP address for security logging
        let clientIP: String
        
        init(clientIP: String) {
            self.clientIP = clientIP
        }
    }
    
    /// Response from manual cleanup operation.
    typealias Response = CacheAdmin.Cleanup.Response
    
    // Dependencies
    let aiCacheService: AICacheServiceInterface
    let logger: Logger
    
    /// Initializes the use case with required dependencies.
    ///
    /// - Parameters:
    ///   - aiCacheService: Service for cache operations
    ///   - logger: Logger for security audit trail
    init(aiCacheService: AICacheServiceInterface, logger: Logger) {
        self.aiCacheService = aiCacheService
        self.logger = logger
    }
    
    /// Executes the manual cleanup use case.
    ///
    /// This method contains the pure business logic for manual cache cleanup:
    /// 1. Log admin manual cleanup request for security audit
    /// 2. Count entries before cleanup for metrics
    /// 3. Execute expired entries cleanup operation
    /// 4. Count entries after cleanup for verification
    /// 5. Calculate and log detailed cleanup metrics
    /// 6. Return response with operation results
    ///
    /// - Parameter request: Contains client IP for logging
    /// - Returns: Cleanup results with entries removed and remaining counts
    /// - Throws: Service errors if cleanup operations fail
    func execute(_ request: Request) async throws -> Response {
        // Security logging: Log admin manual cleanup request
        logger.info("Admin manual cache cleanup request", metadata: [
            "endpoint": "manualCleanup",
            "client_ip": .string(request.clientIP),
            "timestamp": .string(ISO8601DateFormatter().string(from: Date()))
        ])
        
        // Count entries before cleanup for metrics
        let countBefore = await aiCacheService.count()
        
        // Execute expired entries cleanup operation
        await aiCacheService.cleanupExpired()
        
        // Count entries after cleanup for verification
        let countAfter = await aiCacheService.count()
        
        // Calculate entries removed
        let entriesRemoved = countBefore - countAfter
        
        // Security logging: Log completion with detailed metrics
        logger.info("Admin manual cleanup completed", metadata: [
            "entries_removed": .string("\(entriesRemoved)"),
            "remaining_entries": .string("\(countAfter)"),
            "client_ip": .string(request.clientIP)
        ])
        
        return CacheAdmin.Cleanup.Response(
            entriesRemoved: entriesRemoved,
            remainingEntries: countAfter,
            timestamp: Date()
        )
    }
}