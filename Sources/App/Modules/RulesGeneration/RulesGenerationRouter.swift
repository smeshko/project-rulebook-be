import Vapor

struct RulesGenerationRouter: RouteCollection {
    let controller = RulesGenerationController()
    
    func boot(routes: any RoutesBuilder) throws {
        let api = routes
            .grouped("api")
            .grouped("rules-generation")
        
        api.on(
            .POST, "game-box-analysis",
            body: .stream,
            use: controller.analyzeBoxPhoto
        )
        
        api.post("rules-summary", use: controller.generateRulesSummary)
    }
}
