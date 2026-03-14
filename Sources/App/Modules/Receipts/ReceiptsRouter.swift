import Vapor
import VaporToOpenAPI

struct ReceiptsRouter: RouteCollection {

    let controller = ReceiptsController()

    func boot(routes: RoutesBuilder) throws {
        let api = routes
            .grouped("api")
            .grouped("v1")
            .grouped("receipts")
            .groupedOpenAPI(tags: .init(name: "Receipts", description: "In-app purchase receipt validation"))

        api
            .post("validate", use: controller.validate)
            .openAPI(
                description: "Validate an in-app purchase receipt for iOS or Android. Returns validation status and transaction ID.",
                body: .type(Receipts.Validate.Request.self),
                response: .type(Receipts.Validate.Response.self)
            )
    }
}
