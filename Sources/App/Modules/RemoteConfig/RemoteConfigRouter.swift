import Vapor
import VaporToOpenAPI

struct RemoteConfigRouter: RouteCollection {

    let controller = RemoteConfigController()

    func boot(routes: any RoutesBuilder) throws {
        // Public config endpoint - no authentication required
        let publicAPI = routes
            .grouped("api")
            .grouped("v1")
            .grouped("config")
            .groupedOpenAPI(tags: .init(name: "Remote Config", description: "Remote configuration management for mobile apps"))

        publicAPI
            .get(use: controller.getConfig)
            .openAPI(
                description: "Retrieve all remote configuration values grouped by category (featureFlags, settings). This endpoint is public and does not require authentication.",
                response: .type(RemoteConfig.Get.Response.self)
            )

        // Admin config management endpoints - require admin authentication
        let adminAPI = routes
            .grouped("api")
            .grouped("v1")
            .grouped("config")
            .groupedOpenAPI(tags: .init(name: "Remote Config Admin", description: "Remote configuration administration for authorized administrators"))
            .grouped(UserAccountModel.guard())
            .grouped(EnsureAdminUserMiddleware())

        adminAPI
            .post(use: controller.createConfig)
            .openAPI(
                description: "Create a new configuration entry. Requires admin authentication. Value must match the declared value_type.",
                body: .type(RemoteConfig.Create.Request.self),
                response: .type(RemoteConfig.Create.Response.self),
                auth: .bearer(id: "bearerAuth")
            )

        adminAPI
            .patch(":key", use: controller.updateConfig)
            .openAPI(
                description: "Update an existing configuration entry by key. Requires admin authentication. New value must match the existing value_type.",
                body: .type(RemoteConfig.Update.Request.self),
                response: .type(RemoteConfig.Update.Response.self),
                auth: .bearer(id: "bearerAuth")
            )

        adminAPI
            .delete(":key", use: controller.deleteConfig)
            .openAPI(
                description: "Delete a configuration entry by key. Requires admin authentication. This action is irreversible.",
                response: .type(RemoteConfig.Delete.Response.self),
                auth: .bearer(id: "bearerAuth")
            )
    }
}
