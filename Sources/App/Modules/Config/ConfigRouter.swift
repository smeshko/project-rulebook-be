import Vapor
import VaporToOpenAPI

struct ConfigRouter: RouteCollection {
    let controller = ConfigController()

    func boot(routes: RoutesBuilder) throws {
        let api = routes
            .grouped("api")
            .grouped("v1")
            .grouped("config")
            .groupedOpenAPI(tags: .init(name: "Config", description: "Remote configuration for mobile apps"))

        // Public endpoint (no authentication required)
        api
            .get(use: controller.getConfig)
            .openAPI(
                description: "Get remote configuration values including feature flags and settings. Public endpoint, no authentication required.",
                response: .type(Config.Response.self)
            )

        // Admin endpoints (requires admin authentication)
        let adminAPI = routes
            .grouped("api")
            .grouped("v1")
            .grouped("admin")
            .grouped("config")
            .groupedOpenAPI(tags: .init(name: "Config Admin", description: "Configuration management for administrators"))
            .grouped(UserAccountModel.guard())
            .grouped(EnsureAdminUserMiddleware())

        adminAPI
            .put(use: controller.updateConfig)
            .openAPI(
                description: "Update configuration values. Invalidates cache immediately. Admin only.",
                body: .type(Config.Update.Request.self),
                response: .type(Config.Response.self),
                auth: .bearer(id: "bearerAuth")
            )
    }
}
