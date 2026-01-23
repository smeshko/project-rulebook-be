import Vapor
import VaporToOpenAPI

struct RemoteConfigRouter: RouteCollection {

    let controller = RemoteConfigController()

    func boot(routes: RoutesBuilder) throws {
        configPublic(routes: routes)
        configAdmin(routes: routes)
    }
}

private extension RemoteConfigRouter {
    func configPublic(routes: RoutesBuilder) {
        let api = routes
            .grouped("api")
            .grouped("v1")
            .grouped("config")
            .groupedOpenAPI(tags: .init(name: "Remote Config", description: "Remote configuration and feature flags"))

        api
            .get(use: controller.getConfig)
            .openAPI(
                description: "Retrieve all remote configuration values including feature flags and settings. Public endpoint, no authentication required.",
                response: .type(RemoteConfig.Get.Response.self)
            )
    }

    func configAdmin(routes: RoutesBuilder) {
        let adminAPI = routes
            .grouped("api")
            .grouped("v1")
            .grouped("config")
            .grouped("admin")
            .groupedOpenAPI(tags: .init(name: "Remote Config Admin", description: "Remote configuration management for administrators"))
            .grouped(UserPayloadAuthenticator())
            .grouped(UserAccountModel.guard())
            .grouped(EnsureAdminUserMiddleware())

        adminAPI
            .post(use: controller.createConfig)
            .openAPI(
                description: "Create a new configuration entry. Requires admin privileges.",
                body: .type(RemoteConfig.Create.Request.self),
                response: .type(RemoteConfig.Create.Response.self),
                auth: .bearer(id: "bearerAuth")
            )

        adminAPI
            .patch(":id", use: controller.updateConfig)
            .openAPI(
                description: "Update an existing configuration entry. Requires admin privileges.",
                body: .type(RemoteConfig.Update.Request.self),
                response: .type(RemoteConfig.Update.Response.self),
                auth: .bearer(id: "bearerAuth")
            )

        adminAPI
            .delete(":id", use: controller.deleteConfig)
            .openAPI(
                description: "Delete a configuration entry. Requires admin privileges.",
                response: .type(RemoteConfig.Delete.Response.self),
                auth: .bearer(id: "bearerAuth")
            )
    }
}
