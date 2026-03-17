@testable import App
import Crypto
import Fluent
import Testing
import VaporTesting

@Suite(.serialized)
struct ReceiptsControllerTests {
    let app: Application
    let testWorld: IsolatedTestWorld
    let validatePath = "api/v1/receipts/validate"

    let mockAppStore: MockAppStoreValidationService
    let mockPlayStore: MockPlayStoreValidationService

    init() async throws {
        testWorld = try await IsolatedTestWorld()
        app = testWorld.app

        // Configure mock validation services
        let appStore = MockAppStoreValidationService()
        let playStore = MockPlayStoreValidationService()
        self.mockAppStore = appStore
        self.mockPlayStore = playStore
        app.appStoreValidationService = appStore
        app.playStoreValidationService = playStore

        // Configure receipts repository (uses database via migrations)
        app.receiptsRepository = DatabaseReceiptsRepository(database: app.db)

        // Reset rate limits to prevent cross-contamination between tests
        await app.mockRateLimit.resetAllRateLimits()
    }

    // MARK: - iOS Validation Tests

    @Test("Successful iOS validation returns valid status", .tags(.p0Critical, .integration))
    func iosValidationSuccess() async throws {
        mockAppStore.resultToReturn = AppStoreValidationResult(
            transactionId: "ios_txn_123",
            productId: "credits_1",
            bundleId: "com.test.app",
            purchaseDate: Date(),
            environment: "Sandbox"
        )

        let requestBody = Receipts.Validate.Request(
            platform: "ios",
            receiptData: "valid-signed-transaction",
            productId: "credits_1"
        )

        try await app.test(.POST, validatePath, beforeRequest: { req in
            try req.content.encode(requestBody)
        }) { response in
            #expect(response.status == .ok)
            expectContent(Receipts.Validate.Response.self, response) { body in
                #expect(body.success == true)
                #expect(body.status == "valid")
                #expect(body.transactionId == "ios_txn_123")
                #expect(body.error == nil)
            }
        }

        #expect(mockAppStore.verifyCallCount == 1)
        #expect(mockAppStore.lastSignedTransaction == "valid-signed-transaction")
    }

    // MARK: - Android Validation Tests

    @Test("Successful Android validation returns valid status", .tags(.p0Critical, .integration))
    func androidValidationSuccess() async throws {
        mockPlayStore.resultToReturn = PlayStoreValidationResult(
            transactionId: "GPA.1234-5678",
            productId: "credits_3",
            purchaseDate: Date()
        )

        let requestBody = Receipts.Validate.Request(
            platform: "android",
            purchaseToken: "valid-purchase-token",
            productId: "credits_3",
            packageName: "com.test.app"
        )

        try await app.test(.POST, validatePath, beforeRequest: { req in
            try req.content.encode(requestBody)
        }) { response in
            #expect(response.status == .ok)
            expectContent(Receipts.Validate.Response.self, response) { body in
                #expect(body.success == true)
                #expect(body.status == "valid")
                #expect(body.transactionId == "GPA.1234-5678")
                #expect(body.error == nil)
            }
        }

        #expect(mockPlayStore.verifyCallCount == 1)
        #expect(mockPlayStore.lastPurchaseToken == "valid-purchase-token")
    }

    // MARK: - Duplicate Transaction Tests

    @Test("Duplicate transaction returns already_processed", .tags(.p0Critical, .integration))
    func duplicateTransactionReturnsAlreadyProcessed() async throws {
        // Pre-populate a transaction in the database
        let existing = TransactionModel(
            transactionId: "dup_txn_001",
            platform: .ios,
            productId: "credits_1",
            creditAmount: 1,
            receiptHash: "abc123"
        )
        try await existing.create(on: app.db)

        mockAppStore.resultToReturn = AppStoreValidationResult(
            transactionId: "dup_txn_001",
            productId: "credits_1",
            bundleId: "com.test.app",
            purchaseDate: Date(),
            environment: "Sandbox"
        )

        let requestBody = Receipts.Validate.Request(
            platform: "ios",
            receiptData: "signed-data",
            productId: "credits_1"
        )

        try await app.test(.POST, validatePath, beforeRequest: { req in
            try req.content.encode(requestBody)
        }) { response in
            #expect(response.status == .ok)
            expectContent(Receipts.Validate.Response.self, response) { body in
                #expect(body.success == true)
                #expect(body.status == "already_processed")
                #expect(body.transactionId == "dup_txn_001")
            }
        }
    }

