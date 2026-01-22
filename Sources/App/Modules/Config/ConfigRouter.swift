import Vapor
import VaporToOpenAPI

struct ConfigRouter: RouteCollection {
    let controller = ConfigController()

    func boot(routes: RoutesBuilder) throws {
        // Routes will be implemented in Task 5
    }
}
