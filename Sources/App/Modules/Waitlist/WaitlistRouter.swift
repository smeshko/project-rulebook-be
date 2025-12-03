import Vapor
import VaporToOpenAPI

struct WaitlistRouter: RouteCollection {
    let controller = WaitlistController()

    func boot(routes: RoutesBuilder) throws {
        let api = routes
            .grouped("api")
            .grouped("waitlist")
            .groupedOpenAPI(tags: .init(name: "Waitlist", description: "Email waitlist management"))

        // Public endpoints (rate limited via middleware)
        api
            .post(use: controller.subscribe)
            .openAPI(
                description: "Subscribe an email address to the waitlist. Sends a confirmation email on success. Duplicate emails are handled gracefully.",
                body: .type(Waitlist.Subscribe.Request.self),
                response: .type(Waitlist.Subscribe.Response.self)
            )
            .response(statusCode: .badRequest, description: "Invalid email format")

        api
            .get("unsubscribe", ":token", use: controller.unsubscribe)
            .openAPI(
                description: "Unsubscribe from the waitlist using the token from the confirmation email.",
                response: .type(Waitlist.Unsubscribe.Response.self)
            )
            .response(statusCode: .notFound, description: "Invalid or expired unsubscribe token")

        // Admin-only endpoints
        let adminAPI = api
            .grouped(UserAccountModel.guard())
            .grouped(EnsureAdminUserMiddleware())

        adminAPI
            .get("stats", use: controller.stats)
            .openAPI(
                description: "Get waitlist statistics including total subscribers, notified count, and pending count. Admin only.",
                response: .type(Waitlist.Stats.Response.self),
                auth: .bearer(id: "bearerAuth")
            )

        adminAPI
            .post("notify", use: controller.notify)
            .openAPI(
                description: "Send launch notification to all unnotified subscribers. Processes sequentially to respect email rate limits. Admin only.",
                response: .type(Waitlist.Notify.Response.self),
                auth: .bearer(id: "bearerAuth")
            )
    }
}
