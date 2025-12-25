## TASK-010: Create Purchases Module, Controller, and Router

---
**Status:** OPEN
**Branch:** feature/app-store-receipt-validation
**Type:** IMPLEMENTATION
**Phase:** 3
**Depends On:** TASK-009
---

### Overview

Create the Purchases module with unified controller endpoint for receipt verification. Controller detects platform from User-Agent and routes to appropriate validator.

**Files:**
- `Sources/App/Modules/Purchases/PurchasesModule.swift` (create)
- `Sources/App/Modules/Purchases/PurchasesRouter.swift` (create)
- `Sources/App/Modules/Purchases/Controllers/PurchasesController.swift` (create)
- `Sources/App/Entrypoint/Application-Setup.swift` (modify)

### Implementation Steps

**Commit 1: feat(purchases): add PurchasesController with unified verify endpoint**
- [ ] Create Controllers directory
- [ ] Create PurchasesController struct
- [ ] Implement verifyPurchase endpoint with platform detection
- [ ] Define response DTO
- [ ] Add proper error handling and logging

**Commit 2: feat(purchases): add PurchasesRouter and PurchasesModule**
- [ ] Create PurchasesRouter with route registration
- [ ] Add authentication middleware to routes
- [ ] Create PurchasesModule implementing ModuleInterface
- [ ] Register module in Application-Setup.swift

### Code Example

```swift
// Sources/App/Modules/Purchases/Controllers/PurchasesController.swift
import Vapor

struct PurchasesController {
    struct VerifyResponse: Content {
        let verified: Bool
        let platform: String
        let productId: String
        let purchaseDate: Date
        let expiresDate: Date?
        let transactionId: String
    }

    func verifyPurchase(_ req: Request) async throws -> VerifyResponse {
        // Get authenticated user
        let user = try req.auth.require(UserAccountModel.self)

        // Detect platform from User-Agent
        let userAgent = req.headers.first(name: .userAgent)
        guard let platform = MobilePlatform.detect(from: userAgent) else {
            req.logger.warning("Unsupported platform in User-Agent",
                metadata: ["userAgent": "\(userAgent ?? "nil")"])
            throw PurchaseValidationError.unsupportedPlatform
        }

        // Decode request
        let input = try req.content.decode(VerifyPurchaseRequest.self)

        req.logger.info("Verifying purchase",
            metadata: [
                "userId": "\(user.id?.uuidString ?? "unknown")",
                "platform": "\(platform.rawValue)"
            ])

        // Validate with appropriate service
        let result = try await req.services.purchaseValidator.validate(
            platform: platform,
            request: input
        )

        // Store validated receipt
        let receipt = ReceiptModel(
            userID: try user.requireID(),
            platform: platform,
            transactionId: result.transactionId,
            originalTransactionId: result.originalTransactionId,
            productId: result.productId,
            purchaseDate: result.purchaseDate,
            expiresDate: result.expiresDate,
            revocationDate: result.revocationDate,
            environment: result.environment
        )
        _ = try await req.repositories.receipts.upsert(receipt)

        req.logger.info("Purchase verified and stored",
            metadata: ["transactionId": "\(result.transactionId)"])

        return VerifyResponse(
            verified: result.verified,
            platform: platform.rawValue,
            productId: result.productId,
            purchaseDate: result.purchaseDate,
            expiresDate: result.expiresDate,
            transactionId: result.transactionId
        )
    }
}

// Sources/App/Modules/Purchases/PurchasesRouter.swift
import Vapor

struct PurchasesRouter: RouteCollection {
    let controller = PurchasesController()

    func boot(routes: RoutesBuilder) throws {
        let api = routes.grouped("api").grouped("purchases")
        let protected = api.grouped(UserAccountModel.authenticator())
            .grouped(UserAccountModel.guardMiddleware())

        protected.post("verify", use: controller.verifyPurchase)
            .openAPI(
                summary: "Verify a purchase",
                description: """
                    Verify an in-app purchase from iOS (App Store) or Android (Google Play).
                    Platform is detected from User-Agent header.

                    **iOS**: Send JWS signed transaction as purchaseToken
                    **Android**: Send purchase token as purchaseToken, include productId
                    """,
                body: .type(VerifyPurchaseRequest.self),
                response: .type(PurchasesController.VerifyResponse.self)
            )
    }
}

// Sources/App/Modules/Purchases/PurchasesModule.swift
import Vapor

struct PurchasesModule: ModuleInterface {
    func boot(_ app: Application) throws {
        app.migrations.add(ReceiptMigrations.V1())
        try app.register(collection: PurchasesRouter())
    }

    func setUp(_ app: Application) throws {
        // No post-boot setup needed
    }
}

// Application-Setup.swift - Add to modules array in setupModules():
PurchasesModule(),
```

### Success Criteria

- [ ] Build succeeds
- [ ] POST /api/purchases/verify endpoint registered
- [ ] Platform correctly detected from User-Agent
- [ ] iOS requests route to App Store validator
- [ ] Android requests route to Google Play validator
- [ ] Authentication required (401 without token)
- [ ] Missing platform returns 400
- [ ] Migration registered
- [ ] Module registered at startup

### Verification

```bash
swift build
swift run &

# Test without auth (should return 401)
curl -X POST http://localhost:8080/api/purchases/verify \
  -H "Content-Type: application/json" \
  -H "User-Agent: TestApp/1.0 (iPhone14,6; iOS 18.0)" \
  -d '{"purchaseToken": "test"}'

# Test without User-Agent (should return 400)
curl -X POST http://localhost:8080/api/purchases/verify \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <token>" \
  -d '{"purchaseToken": "test"}'
```

### Notes

Following existing patterns from AuthModule and RulesGenerationModule.
Endpoint requires bearer token authentication.
Platform detection uses User-Agent parsing per research.md recommendations.
