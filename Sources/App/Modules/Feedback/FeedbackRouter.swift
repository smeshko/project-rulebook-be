import Vapor
import VaporToOpenAPI

struct FeedbackRouter: RouteCollection {

    let controller = FeedbackController()

    func boot(routes: RoutesBuilder) throws {
        let api = routes
            .grouped("api")
            .grouped("v1")
            .grouped("feedback")
            .groupedOpenAPI(tags: .init(name: "Feedback", description: "User feedback on generated rules"))

        // Route bindings will be added in Story 3.2 (submission) and Story 3.3 (admin)
        _ = api
    }
}
