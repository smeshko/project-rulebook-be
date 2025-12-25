import Vapor
import VaporToOpenAPI

/// Router for purchases-related endpoints.
struct PurchasesRouter: RouteCollection {
    let controller = PurchasesController()

    func boot(routes: RoutesBuilder) throws {
        // Purchases endpoints use device ID for identification (no user auth)
        let purchases = routes
            .grouped("api", "v1", "purchases")

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
                response: .type(Purchases.Validate.Response.self)
            )

        // GET /api/v1/purchases/:deviceId - List device's purchases
        purchases.get(":deviceId", use: controller.list)
            .openAPI(
                summary: "List device purchases",
                description: "Returns all validated purchases for the specified device.",
                response: .type(Purchases.List.Response.self)
            )

        // GET /api/v1/purchases/:deviceId/active - Get active entitlements
        purchases.get(":deviceId", "active", use: controller.active)
            .openAPI(
                summary: "Get active entitlements",
                description: """
                    Returns the device's active purchases and entitlements.
                    Use this to check if a device has premium access.
                    """,
                response: .type(Purchases.Active.Response.self)
            )
    }
}
