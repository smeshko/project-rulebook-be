import Vapor

struct RulesGenerationRouter: RouteCollection {
    let controller = RulesGenerationController()
    
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
    }
}
