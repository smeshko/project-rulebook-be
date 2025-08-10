import Vapor

struct CacheAdminRouter: RouteCollection {
    let controller = CacheAdminController()
    
    func boot(routes: any RoutesBuilder) throws {
        // Admin cache management endpoints (requires admin authentication)
        let adminAPI = routes
            .grouped("api")
            .grouped("admin")
            .grouped("cache")
            .grouped(EnsureAdminUserMiddleware())
        
        // Cache statistics and monitoring
        adminAPI.get("stats", use: controller.getCacheStatistics)
        adminAPI.get("health", use: controller.getCacheHealth)
        adminAPI.get("entries", use: controller.getCacheEntries)
        
        // Cache management operations
        adminAPI.delete(use: controller.clearCache)
        adminAPI.post("cleanup", use: controller.manualCleanup)
    }
}