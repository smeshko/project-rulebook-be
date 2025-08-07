import Vapor

struct RulesGenerationRouter: RouteCollection {
    let controller = RulesGenerationController()
    let cacheAdminController = AICacheAdminController()
    
    func boot(routes: any RoutesBuilder) throws {
        let api = routes
            .grouped("api")
            .grouped("rules-generation")
        
        // Image analysis endpoint with stricter rate limiting (5/hour)
        let imageAnalysisAPI = api.grouped(AIRateLimitMiddleware(operationType: .imageAnalysis))
        imageAnalysisAPI.on(
            .POST, "game-box-analysis",
            body: .stream,
            use: controller.analyzeBoxPhoto
        )
        
        // Rules generation endpoint with moderate rate limiting (10/hour)
        let rulesGenerationAPI = api.grouped(AIRateLimitMiddleware(operationType: .rulesGeneration))
        rulesGenerationAPI.post("rules-summary", use: controller.generateRulesSummary)
        
        // Admin cache management endpoints (requires admin authentication)
        let adminAPI = routes
            .grouped("api")
            .grouped("admin")
            .grouped("cache")
            .grouped(EnsureAdminUserMiddleware())
        
        // Cache statistics and monitoring
        adminAPI.get("stats", use: cacheAdminController.getCacheStatistics)
        adminAPI.get("health", use: cacheAdminController.getCacheHealth)
        adminAPI.get("entries", use: cacheAdminController.getCacheEntries)
        
        // Cache management operations
        adminAPI.delete(use: cacheAdminController.clearCache)
        adminAPI.post("cleanup", use: cacheAdminController.manualCleanup)
    }
}
