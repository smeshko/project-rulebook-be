import Vapor

/// Controller handling purchase validation endpoints.
///
/// Provides REST endpoints for validating iOS and Android in-app purchases
/// and storing validated receipts for user entitlement tracking.
struct PurchasesController {

    // MARK: - Validate Purchase

    /// Validates a purchase receipt from iOS or Android.
    ///
    /// This endpoint:
    /// 1. Validates the request body format
    /// 2. Routes to the appropriate platform validator
    /// 3. Checks for duplicate transactions
    /// 4. Stores the validated receipt
    /// 5. Returns the validated transaction data
    ///
    /// - POST /api/v1/purchases/validate
    /// - Requires authentication
    /// - Body: `Purchases.Validate.Request`
    /// - Returns: `Purchases.Validate.Response`
    func validate(_ req: Request) async throws -> Purchases.Validate.Response {
        // 1. Extract authenticated user
        let user = try req.auth.require(UserAccountModel.self)
        let userId = try user.requireID()

        // 2. Parse and validate request body
        let input = try req.content.decode(Purchases.Validate.Request.self)

        // 3. Validate the receipt with the appropriate platform validator
        let transaction = try await req.services.purchaseValidator.validate(
            platform: input.platform,
            receiptData: input.receiptData,
            productId: input.productId
        )

        // 4. Check for duplicate transaction
        if try await req.repositories.receipts.exists(
            transactionId: transaction.transactionId,
            platform: transaction.platform
        ) {
            req.logger.info("Duplicate transaction detected", metadata: [
                "transactionId": .string(transaction.transactionId),
                "platform": .string(transaction.platform.rawValue)
            ])
            // Return success for duplicates (idempotent behavior)
            return Purchases.Validate.Response(
                success: true,
                transactionId: transaction.transactionId,
                productId: transaction.productId,
                status: transaction.status.rawValue,
                isDuplicate: true
            )
        }

        // 5. Store the validated receipt
        let receipt = ReceiptModel(from: transaction, userId: userId)
        try await req.repositories.receipts.create(receipt)

        req.logger.info("Purchase validated and stored", metadata: [
            "transactionId": .string(transaction.transactionId),
            "productId": .string(transaction.productId),
            "platform": .string(transaction.platform.rawValue),
            "userId": .string(userId.uuidString)
        ])

        // 6. Return response
        return Purchases.Validate.Response(
            success: true,
            transactionId: transaction.transactionId,
            productId: transaction.productId,
            status: transaction.status.rawValue,
            isDuplicate: false
        )
    }

    // MARK: - Get User Purchases

    /// Retrieves all purchases for the authenticated user.
    ///
    /// - GET /api/v1/purchases
    /// - Requires authentication
    /// - Returns: `Purchases.List.Response`
    func list(_ req: Request) async throws -> Purchases.List.Response {
        let user = try req.auth.require(UserAccountModel.self)
        let userId = try user.requireID()

        let receipts = try await req.repositories.receipts.findByUser(userId: userId)

        return Purchases.List.Response(
            purchases: receipts.map { receipt in
                Purchases.List.PurchaseItem(
                    id: receipt.id ?? UUID(),
                    transactionId: receipt.transactionId,
                    productId: receipt.productId,
                    platform: receipt.platform,
                    purchaseDate: receipt.purchaseDate,
                    expirationDate: receipt.expirationDate,
                    status: receipt.status
                )
            }
        )
    }

    // MARK: - Get Active Entitlements

    /// Retrieves active purchases/entitlements for the authenticated user.
    ///
    /// - GET /api/v1/purchases/active
    /// - Requires authentication
    /// - Returns: `Purchases.Active.Response`
    func active(_ req: Request) async throws -> Purchases.Active.Response {
        let user = try req.auth.require(UserAccountModel.self)
        let userId = try user.requireID()

        let activeReceipts = try await req.repositories.receipts.findActiveByUser(userId: userId)

        return Purchases.Active.Response(
            hasActiveSubscription: !activeReceipts.isEmpty,
            productIds: activeReceipts.map { $0.productId }
        )
    }
}
