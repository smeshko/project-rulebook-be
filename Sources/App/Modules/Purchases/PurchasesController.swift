import Vapor

/// Controller handling purchase validation endpoints.
///
/// Provides REST endpoints for validating iOS and Android in-app purchases
/// and storing validated receipts for device entitlement tracking.
/// Uses device ID for identification instead of user authentication.
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
    /// - Body: `Purchases.Validate.Request`
    /// - Returns: `Purchases.Validate.Response`
    func validate(_ req: Request) async throws -> Purchases.Validate.Response {
        // 1. Parse and validate request body
        let input = try req.content.decode(Purchases.Validate.Request.self)
        let deviceId = input.deviceId

        // 2. Validate the receipt with the appropriate platform validator
        let transaction = try await req.services.purchaseValidator.validate(
            platform: input.platform,
            receiptData: input.receiptData,
            productId: input.productId
        )

        // 3. Check for duplicate transaction
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

        // 4. Store the validated receipt
        let receipt = ReceiptModel(from: transaction, deviceId: deviceId)
        try await req.repositories.receipts.create(receipt)

        req.logger.info("Purchase validated and stored", metadata: [
            "transactionId": .string(transaction.transactionId),
            "productId": .string(transaction.productId),
            "platform": .string(transaction.platform.rawValue),
            "deviceId": .string(deviceId)
        ])

        // 5. Return response
        return Purchases.Validate.Response(
            success: true,
            transactionId: transaction.transactionId,
            productId: transaction.productId,
            status: transaction.status.rawValue,
            isDuplicate: false
        )
    }

    // MARK: - Get Device Purchases

    /// Retrieves all purchases for a device.
    ///
    /// - GET /api/v1/purchases/:deviceId
    /// - Returns: `Purchases.List.Response`
    func list(_ req: Request) async throws -> Purchases.List.Response {
        guard let deviceId = req.parameters.get("deviceId") else {
            throw Abort(.badRequest, reason: "Device ID is required")
        }

        let receipts = try await req.repositories.receipts.findByDevice(deviceId: deviceId)

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

    /// Retrieves active purchases/entitlements for a device.
    ///
    /// - GET /api/v1/purchases/:deviceId/active
    /// - Returns: `Purchases.Active.Response`
    func active(_ req: Request) async throws -> Purchases.Active.Response {
        guard let deviceId = req.parameters.get("deviceId") else {
            throw Abort(.badRequest, reason: "Device ID is required")
        }

        let activeReceipts = try await req.repositories.receipts.findActiveByDevice(deviceId: deviceId)

        return Purchases.Active.Response(
            hasActiveSubscription: !activeReceipts.isEmpty,
            productIds: activeReceipts.map { $0.productId }
        )
    }
}
