import Vapor

struct RulesGenerationRouter: RouteCollection {
    let controller = RulesGenerationController()
    
    func boot(routes: any RoutesBuilder) throws {
        let api = routes
            .grouped("api")
            .grouped("rules-generation")
        
        // Image analysis endpoint - rate limiting handled by RateLimitMiddleware
        api.on(
            .POST, "game-box-analysis", 
            body: .stream,
            use: controller.analyzeBoxPhoto
        )
        
        // Rules generation endpoint - rate limiting handled by RateLimitMiddleware
        api.post("rules-summary", use: controller.generateRulesSummary)
    }
}
