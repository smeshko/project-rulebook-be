import Vapor
import VaporToOpenAPI

struct ReceiptsRouter: RouteCollection {

    let controller = ReceiptsController()
    let appleNotificationsController = AppleNotificationsController()

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

        // Apple Server Notifications V2 webhook (no auth middleware — verification via JWS)
        let notifications = routes
            .grouped("api")
            .grouped("v1")
            .grouped("notifications")
            .groupedOpenAPI(tags: .init(name: "Notifications", description: "App Store Server Notifications"))

        notifications
            .post("apple", use: appleNotificationsController.handleNotification)
            .openAPI(
                description: "Receive Apple App Store Server Notifications V2. Always returns 200.",
                body: .type(AppleNotificationsController.AppleNotificationPayload.self)
            )
    }
}
