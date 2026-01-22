import Vapor
import VaporToOpenAPI

struct RemoteConfigRouter: RouteCollection {
    let controller = RemoteConfigController()

    func boot(routes: RoutesBuilder) throws {
        let api = routes
            .grouped("api")
            .grouped("v1")
            .grouped("config")
            .groupedOpenAPI(tags: .init(name: "Remote Config", description: "Remote configuration management for mobile apps"))

        // Public endpoint (for client apps to fetch configuration)
        // No authentication required
        api
            .get(use: controller.getConfig)
            .openAPI(
                description: "Get all remote configuration values grouped into feature flags and settings. This is a public endpoint for mobile apps - no authentication required.",
                response: .type(RemoteConfig.Get.Response.self)
            )

        // Admin-only endpoints for managing configuration
        let adminAPI = api
            .grouped(UserAccountModel.guard())
            .grouped(EnsureAdminUserMiddleware())

        adminAPI
            .get("list", use: controller.listConfigs)
            .openAPI(
                description: "List all remote configuration entries with full metadata. Admin only.",
                response: .type(RemoteConfig.List.Response.self),
                auth: .bearer(id: "bearerAuth")
            )

        adminAPI
            .post(use: controller.createConfig)
            .openAPI(
                description: "Create a new remote configuration entry. Admin only.",
                body: .type(RemoteConfig.Create.Request.self),
                response: .type(RemoteConfig.Create.Response.self),
                auth: .bearer(id: "bearerAuth")
            )
            .response(statusCode: .conflict, description: "Configuration key already exists")
            .response(statusCode: .badRequest, description: "Invalid value for declared type")

        adminAPI
            .patch(":key", use: controller.updateConfig)
            .openAPI(
                description: "Update an existing remote configuration entry by key. Admin only.",
                body: .type(RemoteConfig.Update.Request.self),
                response: .type(RemoteConfig.Update.Response.self),
                auth: .bearer(id: "bearerAuth")
            )
            .response(statusCode: .notFound, description: "Configuration key not found")
            .response(statusCode: .badRequest, description: "Invalid value for declared type")

        adminAPI
            .delete(":key", use: controller.deleteConfig)
            .openAPI(
                description: "Delete a remote configuration entry by key. Admin only.",
                response: .type(RemoteConfig.Delete.Response.self),
                auth: .bearer(id: "bearerAuth")
            )
            .response(statusCode: .notFound, description: "Configuration key not found")
    }
}
