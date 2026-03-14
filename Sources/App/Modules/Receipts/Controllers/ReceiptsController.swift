import Fluent
import Vapor

struct ReceiptsController {

    func validate(_ req: Request) async throws -> Response {
        let validateRequest = try req.content.decode(Receipts.Validate.Request.self)

        // Validate product ID maps to a known credit amount
        guard let creditAmount = Receipts.creditAmount(for: validateRequest.productId) else {
            throw Abort(.badRequest, reason: "Unknown product ID '\(validateRequest.productId)'")
        }

        // Determine platform and validate
        let transactionId: String
        let platform: TransactionPlatform

        switch validateRequest.platform.lowercased() {
        case "ios":
            guard let receiptData = validateRequest.receiptData, !receiptData.isEmpty else {
                throw Abort(.badRequest, reason: "receiptData is required for iOS platform")
            }
            platform = .ios
            do {
                let result = try await req.services.appStoreValidation.verify(signedTransaction: receiptData)
                transactionId = result.transactionId
            } catch let validationError as AppStoreValidationError {
                let body = Receipts.Validate.Response(
                    success: false,
                    status: "invalid",
                    error: "\(validationError)"
                )
                return try await body.encodeResponse(status: .forbidden, for: req)
            }

        case "android":
            guard let purchaseToken = validateRequest.purchaseToken, !purchaseToken.isEmpty else {
                throw Abort(.badRequest, reason: "purchaseToken is required for Android platform")
            }
            platform = .android
            do {
                let result = try await req.services.playStoreValidation.verify(
                    productId: validateRequest.productId,
                    purchaseToken: purchaseToken
                )
                transactionId = result.transactionId
            } catch let validationError as PlayStoreValidationError {
                let body = Receipts.Validate.Response(
                    success: false,
                    status: "invalid",
                    error: "\(validationError)"
                )
                return try await body.encodeResponse(status: .forbidden, for: req)
            }

        default:
            throw Abort(.badRequest, reason: "Unsupported platform '\(validateRequest.platform)'")
        }

        // Check for duplicate transaction
        if let existing = try await req.repositories.receipts.find(transactionId: transactionId) {
            let body = Receipts.Validate.Response(
                success: true,
                status: "already_processed",
                transactionId: existing.transactionId
            )
            return try await body.encodeResponse(status: .ok, for: req)
        }

        // Store new transaction
        let transaction = TransactionModel(
            transactionId: transactionId,
            platform: platform,
            productId: validateRequest.productId,
            creditAmount: creditAmount
        )
        try await req.repositories.receipts.create(transaction)

        let body = Receipts.Validate.Response(
            success: true,
            status: "valid",
            transactionId: transactionId
        )
        return try await body.encodeResponse(status: .ok, for: req)
    }
}
