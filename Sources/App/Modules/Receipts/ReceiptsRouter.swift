import Vapor
import VaporToOpenAPI

struct ReceiptsRouter: RouteCollection {

    let controller = ReceiptsController()

    func boot(routes: RoutesBuilder) throws {}
}
