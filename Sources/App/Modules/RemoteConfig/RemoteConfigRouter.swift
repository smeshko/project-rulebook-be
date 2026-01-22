import Vapor
import VaporToOpenAPI

struct RemoteConfigRouter: RouteCollection {
    let controller = RemoteConfigController()

    func boot(routes: RoutesBuilder) throws {
        let api = routes
            .grouped("api")
            .grouped("v1")
            .grouped("config")
            .groupedOpenAPI(tags: .init(name: "Remote Config", description: "Remote configuration management"))

        // Public endpoint - no authentication required
        api
            .get(use: controller.getConfig)
            .openAPI(
                description: "Fetch all remote configuration values. Returns feature flags and settings grouped by category.",
                response: .type(RemoteConfig.Get.Response.self)
            )

        // Admin-only endpoints - require authentication and admin role
        let adminAPI = api
            .grouped(UserAccountModel.guard())
            .grouped(EnsureAdminUserMiddleware())

        adminAPI
            .get("admin", use: controller.listAllConfig)
            .openAPI(
                description: "List all configuration entries with metadata. Admin only.",
                response: .type(RemoteConfig.List.Response.self),
                auth: .bearer(id: "bearerAuth")
            )

        adminAPI
            .post(use: controller.createConfig)
            .openAPI(
                description: "Create a new configuration entry. Admin only.",
                body: .type(RemoteConfig.Create.Request.self),
                response: .type(RemoteConfig.Create.Response.self),
                auth: .bearer(id: "bearerAuth")
            )
            .response(statusCode: .conflict, description: "Configuration key already exists")

        adminAPI
            .patch(":key", use: controller.updateConfig)
            .openAPI(
                description: "Update an existing configuration entry. Admin only.",
                body: .type(RemoteConfig.Update.Request.self),
                response: .type(RemoteConfig.Update.Response.self),
                auth: .bearer(id: "bearerAuth")
            )
            .response(statusCode: .notFound, description: "Configuration key not found")

        adminAPI
            .delete(":key", use: controller.deleteConfig)
            .openAPI(
                description: "Delete a configuration entry. Admin only.",
                response: .type(RemoteConfig.Delete.Response.self),
                auth: .bearer(id: "bearerAuth")
            )
            .response(statusCode: .notFound, description: "Configuration key not found")
    }
}
