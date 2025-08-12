import Foundation
import Vapor

/// Use case for retrieving cache health status and performance recommendations.
///
/// Handles the business logic for cache health assessment, including:
/// - Cache performance metrics analysis
/// - Health status determination based on thresholds
/// - Performance issue identification
/// - Automated recommendation generation
/// - Security logging for admin access
///
/// This use case encapsulates complex health assessment logic that determines
/// cache performance status and generates actionable recommendations for optimization.
struct GetCacheHealthUseCase: UseCase {
    
    /// Request parameters for getting cache health.
    struct Request {
        /// Client IP address for security logging
        let clientIP: String
        
        init(clientIP: String) {
            self.clientIP = clientIP
        }
    }
    
    /// Response from get cache health operation.
    typealias Response = CacheHealthResponse
    
    // Dependencies
    let aiCacheService: AICacheServiceInterface
    let configurationService: ConfigurationService
    let logger: Logger
    
    /// Initializes the use case with required dependencies.
    ///
    /// - Parameters:
    ///   - aiCacheService: Service for cache operations
    ///   - configurationService: Service for accessing cache configuration
    ///   - logger: Logger for security audit trail
    init(aiCacheService: AICacheServiceInterface, 
         configurationService: ConfigurationService,
         logger: Logger) {
        self.aiCacheService = aiCacheService
        self.configurationService = configurationService
        self.logger = logger
    }
    
    /// Executes the get cache health use case.
    ///
    /// This method contains the pure business logic for cache health assessment:
    /// 1. Log admin access for security audit
    /// 2. Retrieve cache statistics and configuration
    /// 3. Analyze health status based on utilization and hit ratio
    /// 4. Identify performance issues
    /// 5. Generate actionable recommendations
    /// 6. Return comprehensive health assessment
    ///
    /// - Parameter request: Contains client IP for logging
    /// - Returns: Cache health status with issues and recommendations
    /// - Throws: Service errors if health assessment fails
    func execute(_ request: Request) async throws -> Response {
        // Security logging: Log admin cache health request
        logger.info("Admin cache health request", metadata: [
            "endpoint": "getCacheHealth",
            "client_ip": .string(request.clientIP)
        ])
        
        // Retrieve cache statistics and configuration
        let statistics = await aiCacheService.getStatistics()
        let config = try configurationService.cache
        
        // Analyze health status and identify issues
        let utilizationPercentage = statistics.utilization
        let hitRatio = statistics.hitRatio
        
        let healthStatus: CacheHealthStatus
        let issues: [String] = []
        var currentIssues = issues
        
        // Determine health status based on cache metrics
        switch (utilizationPercentage, hitRatio) {
        case (let util, _) where util > 95:
            healthStatus = .critical
            currentIssues.append("Cache is nearly full (\(String(format: "%.1f", util))%)")
        case (let util, _) where util > 90:
            healthStatus = .warning
            currentIssues.append("Cache utilization is very high (\(String(format: "%.1f", util))%)")
        case (_, let hit) where hit < 30 && statistics.totalRequests > 50:
            healthStatus = .warning
            currentIssues.append("Cache hit ratio is low (\(String(format: "%.1f", hit))%)")
        default:
            healthStatus = .healthy
        }
        
        // Generate performance recommendations
        let recommendations = generateRecommendations(for: statistics, config: config)
        
        return CacheHealthResponse(
            status: healthStatus,
            statistics: statistics,
            issues: currentIssues,
            recommendations: recommendations,
            timestamp: Date()
        )
    }
    
    // MARK: - Private Helper Methods
    
    /// Generates performance recommendations based on cache statistics and configuration.
    ///
    /// Analyzes cache performance metrics and configuration settings to provide
    /// actionable recommendations for optimizing cache performance.
    ///
    /// - Parameters:
    ///   - statistics: Current cache performance statistics
    ///   - config: Cache configuration settings
    /// - Returns: Array of recommendation strings for performance optimization
    private func generateRecommendations(for statistics: CacheStatistics, config: CacheConfig) -> [String] {
        var recommendations: [String] = []
        
        // Check utilization recommendations
        if statistics.utilization > 80 {
            recommendations.append("Consider increasing CACHE_MAX_ENTRIES (currently \(statistics.maxEntries))")
        }
        
        // Check hit ratio recommendations
        if statistics.hitRatio < 50 && statistics.totalRequests > 100 {
            recommendations.append("Low cache hit ratio may indicate TTL values are too short")
        }
        
        // Check TTL configuration recommendations
        if config.rulesGenerationTTL < 3600 {
            recommendations.append("Consider increasing CACHE_RULES_TTL for better performance")
        }
        
        // Check for empty cache issues
        if statistics.entryCount == 0 && statistics.totalRequests > 0 {
            recommendations.append("Cache is empty but has requests - check if caching is working correctly")
        }
        
        // Acknowledge good performance
        if statistics.totalRequests > 1000 && statistics.hitRatio > 70 {
            recommendations.append("Cache is performing well - good hit ratio with high request volume")
        }
        
        return recommendations
    }
}