import Foundation
import Vapor

/// Use case for clearing all cache entries.
///
/// Handles the business logic for cache clearing operations, including:
/// - Pre-clear entry counting
/// - Cache clearing execution
/// - Post-clear verification
/// - Comprehensive security logging
/// - Response formatting with metrics
///
/// This use case encapsulates the cache clearing administrative logic
/// while maintaining security audit trails and proper metrics collection.
struct ClearCacheUseCase: Command {
    
    /// Request parameters for clearing cache.
    struct Request {
        /// Client IP address for security logging
        let clientIP: String
        
        init(clientIP: String) {
            self.clientIP = clientIP
        }
    }
    
    /// Response from clear cache operation.
    typealias Response = CacheAdmin.Clear.Response
    
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
    
    /// Executes the clear cache use case.
    ///
    /// This method contains the pure business logic for cache clearing:
    /// 1. Log admin cache clear request for security audit
    /// 2. Count entries before clearing for metrics
    /// 3. Execute cache clearing operation
    /// 4. Count entries after clearing for verification
    /// 5. Log completion with detailed metrics
    /// 6. Return response with operation results
    ///
    /// - Parameter request: Contains client IP for logging
    /// - Returns: Cache clearing results with entry counts
    /// - Throws: Service errors if cache operations fail
    func execute(_ request: Request) async throws -> Response {
        // Security logging: Log admin cache clear request
        logger.info("Admin cache clear request", metadata: [
            "endpoint": "clearCache",
            "client_ip": .string(request.clientIP),
            "timestamp": .string(ISO8601DateFormatter().string(from: Date()))
        ])
        
        // Count entries before clearing for metrics
        let countBefore = await aiCacheService.count()
        
        // Execute cache clearing operation
        await aiCacheService.clear()
        
        // Count entries after clearing for verification
        let countAfter = await aiCacheService.count()
        
        // Security logging: Log completion with detailed metrics
        logger.info("Admin cache cleared", metadata: [
            "entries_removed": .string("\(countBefore)"),
            "remaining_entries": .string("\(countAfter)"),
            "client_ip": .string(request.clientIP)
        ])
        
        return CacheAdmin.Clear.Response(
            entriesRemoved: countBefore,
            remainingEntries: countAfter,
            timestamp: Date()
        )
    }
}