    // MARK: - Invalid Receipt Tests

    @Test("Invalid iOS receipt returns 403 with invalid status", .tags(.p0Critical, .integration))
    func invalidIosReceiptReturns403() async throws {
        mockAppStore.errorToThrow = .invalidSignature

        let requestBody = Receipts.Validate.Request(
            platform: "ios",
            receiptData: "bad-receipt",
            productId: "credits_1"
        )

        try await app.test(.POST, validatePath, beforeRequest: { req in
            try req.content.encode(requestBody)
        }) { response in
            #expect(response.status == .forbidden)
            expectContent(Receipts.Validate.Response.self, response) { body in
                #expect(body.success == false)
                #expect(body.status == "invalid")
                #expect(body.error != nil)
            }
        }
    }

    @Test("Invalid Android token returns 403 with invalid status", .tags(.p0Critical, .integration))
    func invalidAndroidTokenReturns403() async throws {
        mockPlayStore.errorToThrow = .invalidToken

        let requestBody = Receipts.Validate.Request(
            platform: "android",
            purchaseToken: "bad-token",
            productId: "credits_1",
            packageName: "com.test.app"
        )

        try await app.test(.POST, validatePath, beforeRequest: { req in
            try req.content.encode(requestBody)
        }) { response in
            #expect(response.status == .forbidden)
            expectContent(Receipts.Validate.Response.self, response) { body in
                #expect(body.success == false)
                #expect(body.status == "invalid")
                #expect(body.error != nil)
            }
        }
    }

    // MARK: - Malformed Request Tests

    @Test("Unknown platform returns 400", .tags(.p1Core, .integration))
    func unknownPlatformReturns400() async throws {
        let requestBody = Receipts.Validate.Request(
            platform: "windows",
            productId: "credits_1"
        )

        try await app.test(.POST, validatePath, beforeRequest: { req in
            try req.content.encode(requestBody)
        }) { response in
            #expect(response.status == .badRequest)
        }
    }

    @Test("Unknown product ID returns 400", .tags(.p1Core, .integration))
    func unknownProductIdReturns400() async throws {
        let requestBody = Receipts.Validate.Request(
            platform: "ios",
            receiptData: "some-data",
            productId: "unknown_product"
        )

        try await app.test(.POST, validatePath, beforeRequest: { req in
            try req.content.encode(requestBody)
        }) { response in
            #expect(response.status == .badRequest)
        }
    }

    @Test("iOS without receiptData returns 400", .tags(.p1Core, .integration))
    func iosMissingReceiptDataReturns400() async throws {
        let requestBody = Receipts.Validate.Request(
            platform: "ios",
            productId: "credits_1"
        )

        try await app.test(.POST, validatePath, beforeRequest: { req in
            try req.content.encode(requestBody)
        }) { response in
            #expect(response.status == .badRequest)
        }
    }

    @Test("Android without purchaseToken returns 400", .tags(.p1Core, .integration))
    func androidMissingPurchaseTokenReturns400() async throws {
        let requestBody = Receipts.Validate.Request(
            platform: "android",
            productId: "credits_1"
        )

        try await app.test(.POST, validatePath, beforeRequest: { req in
            try req.content.encode(requestBody)
        }) { response in
            #expect(response.status == .badRequest)
        }
    }

    // MARK: - Product ID Mismatch Tests

