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

        // Public endpoint (for client apps to fetch configuration)
        // Routes will be fully implemented in Task 6

        // Admin-only endpoints for managing configuration
        // Routes will be fully implemented in Task 6
    }
}
