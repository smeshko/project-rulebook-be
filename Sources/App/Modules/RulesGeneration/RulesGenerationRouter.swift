import Vapor
import VaporToOpenAPI

struct RulesGenerationRouter: RouteCollection {
    let controller = RulesGenerationController()
    
    func boot(routes: any RoutesBuilder) throws {
        let api = routes
            .grouped("api")
            .grouped("rules-generation")
            .groupedOpenAPI(tags: .init(name: "Rules Generation", description: "AI-powered game box recognition and rules summarization"))

        // Image analysis endpoint - rate limiting handled by RateLimitMiddleware
        api
            .on(.POST, "game-box-analysis", body: .stream, use: controller.analyzeBoxPhoto)
            .openAPI(
                summary: "Analyze game box image",
                description: "Upload game box image (JPEG/PNG) for AI-powered title recognition. Send as binary data in request body with Content-Type: image/jpeg or image/png. Returns guessed title, confidence score, and alternative suggestions. Rate limited to 3 requests/hour in production.",
                response: .type(GameboxRecognition.Response.self)
            )

        // Rules generation endpoint - rate limiting handled by RateLimitMiddleware
        api
            .post("rules-summary", use: controller.generateRulesSummary)
            .openAPI(
                description: "Generate AI-powered rules summary for a board game by title. Returns setup instructions, first round guide, win conditions, and helpful resources. Rate limited to 10 requests/hour in production.",
                body: .type(RulesSummary.Request.self),
                response: .type(RulesSummary.Response.self)
            )
    }
}