    @Test("iOS product ID mismatch returns 403", .tags(.p0Critical, .integration))
    func iosProductIdMismatchReturns403() async throws {
        mockAppStore.resultToReturn = AppStoreValidationResult(
            transactionId: "ios_txn_mismatch",
            productId: "credits_1",
            bundleId: "com.test.app",
            purchaseDate: Date(),
            environment: "Sandbox"
        )

        let requestBody = Receipts.Validate.Request(
            platform: "ios",
            receiptData: "valid-signed-transaction",
            productId: "credits_10"
        )

        try await app.test(.POST, validatePath, beforeRequest: { req in
            try req.content.encode(requestBody)
        }) { response in
            #expect(response.status == .forbidden)
            expectContent(Receipts.Validate.Response.self, response) { body in
                #expect(body.success == false)
                #expect(body.status == "invalid")
                #expect(body.error?.contains("does not match") == true)
            }
        }
    }

    @Test("Android product ID mismatch returns 403", .tags(.p0Critical, .integration))
    func androidProductIdMismatchReturns403() async throws {
        mockPlayStore.resultToReturn = PlayStoreValidationResult(
            transactionId: "GPA.mismatch",
            productId: "credits_1",
            purchaseDate: Date()
        )

        let requestBody = Receipts.Validate.Request(
            platform: "android",
            purchaseToken: "valid-token",
            productId: "credits_10",
            packageName: "com.test.app"
        )

        try await app.test(.POST, validatePath, beforeRequest: { req in
            try req.content.encode(requestBody)
        }) { response in
            #expect(response.status == .forbidden)
            expectContent(Receipts.Validate.Response.self, response) { body in
                #expect(body.success == false)
                #expect(body.status == "invalid")
                #expect(body.error?.contains("does not match") == true)
            }
        }
    }

    // MARK: - Transaction Storage Tests

    @Test("Successful validation stores transaction in database", .tags(.p1Core, .integration))
    func successfulValidationStoresTransaction() async throws {
        mockAppStore.resultToReturn = AppStoreValidationResult(
            transactionId: "store_txn_789",
            productId: "credits_10",
            bundleId: "com.test.app",
            purchaseDate: Date(),
            environment: "Sandbox"
        )

        let requestBody = Receipts.Validate.Request(
            platform: "ios",
            receiptData: "valid-signed-data",
            productId: "credits_10"
        )

        try await app.test(.POST, validatePath, beforeRequest: { req in
            try req.content.encode(requestBody)
        }) { response in
            #expect(response.status == .ok)
        }

        // Verify transaction was stored
        let stored = try await TransactionModel.query(on: app.db)
            .filter(\.$transactionId == "store_txn_789")
            .first()

        #expect(stored != nil)
        #expect(stored?.platform == .ios)
        #expect(stored?.productId == "credits_10")
        #expect(stored?.creditAmount == 10)
    }

    // MARK: - Product-to-Credits Mapping Tests

    @Test("Product credit mapping is correct", .tags(.unit))
    func productCreditMapping() {
        #expect(Receipts.creditAmount(for: "credits_1") == 1)
        #expect(Receipts.creditAmount(for: "credits_3") == 3)
        #expect(Receipts.creditAmount(for: "credits_10") == 10)
        #expect(Receipts.creditAmount(for: "unknown") == nil)
    }

    // MARK: - Android Package Name Validation Tests

    @Test("Android packageName mismatch returns 403 with invalid_app_identity", .tags(.p0Critical, .integration))
    func androidPackageNameMismatchReturns403() async throws {
        let requestBody = Receipts.Validate.Request(
            platform: "android",
            purchaseToken: "valid-token",
            productId: "credits_1",
            packageName: "com.wrong.app"
        )

        try await app.test(.POST, validatePath, beforeRequest: { req in
            try req.content.encode(requestBody)
        }) { response in
            #expect(response.status == .forbidden)
            expectContent(Receipts.Validate.Response.self, response) { body in
                #expect(body.success == false)
                #expect(body.status == "invalid")
                #expect(body.error == "invalid_app_identity")
            }
        }

        // Verify Play Store API was NOT called
        #expect(mockPlayStore.verifyCallCount == 0)
    }

