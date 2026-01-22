import Vapor
import VaporToOpenAPI

struct ConfigRouter: RouteCollection {
    let controller = ConfigController()

    func boot(routes: RoutesBuilder) throws {
        let api = routes
            .grouped("api")
            .grouped("v1")
            .grouped("config")
            .groupedOpenAPI(tags: .init(name: "Config", description: "Remote configuration management"))

        // Public endpoint (no authentication required)
        api
            .get(use: controller.getConfig)
            .openAPI(
                description: "Get all configuration values grouped by category. Returns feature flags and settings as typed values. This endpoint is publicly accessible without authentication.",
                response: .type(Config.Get.Response.self)
            )

        // Admin-only endpoints
        let adminAPI = api
            .grouped(UserAccountModel.guard())
            .grouped(EnsureAdminUserMiddleware())

        adminAPI
            .get("list", use: controller.listConfigs)
            .openAPI(
                description: "List all configuration entries with full details. Admin only.",
                response: .type(Config.List.Response.self),
                auth: .bearer(id: "bearerAuth")
            )

        adminAPI
            .post(use: controller.createConfig)
            .openAPI(
                description: "Create a new configuration entry. Admin only.",
                body: .type(Config.Create.Request.self),
                response: .type(Config.Entry.Response.self),
                auth: .bearer(id: "bearerAuth")
            )
            .response(statusCode: .conflict, description: "Config key already exists")
            .response(statusCode: .badRequest, description: "Invalid request body")

        adminAPI
            .patch(":id", use: controller.updateConfig)
            .openAPI(
                description: "Update an existing configuration entry. Admin only.",
                body: .type(Config.Update.Request.self),
                response: .type(Config.Entry.Response.self),
                auth: .bearer(id: "bearerAuth")
            )
            .response(statusCode: .notFound, description: "Config entry not found")
            .response(statusCode: .badRequest, description: "Invalid config ID or request body")

        adminAPI
            .delete(":id", use: controller.deleteConfig)
            .openAPI(
                description: "Delete a configuration entry. Admin only.",
                auth: .bearer(id: "bearerAuth")
            )
            .response(statusCode: .noContent, description: "Config entry deleted successfully")
            .response(statusCode: .notFound, description: "Config entry not found")
            .response(statusCode: .badRequest, description: "Invalid config ID")
    }
}
