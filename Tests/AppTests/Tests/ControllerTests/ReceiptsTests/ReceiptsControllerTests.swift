@testable import App
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
            productId: "credits_3"
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
            creditAmount: 1
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
}
