import Crypto
import Fluent
import Vapor

struct ReceiptsController {

    private static let receiptHashRateLimit = 10
    private static let receiptHashRateWindow: TimeInterval = 3600

    func validate(_ req: Request) async throws -> Response {
        let validateRequest = try req.content.decode(Receipts.Validate.Request.self)

        // Validate product ID maps to a known credit amount
        guard let creditAmount = Receipts.creditAmount(for: validateRequest.productId) else {
            throw Abort(.badRequest, reason: "Unknown product ID '\(validateRequest.productId)'")
        }

        // Determine platform and validate
        let transactionId: String
        let platform: TransactionPlatform
        let receiptHash: String

        switch validateRequest.platform.lowercased() {
        case "ios":
            guard let receiptData = validateRequest.receiptData, !receiptData.isEmpty else {
                throw Abort(.badRequest, reason: "receiptData is required for iOS platform")
            }
            platform = .ios
            receiptHash = computeReceiptHash(receiptData)
            do {
                let result = try await req.services.appStoreValidation.verify(signedTransaction: receiptData)
                guard result.productId == validateRequest.productId else {
                    let body = Receipts.Validate.Response(
                        success: false,
                        status: "invalid",
                        error: "Product ID does not match the validated receipt"
                    )
                    return try await body.encodeResponse(status: .forbidden, for: req)
                }
                transactionId = result.transactionId
            } catch let validationError as AppStoreValidationError {
                let errorString: String
                if case .bundleIdMismatch = validationError {
                    errorString = "invalid_app_identity"
                } else {
                    errorString = "\(validationError)"
                }
                let body = Receipts.Validate.Response(
                    success: false,
                    status: "invalid",
                    error: errorString
                )
                return try await body.encodeResponse(status: .forbidden, for: req)
            }

        case "android":
            guard let purchaseToken = validateRequest.purchaseToken, !purchaseToken.isEmpty else {
                throw Abort(.badRequest, reason: "purchaseToken is required for Android platform")
            }
            platform = .android
            receiptHash = computeReceiptHash(purchaseToken)

            // Validate packageName matches configured app package name
            let googleConfig = try req.application.configuration.google
            guard validateRequest.packageName == googleConfig.packageName else {
                let body = Receipts.Validate.Response(
                    success: false,
                    status: "invalid",
                    error: "invalid_app_identity"
                )
                return try await body.encodeResponse(status: .forbidden, for: req)
            }

            do {
                let result = try await req.services.playStoreValidation.verify(
                    productId: validateRequest.productId,
                    purchaseToken: purchaseToken
                )
                guard result.productId == validateRequest.productId else {
                    let body = Receipts.Validate.Response(
                        success: false,
                        status: "invalid",
                        error: "Product ID does not match the validated receipt"
                    )
                    return try await body.encodeResponse(status: .forbidden, for: req)
                }
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

        // Receipt-hash-based rate limiting (secondary check, 10 req/hr per unique hash)
        let hashOperationKey = "receipt_hash_\(receiptHash)"
        let hashCutoffTime = Date().addingTimeInterval(-Self.receiptHashRateWindow)
        await RateLimitStorage.shared.cleanup(olderThan: hashCutoffTime)
        let hashRequestCount = await RateLimitStorage.shared.getCount(for: hashOperationKey, since: hashCutoffTime)

        if hashRequestCount >= Self.receiptHashRateLimit {
            let retryAfterSeconds: Int
            if let oldestTimestamp = await RateLimitStorage.shared.getOldestTimestamp(for: hashOperationKey, since: hashCutoffTime) {
                let expiresAt = oldestTimestamp.addingTimeInterval(Self.receiptHashRateWindow)
                retryAfterSeconds = max(1, Int(expiresAt.timeIntervalSince(Date()).rounded(.up)))
            } else {
                retryAfterSeconds = Int(Self.receiptHashRateWindow)
            }

            let responseBody = RateLimitErrorResponse(error: "rate_limited", retryAfter: retryAfterSeconds)
            let response = Response(status: .tooManyRequests)
            response.headers.add(name: "Content-Type", value: "application/json")
            response.headers.add(name: "Retry-After", value: "\(retryAfterSeconds)")
            response.body = try .init(data: JSONEncoder().encode(responseBody))
            return response
        }

        await RateLimitStorage.shared.record(operationKey: hashOperationKey, at: Date())

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
            creditAmount: creditAmount,
            receiptHash: receiptHash
        )
        try await req.repositories.receipts.create(transaction)

        let body = Receipts.Validate.Response(
            success: true,
            status: "valid",
            transactionId: transactionId
        )
        return try await body.encodeResponse(status: .ok, for: req)
    }

    // MARK: - Private

    private func computeReceiptHash(_ payload: String) -> String {
        SHA256.hash(payload)
    }
}
