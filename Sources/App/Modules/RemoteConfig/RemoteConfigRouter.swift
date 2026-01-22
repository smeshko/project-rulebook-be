import Vapor
import VaporToOpenAPI

struct RemoteConfigRouter: RouteCollection {
    let controller = RemoteConfigController()

    func boot(routes: RoutesBuilder) throws {
        let api = routes
            .grouped("api")
            .grouped("v1")
            .grouped("config")
            .groupedOpenAPI(tags: .init(name: "Remote Config", description: "Remote configuration for mobile clients"))

        // Public endpoint (no auth required)
        api
            .get(use: controller.getPublicConfig)
            .openAPI(
                description: "Get public configuration including feature flags and settings for mobile clients. Cached with 5-minute TTL.",
                response: .type(RemoteConfig.Public.Response.self)
            )

        // Admin-only endpoints
        let adminAPI = routes
            .grouped("api")
            .grouped("v1")
            .grouped("admin")
            .grouped("config")
            .groupedOpenAPI(tags: .init(name: "Remote Config Admin", description: "Remote configuration administration"))
            .grouped(UserAccountModel.guard())
            .grouped(EnsureAdminUserMiddleware())

        adminAPI
            .get(use: controller.listEntries)
            .openAPI(
                description: "List all config entries. Admin only.",
                response: .type(RemoteConfig.List.Response.self),
                auth: .bearer(id: "bearerAuth")
            )

        adminAPI
            .post(use: controller.createEntry)
            .openAPI(
                description: "Create a new config entry. Admin only.",
                body: .type(RemoteConfig.Create.Request.self),
                response: .type(RemoteConfig.Create.Response.self),
                auth: .bearer(id: "bearerAuth")
            )
            .response(statusCode: .conflict, description: "Config entry with this key already exists")
            .response(statusCode: .badRequest, description: "Invalid value for declared type")

        adminAPI
            .patch(":key", use: controller.updateEntry)
            .openAPI(
                description: "Update an existing config entry. Admin only.",
                body: .type(RemoteConfig.Update.Request.self),
                response: .type(RemoteConfig.Update.Response.self),
                auth: .bearer(id: "bearerAuth")
            )
            .response(statusCode: .notFound, description: "Config entry not found")
            .response(statusCode: .badRequest, description: "Invalid value for declared type")

        adminAPI
            .delete(":key", use: controller.deleteEntry)
            .openAPI(
                description: "Delete a config entry. Admin only.",
                response: .type(RemoteConfig.Delete.Response.self),
                auth: .bearer(id: "bearerAuth")
            )
            .response(statusCode: .notFound, description: "Config entry not found")
    }
}
