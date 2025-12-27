import Vapor
import VaporToOpenAPI

struct RemoteConfigRouter: RouteCollection {
    let controller = RemoteConfigController()

    func boot(routes: RoutesBuilder) throws {
        let apiV1 = routes
            .grouped("api")
            .grouped("v1")
            .groupedOpenAPI(tags: .init(name: "Remote Config", description: "Configuration and feature flags"))

        // Public endpoint - GET /api/v1/config
        apiV1
            .grouped("config")
            .get(use: controller.getConfig)
            .openAPI(
                description: "Fetch feature flags and configuration. No authentication required. Heavily cached for performance.",
                response: .type(RemoteConfig.GetResponse.self)
            )

        // Admin endpoint - PATCH /api/v1/admin/config
        let admin = apiV1
            .grouped("admin")
            .grouped(UserPayloadAuthenticator())
            .grouped(EnsureAdminUserMiddleware())
            .grouped("config")

        admin
            .patch(use: controller.updateConfig)
            .openAPI(
                description: "Update configuration values. Requires admin authentication. Invalidates cache on success.",
                body: .type(RemoteConfig.UpdateRequest.self),
                response: .type(RemoteConfig.UpdateResponse.self),
                auth: .bearer(id: "bearerAuth")
            )
    }
}
