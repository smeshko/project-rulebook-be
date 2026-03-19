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

        // Extract platform-specific payload and compute receipt hash before external validation
        let platform: TransactionPlatform
        let receiptHash: String
        let receiptPayload: String

        switch validateRequest.platform.lowercased() {
        case "ios":
            guard let receiptData = validateRequest.receiptData, !receiptData.isEmpty else {
                throw Abort(.badRequest, reason: "receiptData is required for iOS platform")
            }
            platform = .ios
            receiptPayload = receiptData
            receiptHash = computeReceiptHash(receiptData)

        case "android":
            guard let purchaseToken = validateRequest.purchaseToken, !purchaseToken.isEmpty else {
                throw Abort(.badRequest, reason: "purchaseToken is required for Android platform")
            }
            platform = .android
            receiptPayload = purchaseToken
            receiptHash = computeReceiptHash(purchaseToken)

        default:
            throw Abort(.badRequest, reason: "Unsupported platform '\(validateRequest.platform)'")
        }

        // Receipt-hash-based rate limiting (secondary check, 10 req/hr per unique hash)
        // Must happen BEFORE expensive external validation calls
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

        // Perform platform-specific external validation
        let transactionId: String

        switch platform {
        case .ios:
            do {
                let result = try await req.services.appStoreValidation.verify(signedTransaction: receiptPayload)
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
                switch validationError {
                case .configurationError:
                    throw validationError
                default:
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
            } catch {
                // Transient error (timeout, connection refused, etc.) — store as pending
                return try await storePendingValidation(
                    req: req,
                    platform: platform,
                    productId: validateRequest.productId,
                    creditAmount: creditAmount,
                    receiptHash: receiptHash,
                    receiptPayload: receiptPayload
                )
            }

        case .android:
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
                    purchaseToken: receiptPayload
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
                switch validationError {
                case .apiError(let code, _) where code >= 500:
                    // Transient upstream error — store as pending
                    return try await storePendingValidation(
                        req: req,
                        platform: platform,
                        productId: validateRequest.productId,
                        creditAmount: creditAmount,
                        receiptHash: receiptHash,
                        receiptPayload: receiptPayload
                    )
                case .configurationError:
                    throw validationError
                default:
                    let body = Receipts.Validate.Response(
                        success: false,
                        status: "invalid",
                        error: "\(validationError)"
                    )
                    return try await body.encodeResponse(status: .forbidden, for: req)
                }
            } catch {
                // Transient error (timeout, connection refused, etc.) — store as pending
                return try await storePendingValidation(
                    req: req,
                    platform: platform,
                    productId: validateRequest.productId,
                    creditAmount: creditAmount,
                    receiptHash: receiptHash,
                    receiptPayload: receiptPayload
                )
            }
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

    private func storePendingValidation(
        req: Request,
        platform: TransactionPlatform,
        productId: String,
        creditAmount: Int,
        receiptHash: String,
        receiptPayload: String
    ) async throws -> Response {
        // Check if any transaction with same receipt hash already exists (regardless of status)
        if let existing = try await req.repositories.receipts.findByReceiptHash(receiptHash: receiptHash) {
            if existing.status == .pendingValidation {
                // Idempotent: return existing pending transaction
                let body = Receipts.Validate.Response(
                    success: true,
                    status: "pending",
                    transactionId: existing.transactionId
                )
                return try await body.encodeResponse(status: .accepted, for: req)
            } else {
                // Already validated — return as already_processed
                let body = Receipts.Validate.Response(
                    success: true,
                    status: "already_processed",
                    transactionId: existing.transactionId
                )
                return try await body.encodeResponse(status: .ok, for: req)
            }
        }

        let tempTransactionId = UUID().uuidString
        let transaction = TransactionModel(
            transactionId: tempTransactionId,
            platform: platform,
            productId: productId,
            creditAmount: creditAmount,
            receiptHash: receiptHash,
            status: .pendingValidation,
            receiptData: receiptPayload
        )
        try await req.repositories.receipts.create(transaction)

        let body = Receipts.Validate.Response(
            success: true,
            status: "pending",
            transactionId: tempTransactionId
        )
        return try await body.encodeResponse(status: .accepted, for: req)
    }
}