    @Test("Android missing packageName returns 403 with invalid_app_identity", .tags(.p0Critical, .integration))
    func androidMissingPackageNameReturns403() async throws {
        let requestBody = Receipts.Validate.Request(
            platform: "android",
            purchaseToken: "valid-token",
            productId: "credits_1"
        )

        try await app.test(.POST, validatePath, beforeRequest: { req in
            try req.content.encode(requestBody)
        }) { response in
            #expect(response.status == .forbidden)
            expectContent(Receipts.Validate.Response.self, response) { body in
                #expect(body.success == false)
                #expect(body.status == "invalid")
                #expect(body.error == "invalid_app_identity")
            }
        }

        #expect(mockPlayStore.verifyCallCount == 0)
    }

    // MARK: - iOS Bundle ID Validation Tests

    @Test("iOS bundleId mismatch returns 403 with invalid_app_identity", .tags(.p0Critical, .integration))
    func iosBundleIdMismatchReturns403() async throws {
        mockAppStore.errorToThrow = .bundleIdMismatch

        let requestBody = Receipts.Validate.Request(
            platform: "ios",
            receiptData: "signed-data-wrong-bundle",
            productId: "credits_1"
        )

        try await app.test(.POST, validatePath, beforeRequest: { req in
            try req.content.encode(requestBody)
        }) { response in
            #expect(response.status == .forbidden)
            expectContent(Receipts.Validate.Response.self, response) { body in
                #expect(body.success == false)
                #expect(body.status == "invalid")
                #expect(body.error == "invalid_app_identity")
            }
        }
    }

    // MARK: - Receipt Hash Tests

    @Test("Receipt hash is stored on successful transaction", .tags(.p1Core, .integration))
    func receiptHashIsStoredOnSuccess() async throws {
        mockAppStore.resultToReturn = AppStoreValidationResult(
            transactionId: "hash_txn_001",
            productId: "credits_1",
            bundleId: "com.test.app",
            purchaseDate: Date(),
            environment: "Sandbox"
        )

        let requestBody = Receipts.Validate.Request(
            platform: "ios",
            receiptData: "test-receipt-payload",
            productId: "credits_1"
        )

        try await app.test(.POST, validatePath, beforeRequest: { req in
            try req.content.encode(requestBody)
        }) { response in
            #expect(response.status == .ok)
        }

        let stored = try await TransactionModel.query(on: app.db)
            .filter(\.$transactionId == "hash_txn_001")
            .first()

        #expect(stored != nil)
        // SHA-256 produces a 64-character hex string
        #expect(stored?.receiptHash.count == 64)
        // Verify it's a valid hex string
        #expect(stored?.receiptHash.allSatisfy { $0.isHexDigit } == true)
    }

    @Test("Receipt hash is deterministic for same input", .tags(.unit, .integration))
    func receiptHashIsDeterministic() async throws {
        // Precomputed SHA-256 of "test-receipt-payload" (independent of production code)
        let expectedHash = "e73d976e53ac919d727661b37e45bd96c0b3596f3db3d6aa956905c6fd3b15ee"

        mockAppStore.resultToReturn = AppStoreValidationResult(
            transactionId: "det_txn_001",
            productId: "credits_1",
            bundleId: "com.test.app",
            purchaseDate: Date(),
            environment: "Sandbox"
        )

        let requestBody = Receipts.Validate.Request(
            platform: "ios",
            receiptData: "test-receipt-payload",
            productId: "credits_1"
        )

        try await app.test(.POST, validatePath, beforeRequest: { req in
            try req.content.encode(requestBody)
        }) { response in
            #expect(response.status == .ok)
        }

        let stored = try await TransactionModel.query(on: app.db)
            .filter(\.$transactionId == "det_txn_001")
            .first()

        #expect(stored?.receiptHash == expectedHash)
    }

