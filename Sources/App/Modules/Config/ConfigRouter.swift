import Vapor
import VaporToOpenAPI

struct ConfigRouter: RouteCollection {
    let controller = ConfigController()

    func boot(routes: RoutesBuilder) throws {
        // Public config endpoint (no auth required)
        let api = routes
            .grouped("api")
            .grouped("v1")
            .grouped("config")
            .groupedOpenAPI(tags: .init(name: "Config", description: "Remote configuration and feature flags"))

        api
            .get(use: controller.getConfig)
            .openAPI(
                description: "Get all configuration values including feature flags and settings. Public endpoint - no authentication required.",
                response: .type(Config.Response.self)
            )

        // Admin config endpoints (requires admin authentication)
        let adminAPI = routes
            .grouped("api")
            .grouped("v1")
            .grouped("admin")
            .grouped("config")
            .groupedOpenAPI(tags: .init(name: "Config Admin", description: "Admin configuration management"))
            .grouped(UserAccountModel.guard())
            .grouped(EnsureAdminUserMiddleware())

        adminAPI
            .get(use: controller.listConfig)
            .openAPI(
                description: "List all config entries with metadata. Admin only.",
                response: .type(Config.Admin.ListResponse.self),
                auth: .bearer(id: "bearerAuth")
            )

        adminAPI
            .post(use: controller.createConfig)
            .openAPI(
                description: "Create a new config entry. Admin only.",
                body: .type(Config.Admin.CreateRequest.self),
                response: .type(Config.Admin.ConfigEntryResponse.self),
                auth: .bearer(id: "bearerAuth")
            )
            .response(statusCode: .conflict, description: "Config key already exists")

        adminAPI
            .put(":key", use: controller.updateConfig)
            .openAPI(
                description: "Update an existing config entry by key. Admin only.",
                body: .type(Config.Admin.UpdateRequest.self),
                response: .type(Config.Admin.ConfigEntryResponse.self),
                auth: .bearer(id: "bearerAuth")
            )
            .response(statusCode: .notFound, description: "Config key not found")

        adminAPI
            .delete(":key", use: controller.deleteConfig)
            .openAPI(
                description: "Delete a config entry by key. Admin only.",
                response: .type(Config.Admin.DeleteResponse.self),
                auth: .bearer(id: "bearerAuth")
            )
            .response(statusCode: .notFound, description: "Config key not found")
    }
}
