import Vapor
import VaporToOpenAPI

/// Router for purchases-related endpoints.
struct PurchasesRouter: RouteCollection {
    let controller = PurchasesController()

    func boot(routes: RoutesBuilder) throws {
        // All purchases endpoints require authentication
        let purchases = routes
            .grouped("api", "v1", "purchases")
            .grouped(UserPayloadAuthenticator())
            .grouped(UserAccountModel.guardMiddleware())

        // POST /api/v1/purchases/validate - Validate a purchase receipt
        purchases.post("validate", use: controller.validate)
            .openAPI(
                summary: "Validate purchase receipt",
                description: """
                    Validates an in-app purchase receipt from iOS or Android.

                    For iOS: Send the signedTransactionInfo JWS string from StoreKit 2.
                    For Android: Send the purchase token and product ID from Google Play Billing.

                    The endpoint verifies the receipt signature, stores it for duplicate detection,
                    and returns the validated transaction information.
                    """,
                body: .type(Purchases.Validate.Request.self),
                response: .type(Purchases.Validate.Response.self),
                auth: .bearer()
            )

        // GET /api/v1/purchases - List user's purchases
        purchases.get(use: controller.list)
            .openAPI(
                summary: "List user purchases",
                description: "Returns all validated purchases for the authenticated user.",
                response: .type(Purchases.List.Response.self),
                auth: .bearer()
            )

        // GET /api/v1/purchases/active - Get active entitlements
        purchases.get("active", use: controller.active)
            .openAPI(
                summary: "Get active entitlements",
                description: """
                    Returns the user's active purchases and entitlements.
                    Use this to check if a user has premium access.
                    """,
                response: .type(Purchases.Active.Response.self),
                auth: .bearer()
            )
    }
}