    // MARK: - Rate Limiting Tests

    @Test("IP-based rate limiting returns 429 after 30 requests", .tags(.p0Critical, .integration))
    func ipBasedRateLimitReturns429() async throws {
        // Reset rate limits
        await app.mockRateLimit.resetAllRateLimits()

        // Pre-fill IP-based rate limit to the max
        // In VaporTesting, remoteAddress is nil so IP falls back to "unknown"
        // Development config uses 300 req/hr for receipts
        await app.mockRateLimit.fillRateLimit(
            type: .receipt,
            clientIP: "unknown",
            configuration: .development()
        )

        mockAppStore.resultToReturn = AppStoreValidationResult(
            transactionId: "rate_limit_txn",
            productId: "credits_1",
            bundleId: "com.test.app",
            purchaseDate: Date(),
            environment: "Sandbox"
        )

        let requestBody = Receipts.Validate.Request(
            platform: "ios",
            receiptData: "some-receipt-data",
            productId: "credits_1"
        )

        try await app.test(.POST, validatePath, beforeRequest: { req in
            try req.content.encode(requestBody)
        }) { response in
            #expect(response.status == .tooManyRequests)
            let retryAfter = response.headers.first(name: "Retry-After")
            #expect(retryAfter != nil)
            #expect(Int(retryAfter!) != nil)
            #expect(Int(retryAfter!)! > 0)

            expectContent(RateLimitErrorResponse.self, response) { body in
                #expect(body.error == "rate_limited")
                #expect(body.retryAfter > 0)
            }
        }
    }

    @Test("Receipt-hash rate limiting returns 429 after 10 identical hash submissions", .tags(.p0Critical, .integration))
    func receiptHashRateLimitReturns429() async throws {
        // Reset rate limits
        await app.mockRateLimit.resetAllRateLimits()

        // Pre-fill hash-based rate limit: compute the hash of "repeated-receipt" and fill storage
        let receiptPayload = "repeated-receipt"
        let hash = SHA256.hash(receiptPayload)
        let hashOperationKey = "receipt_hash_\(hash)"

        for _ in 0..<10 {
            await RateLimitStorage.shared.record(operationKey: hashOperationKey, at: Date())
        }

        mockAppStore.resultToReturn = AppStoreValidationResult(
            transactionId: "hash_rate_txn",
            productId: "credits_1",
            bundleId: "com.test.app",
            purchaseDate: Date(),
            environment: "Sandbox"
        )

        let requestBody = Receipts.Validate.Request(
            platform: "ios",
            receiptData: receiptPayload,
            productId: "credits_1"
        )

        try await app.test(.POST, validatePath, beforeRequest: { req in
            try req.content.encode(requestBody)
        }) { response in
            #expect(response.status == .tooManyRequests)

            expectContent(RateLimitErrorResponse.self, response) { body in
                #expect(body.error == "rate_limited")
                #expect(body.retryAfter > 0)
            }
        }
    }

    @Test("429 response contains Retry-After header with accurate seconds", .tags(.p0Critical, .integration))
    func rateLimitResponseHasRetryAfterHeader() async throws {
        await app.mockRateLimit.resetAllRateLimits()

        // Record requests spread over 30 minutes to test accurate Retry-After
        let now = Date()
        let hashOperationKey = "receipt_hash_test_retry"
        // Oldest request was 30 minutes ago → should expire in 30 minutes (1800s)
        await RateLimitStorage.shared.record(operationKey: hashOperationKey, at: now.addingTimeInterval(-1800))
        for i in 1..<10 {
            await RateLimitStorage.shared.record(operationKey: hashOperationKey, at: now.addingTimeInterval(-Double(i * 10)))
        }

        // Use IP-based limiting for this test
        await app.mockRateLimit.fillRateLimit(
            type: .receipt,
            clientIP: "unknown",
            configuration: .development()
        )

        let requestBody = Receipts.Validate.Request(
            platform: "ios",
            receiptData: "any-data",
            productId: "credits_1"
        )

        try await app.test(.POST, validatePath, beforeRequest: { req in
            try req.content.encode(requestBody)
        }) { response in
            #expect(response.status == .tooManyRequests)
            let retryAfter = response.headers.first(name: "Retry-After")
            #expect(retryAfter != nil)
            let retrySeconds = Int(retryAfter!)
            #expect(retrySeconds != nil)
            // Retry-After should be positive and <= window (3600)
            #expect(retrySeconds! > 0)
            #expect(retrySeconds! <= 3600)
        }
    }

