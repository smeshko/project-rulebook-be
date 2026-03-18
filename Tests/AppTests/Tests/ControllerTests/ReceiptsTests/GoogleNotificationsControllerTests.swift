@testable import App
import Fluent
import Foundation
import Testing
import VaporTesting

@Suite(.serialized)
struct GoogleNotificationsControllerTests {
    let app: Application
    let testWorld: IsolatedTestWorld
    let notificationPath = "api/v1/notifications/google"

    let mockNotificationService: MockGoogleNotificationService

    /// The verification token configured in the testing environment.
    let verificationToken = "test_pubsub_token"

    init() async throws {
        testWorld = try await IsolatedTestWorld()
        app = testWorld.app

        let notificationService = MockGoogleNotificationService()
        self.mockNotificationService = notificationService
        app.googleNotificationService = notificationService

        app.receiptsRepository = DatabaseReceiptsRepository(database: app.db)
    }

    // MARK: - Helpers

    /// Builds a valid Pub/Sub push message body with base64-encoded data.
    private func makePubSubBody(base64Data: String = "eyJ2ZXJzaW9uIjoiMS4wIn0=") -> PubSubPushMessage {
        PubSubPushMessage(
            message: PubSubMessage(
                data: base64Data,
                messageId: "msg-123"
            ),
            subscription: "projects/test/subscriptions/test-sub"
        )
    }

    /// The notification path with a valid token query parameter.
    private var authenticatedPath: String {
        "\(notificationPath)?token=\(verificationToken)"
    }

    // MARK: - Refund Notification Tests

    @Test("Valid refund notification marks transaction as refunded", .tags(.p0Critical, .receipts, .integration))
    func refundNotificationMarksRefunded() async throws {
        let transaction = TransactionModel(
            transactionId: "GPA.1234-5678-9012",
            platform: .android,
            productId: "credits_1",
            creditAmount: 1,
            receiptHash: "google_hash_1"
        )
        try await transaction.create(on: app.db)

        mockNotificationService.decodeResultToReturn = GoogleNotificationResult(
            notificationType: .oneTimeProductRefunded,
            purchaseToken: "purchase_token_abc",
            productId: "credits_1",
            packageName: "com.test.app"
        )
        mockNotificationService.voidedOrderIdToReturn = "GPA.1234-5678-9012"

        let requestBody = makePubSubBody()

        try await app.test(.POST, authenticatedPath, beforeRequest: { req in
            try req.content.encode(requestBody)
        }) { response in
            #expect(response.status == .ok)
        }

        let updated = try await TransactionModel.query(on: app.db)
            .filter(\.$transactionId == "GPA.1234-5678-9012")
            .first()

        #expect(updated != nil)
        #expect(updated?.status == .refunded)
        #expect(updated?.refundedAt != nil)
    }

    // MARK: - Canceled Notification Tests

    @Test("Valid canceled notification marks transaction as refunded", .tags(.p0Critical, .receipts, .integration))
    func canceledNotificationMarksRefunded() async throws {
        let transaction = TransactionModel(
            transactionId: "GPA.9999-8888-7777",
            platform: .android,
            productId: "credits_3",
            creditAmount: 3,
            receiptHash: "google_hash_2"
        )
        try await transaction.create(on: app.db)

        mockNotificationService.decodeResultToReturn = GoogleNotificationResult(
            notificationType: .oneTimeProductCanceled,
            purchaseToken: "purchase_token_xyz",
            productId: "credits_3",
            packageName: "com.test.app"
        )
        mockNotificationService.voidedOrderIdToReturn = "GPA.9999-8888-7777"

        let requestBody = makePubSubBody()

        try await app.test(.POST, authenticatedPath, beforeRequest: { req in
            try req.content.encode(requestBody)
        }) { response in
            #expect(response.status == .ok)
        }

        let updated = try await TransactionModel.query(on: app.db)
            .filter(\.$transactionId == "GPA.9999-8888-7777")
            .first()

        #expect(updated != nil)
        #expect(updated?.status == .refunded)
        #expect(updated?.refundedAt != nil)
    }

    // MARK: - Token Verification Tests

    @Test("Invalid verification token returns 403", .tags(.p0Critical, .receipts, .integration))
    func invalidTokenReturns403() async throws {
        let requestBody = makePubSubBody()

        try await app.test(.POST, "\(notificationPath)?token=wrong_token", beforeRequest: { req in
            try req.content.encode(requestBody)
        }) { response in
            #expect(response.status == .forbidden)
        }
    }

    @Test("Missing verification token returns 403", .tags(.p0Critical, .receipts, .integration))
    func missingTokenReturns403() async throws {
        let requestBody = makePubSubBody()

        try await app.test(.POST, notificationPath, beforeRequest: { req in
            try req.content.encode(requestBody)
        }) { response in
            #expect(response.status == .forbidden)
        }
    }

    // MARK: - Unknown Notification Type Tests

    @Test("Unknown notification type returns 200 and logs", .tags(.p1Core, .receipts, .integration))
    func unknownNotificationReturns200() async throws {
        mockNotificationService.decodeResultToReturn = GoogleNotificationResult(
            notificationType: .oneTimeProductPurchased,
            purchaseToken: "purchase_token_def",
            productId: "credits_1",
            packageName: "com.test.app"
        )

        let requestBody = makePubSubBody()

        try await app.test(.POST, authenticatedPath, beforeRequest: { req in
            try req.content.encode(requestBody)
        }) { response in
            #expect(response.status == .ok)
        }
    }

