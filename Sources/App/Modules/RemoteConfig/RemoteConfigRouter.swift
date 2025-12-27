import Vapor
import VaporToOpenAPI

struct RemoteConfigRouter: RouteCollection {
    let controller = RemoteConfigController()

    func boot(routes: RoutesBuilder) throws {
        let api = routes
            .grouped("api")
            .grouped("v1")
            .grouped("config")
            .groupedOpenAPI(tags: .init(
                name: "Remote Config",
                description: "Remote configuration and feature flags for mobile apps"
            ))

        // Public endpoint - no authentication required
        api
            .get(use: controller.getConfig)
            .openAPI(
                description: "Get all configuration values including feature flags and settings. Public endpoint accessible without authentication.",
                response: .type(RemoteConfig.Response.self)
            )

        // Admin endpoints - require authentication
        let admin = api
            .grouped("admin")
            .grouped(UserAccountModel.guard())

        admin
            .post(use: controller.createOrUpdateConfig)
            .openAPI(
                description: "Create or update a configuration entry. Requires admin authentication. Cache is automatically invalidated.",
                body: .type(RemoteConfig.CreateConfigRequest.self),
                response: .type(RemoteConfig.ConfigEntry.self),
                auth: .bearer(id: "bearerAuth")
            )

        admin
            .get(use: controller.getAllConfigEntries)
            .openAPI(
                description: "List all configuration entries with their types and metadata. Requires admin authentication.",
                response: .type([RemoteConfig.ConfigEntry].self),
                auth: .bearer(id: "bearerAuth")
            )

        admin
            .delete(":key", use: controller.deleteConfig)
            .openAPI(
                description: "Delete a configuration entry by key. Requires admin authentication. Cache is automatically invalidated.",
                auth: .bearer(id: "bearerAuth")
            )
            .response(statusCode: .ok, description: "Configuration deleted successfully")
    }
}
