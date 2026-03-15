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
        // Compute expected hash using the same SHA256 utility
        let expectedHash = SHA256.hash("test-receipt-payload")

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

    @Test("Android receipt hash uses purchaseToken", .tags(.p1Core, .integration))
    func androidReceiptHashUsesPurchaseToken() async throws {
        let expectedHash = SHA256.hash("android-purchase-token-123")

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
