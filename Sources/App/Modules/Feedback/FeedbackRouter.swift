import Vapor
import VaporToOpenAPI

struct FeedbackRouter: RouteCollection {

    let controller = FeedbackController()

    func boot(routes: RoutesBuilder) throws {
        let api = routes
            .grouped("api")
            .grouped("v1")
            .grouped("feedback")
            .groupedOpenAPI(tags: .init(name: "Feedback", description: "User feedback on generated rules"))

        api
            .post(use: controller.submit)
            .openAPI(
                description: "Submit feedback about incorrect or incomplete rules. No authentication required.",
                body: .type(Feedback.Submit.Request.self),
                response: .type(Feedback.Submit.Response.self)
            )
            .response(statusCode: .badRequest, description: "Validation error (missing fields, invalid type, or exceeds length limits)")
            .response(statusCode: .tooManyRequests, description: "Rate limit exceeded (5 requests per hour)")
    }
}
