@testable import App
@preconcurrency import AppStoreServerLibrary
import Fluent
import Testing
import VaporTesting

@Suite(.serialized)
struct AppleNotificationsControllerTests {
    let app: Application
    let testWorld: IsolatedTestWorld
    let notificationPath = "api/v1/notifications/apple"

    let mockNotificationService: MockAppleNotificationService

    init() async throws {
        testWorld = try await IsolatedTestWorld()
        app = testWorld.app

        let notificationService = MockAppleNotificationService()
        self.mockNotificationService = notificationService
        app.appleNotificationService = notificationService

        app.receiptsRepository = DatabaseReceiptsRepository(database: app.db)
    }

    // MARK: - REFUND Notification Tests

    @Test("REFUND notification marks transaction as refunded", .tags(.p0Critical, .receipts, .integration))
    func refundNotificationMarksRefunded() async throws {
        // Create a transaction in the database
        let transaction = TransactionModel(
            transactionId: "orig_txn_100",
            platform: .ios,
            productId: "credits_1",
            creditAmount: 1,
            receiptHash: "abc123"
        )
        try await transaction.create(on: app.db)

        mockNotificationService.resultToReturn = AppleNotificationResult(
            notificationType: .refund,
            rawNotificationType: "REFUND",
            subtype: nil,
            originalTransactionId: "orig_txn_100"
        )

        let requestBody = AppleNotificationsController.AppleNotificationPayload(
            signedPayload: "valid-signed-payload"
        )

        try await app.test(.POST, notificationPath, beforeRequest: { req in
            try req.content.encode(requestBody)
        }) { response in
            #expect(response.status == .ok)
        }

        // Verify transaction status was updated
        let updated = try await TransactionModel.query(on: app.db)
            .filter(\.$transactionId == "orig_txn_100")
            .first()

        #expect(updated != nil)
        #expect(updated?.status == .refunded)
        #expect(updated?.refundedAt != nil)
    }

    // MARK: - REVOKE Notification Tests

    @Test("REVOKE notification marks transaction as revoked", .tags(.p0Critical, .receipts, .integration))
    func revokeNotificationMarksRevoked() async throws {
        let transaction = TransactionModel(
            transactionId: "orig_txn_200",
            platform: .ios,
            productId: "credits_3",
            creditAmount: 3,
            receiptHash: "def456"
        )
        try await transaction.create(on: app.db)

        mockNotificationService.resultToReturn = AppleNotificationResult(
            notificationType: .revoke,
            rawNotificationType: "REVOKE",
            subtype: nil,
            originalTransactionId: "orig_txn_200"
        )

        let requestBody = AppleNotificationsController.AppleNotificationPayload(
            signedPayload: "valid-signed-payload"
        )

        try await app.test(.POST, notificationPath, beforeRequest: { req in
            try req.content.encode(requestBody)
        }) { response in
            #expect(response.status == .ok)
        }

        let updated = try await TransactionModel.query(on: app.db)
            .filter(\.$transactionId == "orig_txn_200")
            .first()

        #expect(updated != nil)
        #expect(updated?.status == .revoked)
    }

    // MARK: - Unsupported Notification Tests

    @Test("Unsupported notification type returns 200 and logs", .tags(.p1Core, .receipts, .integration))
    func unsupportedNotificationReturns200() async throws {
        mockNotificationService.resultToReturn = AppleNotificationResult(
            notificationType: .consumptionRequest,
            rawNotificationType: "CONSUMPTION_REQUEST",
            subtype: nil,
            originalTransactionId: "orig_txn_300"
        )

        let requestBody = AppleNotificationsController.AppleNotificationPayload(
            signedPayload: "valid-signed-payload"
        )

        try await app.test(.POST, notificationPath, beforeRequest: { req in
            try req.content.encode(requestBody)
        }) { response in
            #expect(response.status == .ok)
        }
    }

    @Test("TEST notification type returns 200", .tags(.p1Core, .receipts, .integration))
    func testNotificationReturns200() async throws {
        mockNotificationService.resultToReturn = AppleNotificationResult(
            notificationType: .test,
            rawNotificationType: "TEST",
            subtype: nil,
            originalTransactionId: nil
        )

        let requestBody = AppleNotificationsController.AppleNotificationPayload(
            signedPayload: "test-payload"
        )

        try await app.test(.POST, notificationPath, beforeRequest: { req in
            try req.content.encode(requestBody)
        }) { response in
            #expect(response.status == .ok)
        }
    }

