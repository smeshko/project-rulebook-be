import Vapor
import VaporToOpenAPI

struct HealthRouter: RouteCollection {
    let controller = HealthController()

    func boot(routes: any RoutesBuilder) throws {
        let health = routes
            .grouped("health")
            .groupedOpenAPI(tags: .init(name: "Health", description: "Service health monitoring for infrastructure probes"))

        health
            .get(use: controller.check)
            .openAPI(
                description: "Health check endpoint for monitoring and deployment systems. Returns service health status with database and Redis connectivity checks.",
                response: .type(Health.Check.Response.self)
            )
    }
}
