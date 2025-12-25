import Vapor
import Fluent

/// Module encapsulating all purchases-related functionality.
///
/// This module provides:
/// - In-app purchase receipt validation for iOS and Android
/// - Receipt storage for duplicate detection
/// - User entitlement tracking
///
/// ## Endpoints
/// - `POST /api/v1/purchases/validate` - Validate a purchase receipt
/// - `GET /api/v1/purchases` - List user's purchases
/// - `GET /api/v1/purchases/active` - Get active entitlements
struct PurchasesModule: ModuleInterface {

    let router = PurchasesRouter()

    func boot(_ app: Application) throws {
        // Register migrations
        for migration in PurchasesMigrations.all {
            app.migrations.add(migration)
        }

        // Register routes
        try router.boot(routes: app.routes)
    }
}
