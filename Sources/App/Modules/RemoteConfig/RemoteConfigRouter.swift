import Vapor
import VaporToOpenAPI

struct RemoteConfigRouter: RouteCollection {
    let controller = RemoteConfigController()

    func boot(routes: RoutesBuilder) throws {
        // Public endpoint at /api/v1/config
        let publicAPI = routes
            .grouped("api")
            .grouped("v1")
            .grouped("config")
            .groupedOpenAPI(tags: .init(name: "Remote Config", description: "Remote configuration for mobile apps"))

        publicAPI
            .get(use: controller.getConfig)
            .openAPI(
                description: "Retrieve current remote configuration including feature flags and settings. Public endpoint - no authentication required. Response is cached for 5 minutes.",
                response: .type(RemoteConfig.Response.self)
            )

        // Admin endpoints at /api/v1/admin/config
        let adminAPI = routes
            .grouped("api")
            .grouped("v1")
            .grouped("admin")
            .grouped("config")
            .groupedOpenAPI(tags: .init(name: "Remote Config Admin", description: "Remote configuration management for administrators"))
            .grouped(UserAccountModel.guard())
            .grouped(EnsureAdminUserMiddleware())

        adminAPI
            .get(use: controller.list)
            .openAPI(
                description: "List all configuration entries. Admin only.",
                response: .type(RemoteConfig.List.Response.self),
                auth: .bearer(id: "bearerAuth")
            )

        adminAPI
            .post(use: controller.create)
            .openAPI(
                description: "Create a new configuration entry. Invalidates the config cache immediately. Admin only.",
                body: .type(RemoteConfig.Create.Request.self),
                response: .type(RemoteConfig.Create.Response.self),
                auth: .bearer(id: "bearerAuth")
            )
            .response(statusCode: .badRequest, description: "Invalid request data or value type mismatch")
            .response(statusCode: .conflict, description: "Configuration key already exists")

        adminAPI
            .patch(":id", use: controller.update)
            .openAPI(
                description: "Update an existing configuration entry. Invalidates the config cache immediately. Admin only.",
                body: .type(RemoteConfig.Update.Request.self),
                response: .type(RemoteConfig.Update.Response.self),
                auth: .bearer(id: "bearerAuth")
            )
            .response(statusCode: .badRequest, description: "Invalid request data or value type mismatch")
            .response(statusCode: .notFound, description: "Configuration entry not found")

        adminAPI
            .delete(":id", use: controller.delete)
            .openAPI(
                description: "Delete a configuration entry. Invalidates the config cache immediately. Admin only.",
                response: .type(RemoteConfig.Delete.Response.self),
                auth: .bearer(id: "bearerAuth")
            )
            .response(statusCode: .notFound, description: "Configuration entry not found")
    }
}