    // MARK: - Invalid JWS Tests

    @Test("Invalid JWS signature returns 200", .tags(.p0Critical, .receipts, .integration))
    func invalidJWSReturns200() async throws {
        mockNotificationService.errorToThrow = AppleNotificationError.invalidSignature

        let requestBody = AppleNotificationsController.AppleNotificationPayload(
            signedPayload: "invalid-jws-payload"
        )

        try await app.test(.POST, notificationPath, beforeRequest: { req in
            try req.content.encode(requestBody)
        }) { response in
            #expect(response.status == .ok)
        }
    }

    // MARK: - Unknown Transaction Tests

    @Test("REFUND for unknown transactionId returns 200", .tags(.p1Core, .receipts, .integration))
    func refundUnknownTransactionReturns200() async throws {
        mockNotificationService.resultToReturn = AppleNotificationResult(
            notificationType: .refund,
            rawNotificationType: "REFUND",
            subtype: nil,
            originalTransactionId: "nonexistent_txn_999"
        )

        let requestBody = AppleNotificationsController.AppleNotificationPayload(
            signedPayload: "valid-signed-payload"
        )

        try await app.test(.POST, notificationPath, beforeRequest: { req in
            try req.content.encode(requestBody)
        }) { response in
            #expect(response.status == .ok)
        }
    }

    // MARK: - Malformed Request Tests

    @Test("Malformed request body returns 200", .tags(.p1Core, .receipts, .integration))
    func malformedRequestReturns200() async throws {
        try await app.test(.POST, notificationPath, beforeRequest: { req in
            req.headers.contentType = .json
            req.body = .init(string: "{\"invalid\": \"body\"}")
        }) { response in
            #expect(response.status == .ok)
        }
    }

    @Test("Empty body returns 200", .tags(.p1Core, .receipts, .integration))
    func emptyBodyReturns200() async throws {
        try await app.test(.POST, notificationPath, beforeRequest: { req in
            req.headers.contentType = .json
            req.body = .init(string: "{}")
        }) { response in
            #expect(response.status == .ok)
        }
    }

    // MARK: - Missing Transaction ID Tests

    @Test("REFUND with missing originalTransactionId returns 200", .tags(.p1Core, .receipts, .integration))
    func refundMissingTransactionIdReturns200() async throws {
        mockNotificationService.resultToReturn = AppleNotificationResult(
            notificationType: .refund,
            rawNotificationType: "REFUND",
            subtype: nil,
            originalTransactionId: nil
        )

        let requestBody = AppleNotificationsController.AppleNotificationPayload(
            signedPayload: "valid-signed-payload"
        )

        try await app.test(.POST, notificationPath, beforeRequest: { req in
            try req.content.encode(requestBody)
        }) { response in
            #expect(response.status == .ok)
        }
    }

    // MARK: - Service Call Verification

    @Test("Controller passes signedPayload to notification service", .tags(.p1Core, .receipts, .integration))
    func controllerPassesPayloadToService() async throws {
        mockNotificationService.resultToReturn = AppleNotificationResult(
            notificationType: .test,
            rawNotificationType: "TEST",
            subtype: nil,
            originalTransactionId: nil
        )

        let requestBody = AppleNotificationsController.AppleNotificationPayload(
            signedPayload: "specific-payload-value"
        )

        try await app.test(.POST, notificationPath, beforeRequest: { req in
            try req.content.encode(requestBody)
        }) { response in
            #expect(response.status == .ok)
        }

        #expect(mockNotificationService.verifyCallCount == 1)
        #expect(mockNotificationService.lastSignedPayload == "specific-payload-value")
    }
}

// MARK: - Mock AppleNotificationService

final class MockAppleNotificationService: AppleNotificationService, @unchecked Sendable {
    var resultToReturn: AppleNotificationResult?
    var errorToThrow: AppleNotificationError?
    var verifyCallCount = 0
    var lastSignedPayload: String?

    func verifyAndDecode(signedPayload: String) async throws -> AppleNotificationResult {
        verifyCallCount += 1
        lastSignedPayload = signedPayload

        if let error = errorToThrow {
            throw error
        }

        guard let result = resultToReturn else {
            throw AppleNotificationError.configurationError("Mock not configured")
        }

        return result
    }

    func reset() {
        resultToReturn = nil
        errorToThrow = nil
        verifyCallCount = 0
        lastSignedPayload = nil
    }
}
