import Vapor
import VaporToOpenAPI

struct ConfigRouter: RouteCollection {
    let controller = ConfigController()

    func boot(routes: RoutesBuilder) throws {
        let api = routes
            .grouped("api")
            .grouped("v1")
            .grouped("config")
            .groupedOpenAPI(tags: .init(name: "Config", description: "Remote configuration"))

        // Public endpoint (no authentication required)
        api
            .get(use: controller.getConfig)
            .openAPI(
                description: "Get all remote configuration values including feature flags and settings",
                response: .type(Config.Response.self)
            )

        // Admin-only endpoints at /api/v1/admin/config
        let adminAPI = routes
            .grouped("api")
            .grouped("v1")
            .grouped("admin")
            .grouped("config")
            .grouped(UserAccountModel.guard())
            .grouped(EnsureAdminUserMiddleware())
            .groupedOpenAPI(tags: .init(name: "Config Admin", description: "Remote configuration administration"))

        adminAPI
            .patch(use: controller.updateConfig)
            .openAPI(
                description: "Update one or more configuration values. Invalidates cache immediately. Admin only.",
                body: .type(Config.Update.Request.self),
                response: .type(Config.Update.Response.self),
                auth: .bearer(id: "bearerAuth")
            )
    }
}
