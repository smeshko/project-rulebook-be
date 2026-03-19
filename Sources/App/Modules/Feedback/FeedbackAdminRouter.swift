import Vapor
import VaporToOpenAPI

struct FeedbackAdminRouter: RouteCollection {
    let controller = FeedbackAdminController()

    func boot(routes: any RoutesBuilder) throws {
        let adminAPI = routes
            .grouped("api")
            .grouped("v1")
            .grouped("admin")
            .grouped("feedback")
            .groupedOpenAPI(tags: .init(name: "Feedback Admin", description: "Feedback management for administrators"))
            .grouped(EnsureAdminUserMiddleware())

        adminAPI
            .get(use: controller.list)
            .openAPI(
                description: "List all feedback with optional status filtering and pagination. Admin only.",
                query: [
                    "status": .string,
                    "page": .integer,
                    "limit": .integer
                ],
                response: .type(Feedback.List.Response.self),
                auth: .bearer(id: "bearerAuth")
            )
            .response(statusCode: .unauthorized, description: "Unauthorized - missing or invalid admin credentials")
            .response(statusCode: .badRequest, description: "Invalid status parameter")

        adminAPI
            .patch(":feedbackId", use: controller.updateStatus)
            .openAPI(
                description: "Update feedback status. Admin only.",
                body: .type(Feedback.UpdateStatus.Request.self),
                response: .type(Feedback.UpdateStatus.Response.self),
                auth: .bearer(id: "bearerAuth")
            )
            .response(statusCode: .unauthorized, description: "Unauthorized - missing or invalid admin credentials")
            .response(statusCode: .badRequest, description: "Invalid status value")
            .response(statusCode: .notFound, description: "Feedback not found")
    }
}
