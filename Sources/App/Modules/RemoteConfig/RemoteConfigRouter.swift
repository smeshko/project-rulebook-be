import Vapor
import VaporToOpenAPI

struct RemoteConfigRouter: RouteCollection {
    let controller = RemoteConfigController()

    func boot(routes: any RoutesBuilder) throws {
        let api = routes
            .grouped("api")
            .grouped("v1")
            .grouped("config")
            .groupedOpenAPI(tags: .init(name: "Remote Config", description: "Feature flags and application settings"))

        // Public endpoint - no authentication required
        api
            .get(use: controller.getConfig)
            .openAPI(
                description: "Retrieve all remote configuration values. Returns feature flags and settings grouped by category. This endpoint is public and does not require authentication. Responses are cached with a 5-minute TTL.",
                response: .type(RemoteConfig.Get.Response.self)
            )

        // Admin-only endpoints
        let adminAPI = api
            .grouped(UserAccountModel.guard())
            .grouped(EnsureAdminUserMiddleware())

        adminAPI
            .post(use: controller.createConfig)
            .openAPI(
                description: "Create a new configuration entry. Requires admin authentication. The key must be unique across all configurations.",
                body: .type(RemoteConfig.Create.Request.self),
                response: .type(RemoteConfig.Item.Response.self),
                auth: .bearer(id: "bearerAuth")
            )

        adminAPI
            .patch(":key", use: controller.updateConfig)
            .openAPI(
                description: "Update an existing configuration entry by key. Requires admin authentication. Only provided fields are updated.",
                body: .type(RemoteConfig.Update.Request.self),
                response: .type(RemoteConfig.Item.Response.self),
                auth: .bearer(id: "bearerAuth")
            )

        adminAPI
            .delete(":key", use: controller.deleteConfig)
            .openAPI(
                description: "Delete a configuration entry by key. Requires admin authentication. Uses soft delete.",
                auth: .bearer(id: "bearerAuth")
            )
            .response(statusCode: .noContent, description: "Configuration deleted successfully")
    }
}
