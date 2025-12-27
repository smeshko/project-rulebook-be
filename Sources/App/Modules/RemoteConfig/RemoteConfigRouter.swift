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

        // Public endpoint (AC: 2 - No authentication required)
        api
            .get(use: controller.getConfig)
            .openAPI(
                description: "Fetch active remote configuration including feature flags and settings. Public endpoint, no authentication required.",
                response: .type(RemoteConfig.Entry.Response.self)
            )

        // Admin endpoints (AC: 5 - Requires authentication + admin role)
        let protectedAPI = api
            .grouped("admin")
            .grouped(UserAccountModel.guard())
            .grouped(EnsureAdminUserMiddleware())

        protectedAPI
            .post(use: controller.createConfig)
            .openAPI(
                description: "Create new configuration entry. Requires admin privileges. Cache is invalidated automatically.",
                body: .type(RemoteConfig.Create.Request.self),
                response: .type(RemoteConfig.Create.Response.self),
                auth: .bearer(id: "bearerAuth")
            )

        protectedAPI
            .patch(":key", use: controller.updateConfig)
            .openAPI(
                description: "Update existing configuration by key. Requires admin privileges. Cache is invalidated automatically.",
                body: .type(RemoteConfig.Update.Request.self),
                response: .type(RemoteConfig.Update.Response.self),
                auth: .bearer(id: "bearerAuth")
            )

        protectedAPI
            .delete(":key", use: controller.deleteConfig)
            .openAPI(
                description: "Delete configuration by key. Requires admin privileges. Cache is invalidated automatically.",
                response: .type(RemoteConfig.Delete.Response.self),
                auth: .bearer(id: "bearerAuth")
            )
    }
}
