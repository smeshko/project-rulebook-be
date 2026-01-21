import Vapor
import VaporToOpenAPI

struct RemoteConfigRouter: RouteCollection {
    let controller = RemoteConfigController()

    func boot(routes: RoutesBuilder) throws {
        // Public endpoint - no authentication required
        let publicAPI = routes
            .grouped("api")
            .grouped("v1")
            .grouped("config")
            .groupedOpenAPI(tags: .init(name: "Remote Config", description: "Remote configuration for mobile clients"))

        publicAPI
            .get(use: controller.getConfig)
            .openAPI(
                description: "Get remote configuration including feature flags and settings",
                response: .type(RemoteConfig.Response.self)
            )

        // Admin endpoints - require authentication and admin role
        let adminAPI = routes
            .grouped("api")
            .grouped("v1")
            .grouped("admin")
            .grouped("config")
            .groupedOpenAPI(tags: .init(name: "Remote Config Admin", description: "Admin endpoints for managing remote configuration"))
            .grouped(UserAccountModel.guard())
            .grouped(EnsureAdminUserMiddleware())

        adminAPI
            .get(use: controller.list)
            .openAPI(
                description: "List all configuration entries",
                response: .type(RemoteConfig.List.Response.self),
                auth: .bearer(id: "bearerAuth")
            )

        adminAPI
            .post(use: controller.create)
            .openAPI(
                description: "Create a new configuration entry",
                body: .type(RemoteConfig.Create.Request.self),
                response: .type(RemoteConfig.Create.Response.self),
                auth: .bearer(id: "bearerAuth")
            )

        adminAPI
            .group(":id") { entry in
                entry
                    .get(use: controller.get)
                    .openAPI(
                        description: "Get a specific configuration entry",
                        response: .type(RemoteConfig.Detail.Response.self),
                        auth: .bearer(id: "bearerAuth")
                    )

                entry
                    .patch(use: controller.update)
                    .openAPI(
                        description: "Update a configuration entry",
                        body: .type(RemoteConfig.Update.Request.self),
                        response: .type(RemoteConfig.Update.Response.self),
                        auth: .bearer(id: "bearerAuth")
                    )

                entry
                    .delete(use: controller.delete)
                    .openAPI(
                        description: "Delete a configuration entry",
                        response: .type(RemoteConfig.Delete.Response.self),
                        auth: .bearer(id: "bearerAuth")
                    )
            }
    }
}