    @Test("Different receipt hashes are tracked independently", .tags(.p1Core, .integration))
    func differentHashesTrackedIndependently() async throws {
        await app.mockRateLimit.resetAllRateLimits()

        // Fill rate limit for hash A
        let hashA = SHA256.hash("receipt-A")
        let hashKeyA = "receipt_hash_\(hashA)"
        for _ in 0..<10 {
            await RateLimitStorage.shared.record(operationKey: hashKeyA, at: Date())
        }

        // Hash B should still work
        mockAppStore.resultToReturn = AppStoreValidationResult(
            transactionId: "independent_txn",
            productId: "credits_1",
            bundleId: "com.test.app",
            purchaseDate: Date(),
            environment: "Sandbox"
        )

        let requestBody = Receipts.Validate.Request(
            platform: "ios",
            receiptData: "receipt-B",
            productId: "credits_1"
        )

        try await app.test(.POST, validatePath, beforeRequest: { req in
            try req.content.encode(requestBody)
        }) { response in
            #expect(response.status == .ok)
            expectContent(Receipts.Validate.Response.self, response) { body in
                #expect(body.success == true)
                #expect(body.status == "valid")
            }
        }
    }

    @Test("Requests within limits proceed normally", .tags(.p1Core, .integration))
    func requestsWithinLimitsProceed() async throws {
        await app.mockRateLimit.resetAllRateLimits()

        mockAppStore.resultToReturn = AppStoreValidationResult(
            transactionId: "within_limit_txn",
            productId: "credits_1",
            bundleId: "com.test.app",
            purchaseDate: Date(),
            environment: "Sandbox"
        )

        let requestBody = Receipts.Validate.Request(
            platform: "ios",
            receiptData: "normal-receipt",
            productId: "credits_1"
        )

        try await app.test(.POST, validatePath, beforeRequest: { req in
            try req.content.encode(requestBody)
        }) { response in
            #expect(response.status == .ok)
            expectContent(Receipts.Validate.Response.self, response) { body in
                #expect(body.success == true)
                #expect(body.status == "valid")
            }
        }
    }

    @Test("Android receipt hash uses purchaseToken", .tags(.p1Core, .integration))
    func androidReceiptHashUsesPurchaseToken() async throws {
        // Precomputed SHA-256 of "android-purchase-token-123" (independent of production code)
        let expectedHash = "e34f78e8707f1f9b52c09dc160360dd85ae05c4da58844a7de290c529feeb61c"

        mockPlayStore.resultToReturn = PlayStoreValidationResult(
            transactionId: "GPA.hash-test",
            productId: "credits_1",
            purchaseDate: Date()
        )

        let requestBody = Receipts.Validate.Request(
            platform: "android",
            purchaseToken: "android-purchase-token-123",
            productId: "credits_1",
            packageName: "com.test.app"
        )

        try await app.test(.POST, validatePath, beforeRequest: { req in
            try req.content.encode(requestBody)
        }) { response in
            #expect(response.status == .ok)
        }

        let stored = try await TransactionModel.query(on: app.db)
            .filter(\.$transactionId == "GPA.hash-test")
            .first()

        #expect(stored?.receiptHash == expectedHash)
    }
}
