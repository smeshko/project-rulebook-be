import Foundation
import Vapor

/// Use case for retrieving cache statistics and performance metrics.
///
/// Handles the business logic for gathering cache statistics, including:
/// - Cache performance metrics (hits, misses, utilization)
/// - Entries grouped by cache type  
/// - Security logging for admin access
/// - Response formatting
///
/// This use case encapsulates the administrative cache statistics logic
/// while keeping HTTP concerns separate from business logic.
struct GetCacheStatsUseCase: Query {
    
    /// Request parameters for getting cache statistics.
    struct Request {
        /// Client IP address for security logging
        let clientIP: String
        
        init(clientIP: String) {
            self.clientIP = clientIP
        }
    }
    
    /// Response from get cache statistics operation.
    typealias Response = CacheAdmin.Statistics.Response
    
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
    
    /// Executes the get cache statistics use case.
    ///
    /// This method contains the pure business logic for cache statistics:
    /// 1. Log admin access for security audit
    /// 2. Retrieve cache statistics from service
    /// 3. Retrieve entries grouped by type
    /// 4. Format response with proper timestamp
    ///
    /// - Parameter request: Contains client IP for logging
    /// - Returns: Cache statistics and metadata
    /// - Throws: Service errors if statistics retrieval fails
    func execute(_ request: Request) async throws -> Response {
        // Security logging: Log admin cache statistics access
        logger.info("Admin cache statistics request", metadata: [
            "endpoint": "getCacheStatistics",
            "client_ip": .string(request.clientIP),
            "timestamp": .string(ISO8601DateFormatter().string(from: Date()))
        ])
        
        // Retrieve cache statistics and entries
        let statistics = await aiCacheService.getStatistics()
        let entriesByType = await aiCacheService.getEntriesByType()
        
        // Convert enum keys to strings for JSON serialization
        let stringKeysEntriesByType = Dictionary(uniqueKeysWithValues: 
            entriesByType.map { (key, value) in (key.rawValue, value) }
        )
        
        return CacheAdmin.Statistics.Response(
            statistics: statistics,
            entriesByType: stringKeysEntriesByType,
            timestamp: Date()
        )
    }
}