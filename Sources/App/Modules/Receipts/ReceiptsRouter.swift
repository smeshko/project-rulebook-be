import Vapor
import VaporToOpenAPI

struct ReceiptsRouter: RouteCollection {

    let controller = ReceiptsController()

    func boot(routes: RoutesBuilder) throws {
        // Route group at /api/v1/receipts
        // Actual routes will be added in Story 2.4
        _ = routes
            .grouped("api")
            .grouped("v1")
            .grouped("receipts")
            .groupedOpenAPI(tags: .init(name: "Receipts", description: "In-app purchase receipt validation"))
    }
}
