import Vapor
import VaporToOpenAPI

struct CacheAdminRouter: RouteCollection {
    let controller = CacheAdminController()
    
    func boot(routes: any RoutesBuilder) throws {
        // Admin cache management endpoints (requires admin authentication)
        let adminAPI = routes
            .grouped("api")
            .grouped("admin")
            .grouped("cache")
            .groupedOpenAPI(tags: .init(name: "Cache Admin", description: "Cache monitoring and management for administrators"))
            .grouped(EnsureAdminUserMiddleware())

        // Cache statistics and monitoring
        adminAPI
            .get("stats", use: controller.getCacheStatistics)
            .openAPI(
                description: "Retrieve comprehensive cache statistics including hit/miss rates, entry counts, and memory usage. Admin only.",
                auth: .bearer(id: "bearerAuth")
            )

        adminAPI
            .get("health", use: controller.getCacheHealth)
            .openAPI(
                description: "Check cache health status with diagnostic information and recommendations. Admin only.",
                auth: .bearer(id: "bearerAuth")
            )

        adminAPI
            .get("entries", use: controller.getCacheEntries)
            .openAPI(
                description: "List all cache entries with metadata (age, TTL, hit count). Useful for debugging cache behavior. Admin only.",
                auth: .bearer(id: "bearerAuth")
            )

        // Redis-specific health monitoring
        adminAPI
            .get("redis", "health", use: controller.getRedisHealth)
            .openAPI(
                description: "Check Redis connection health and latency. Separate from general cache health for infrastructure monitoring. Admin only.",
                auth: .bearer(id: "bearerAuth")
            )

        // Cache management operations
        adminAPI
            .delete(use: controller.clearCache)
            .openAPI(
                description: "Clear all cache entries. Use with caution - will temporarily reduce performance until cache rebuilds. Admin only.",
                auth: .bearer(id: "bearerAuth")
            )

        adminAPI
            .post("cleanup", use: controller.manualCleanup)
            .openAPI(
                description: "Manually trigger cache cleanup to remove expired entries. Normally handled automatically but useful for testing. Admin only.",
                auth: .bearer(id: "bearerAuth")
            )
    }
}