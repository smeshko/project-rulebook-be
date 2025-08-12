import Foundation
import Vapor

/// Use case for listing cache entries with metadata.
///
/// Handles the business logic for retrieving cache entry listings, including:
/// - Security logging for admin access
/// - Entries grouped by cache type
/// - Detailed entry metadata (when available)
/// - Response formatting with pagination support
///
/// This use case handles the administrative cache entries listing logic
/// while maintaining security audit trails and proper data formatting.
///
/// Note: Currently returns empty entries array to avoid non-sendable type issues.
/// This can be improved later with a proper sendable detailed info method.
struct GetCacheEntriesUseCase: UseCase {
    
    /// Request parameters for getting cache entries.
    struct Request {
        /// Client IP address for security logging
        let clientIP: String
        
        init(clientIP: String) {
            self.clientIP = clientIP
        }
    }
    
    /// Response from get cache entries operation.
    typealias Response = CacheEntriesResponse
    
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
    
    /// Executes the get cache entries use case.
    ///
    /// This method contains the pure business logic for cache entries retrieval:
    /// 1. Log admin access for security audit
    /// 2. Retrieve entries grouped by type from service
    /// 3. Format detailed entry information (currently empty for safety)
    /// 4. Convert enum keys for JSON serialization
    /// 5. Return formatted response with metadata
    ///
    /// - Parameter request: Contains client IP for logging
    /// - Returns: Cache entries listing with type grouping
    /// - Throws: Service errors if entries retrieval fails
    func execute(_ request: Request) async throws -> Response {
        // Security logging: Log admin cache entries access
        logger.info("Admin cache entries request", metadata: [
            "endpoint": "getCacheEntries",
            "client_ip": .string(request.clientIP),
            "timestamp": .string(ISO8601DateFormatter().string(from: Date()))
        ])
        
        // Retrieve entries grouped by type
        let entriesByType = await aiCacheService.getEntriesByType()
        
        // For now, return empty entries array to avoid non-sendable type issues
        // This can be improved later with a proper sendable detailed info method
        let entriesInfo: [CacheEntryInfo] = []
        
        // Convert enum keys to strings for JSON serialization
        let stringKeysEntriesByType = Dictionary(uniqueKeysWithValues: 
            entriesByType.map { (key, value) in (key.rawValue, value) }
        )
        
        return CacheEntriesResponse(
            entries: entriesInfo,
            entriesByType: stringKeysEntriesByType,
            totalCount: entriesInfo.count,
            timestamp: Date()
        )
    }
}