    // MARK: - Unknown Transaction Tests

    @Test("Notification for unknown transactionId returns 200", .tags(.p1Core, .receipts, .integration))
    func unknownTransactionReturns200() async throws {
        mockNotificationService.decodeResultToReturn = GoogleNotificationResult(
            notificationType: .oneTimeProductRefunded,
            purchaseToken: "purchase_token_unknown",
            productId: "credits_1",
            packageName: "com.test.app"
        )
        mockNotificationService.voidedOrderIdToReturn = "GPA.0000-0000-0000"

        let requestBody = makePubSubBody()

        try await app.test(.POST, authenticatedPath, beforeRequest: { req in
            try req.content.encode(requestBody)
        }) { response in
            #expect(response.status == .ok)
        }
    }

    // MARK: - Malformed Request Tests

    @Test("Malformed Pub/Sub message returns 200", .tags(.p1Core, .receipts, .integration))
    func malformedMessageReturns200() async throws {
        try await app.test(.POST, authenticatedPath, beforeRequest: { req in
            req.headers.contentType = .json
            req.body = .init(string: "{\"invalid\": \"body\"}")
        }) { response in
            #expect(response.status == .ok)
        }
    }

    @Test("Empty body returns 200", .tags(.p1Core, .receipts, .integration))
    func emptyBodyReturns200() async throws {
        try await app.test(.POST, authenticatedPath, beforeRequest: { req in
            req.headers.contentType = .json
            req.body = .init(string: "{}")
        }) { response in
            #expect(response.status == .ok)
        }
    }

    // MARK: - Service Call Verification

    @Test("Controller passes base64 data to notification service", .tags(.p1Core, .receipts, .integration))
    func controllerPassesDataToService() async throws {
        mockNotificationService.decodeResultToReturn = GoogleNotificationResult(
            notificationType: .unknown(0),
            purchaseToken: nil,
            productId: nil,
            packageName: "com.test.app"
        )

        let requestBody = makePubSubBody(base64Data: "c3BlY2lmaWNfZGF0YQ==")

        try await app.test(.POST, authenticatedPath, beforeRequest: { req in
            try req.content.encode(requestBody)
        }) { response in
            #expect(response.status == .ok)
        }

        #expect(mockNotificationService.decodeCallCount == 1)
        #expect(mockNotificationService.lastBase64Message == "c3BlY2lmaWNfZGF0YQ==")
    }

    // MARK: - Voided Purchase Verification Failure Tests

    @Test("Voided purchase API failure returns 200", .tags(.p1Core, .receipts, .integration))
    func voidedPurchaseAPIFailureReturns200() async throws {
        mockNotificationService.decodeResultToReturn = GoogleNotificationResult(
            notificationType: .oneTimeProductRefunded,
            purchaseToken: "purchase_token_fail",
            productId: "credits_1",
            packageName: "com.test.app"
        )
        mockNotificationService.verifyErrorToThrow = GoogleNotificationError.voidedPurchaseVerificationFailed(
            "API error"
        )

        let requestBody = makePubSubBody()

        try await app.test(.POST, authenticatedPath, beforeRequest: { req in
            try req.content.encode(requestBody)
        }) { response in
            #expect(response.status == .ok)
        }
    }

    @Test("Voided purchase not found in API returns 200", .tags(.p1Core, .receipts, .integration))
    func voidedPurchaseNotFoundReturns200() async throws {
        mockNotificationService.decodeResultToReturn = GoogleNotificationResult(
            notificationType: .oneTimeProductCanceled,
            purchaseToken: "purchase_token_notfound",
            productId: "credits_1",
            packageName: "com.test.app"
        )
        mockNotificationService.voidedOrderIdToReturn = nil

        let requestBody = makePubSubBody()

        try await app.test(.POST, authenticatedPath, beforeRequest: { req in
            try req.content.encode(requestBody)
        }) { response in
            #expect(response.status == .ok)
        }
    }
}

// MARK: - Mock GoogleNotificationService

final class MockGoogleNotificationService: GoogleNotificationService, @unchecked Sendable {
    var decodeResultToReturn: GoogleNotificationResult?
    var decodeErrorToThrow: GoogleNotificationError?
    var voidedOrderIdToReturn: String?
    var verifyErrorToThrow: GoogleNotificationError?
    var decodeCallCount = 0
    var verifyCallCount = 0
    var lastBase64Message: String?
    var lastPurchaseToken: String?

    func decodeNotification(base64Message: String) throws -> GoogleNotificationResult {
        decodeCallCount += 1
        lastBase64Message = base64Message

        if let error = decodeErrorToThrow {
            throw error
        }

        guard let result = decodeResultToReturn else {
            throw GoogleNotificationError.configurationError("Mock not configured")
        }

        return result
    }

    func verifyVoidedPurchase(purchaseToken: String) async throws -> String? {
        verifyCallCount += 1
        lastPurchaseToken = purchaseToken

        if let error = verifyErrorToThrow {
            throw error
        }

        return voidedOrderIdToReturn
    }

    func reset() {
        decodeResultToReturn = nil
        decodeErrorToThrow = nil
        voidedOrderIdToReturn = nil
        verifyErrorToThrow = nil
        decodeCallCount = 0
        verifyCallCount = 0
        lastBase64Message = nil
        lastPurchaseToken = nil
    }
}
