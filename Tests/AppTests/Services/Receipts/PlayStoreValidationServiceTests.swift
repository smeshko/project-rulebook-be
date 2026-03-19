@testable import App
import Testing
import VaporTesting

@Suite(.serialized)
struct PlayStoreValidationServiceTests {

    // MARK: - PlayStoreValidationResult Tests

    @Test("Validation result captures all required fields", .tags(.unit))
    func validationResultFields() {
        let date = Date(timeIntervalSince1970: 1700000000)
        let result = PlayStoreValidationResult(
            transactionId: "GPA.1234-5678-9012-34567",
            productId: "com.app.credits.100",
            purchaseDate: date
        )

        #expect(result.transactionId == "GPA.1234-5678-9012-34567")
        #expect(result.productId == "com.app.credits.100")
        #expect(result.purchaseDate == date)
    }

    // MARK: - PlayStoreValidationError Tests

    @Test("Error cases are equatable", .tags(.unit))
    func errorEquatable() {
        #expect(PlayStoreValidationError.invalidToken == PlayStoreValidationError.invalidToken)
        #expect(PlayStoreValidationError.purchaseNotFound == PlayStoreValidationError.purchaseNotFound)
        #expect(PlayStoreValidationError.configurationError("a") == PlayStoreValidationError.configurationError("a"))
        #expect(PlayStoreValidationError.configurationError("a") != PlayStoreValidationError.configurationError("b"))
        #expect(PlayStoreValidationError.verificationFailed("x") == PlayStoreValidationError.verificationFailed("x"))
        #expect(PlayStoreValidationError.apiError(500, "err") == PlayStoreValidationError.apiError(500, "err"))
        #expect(PlayStoreValidationError.apiError(500, "a") != PlayStoreValidationError.apiError(500, "b"))
        #expect(PlayStoreValidationError.invalidToken != PlayStoreValidationError.purchaseNotFound)
    }

    @Test("All error cases are distinct", .tags(.unit))
    func errorCasesDistinct() {
        let cases: [PlayStoreValidationError] = [
            .invalidToken,
            .purchaseNotFound,
            .configurationError("test"),
            .verificationFailed("test"),
            .apiError(500, "test"),
        ]

        for i in 0..<cases.count {
            for j in (i + 1)..<cases.count {
                #expect(cases[i] != cases[j], "Expected \(cases[i]) != \(cases[j])")
            }
        }
    }

    @Test("Error conforms to Error protocol", .tags(.unit))
    func errorConformsToError() {
        let error: Error = PlayStoreValidationError.invalidToken
        #expect(error is PlayStoreValidationError)
    }

    // MARK: - DefaultPlayStoreValidationService Tests

    @Test("Service rejects empty purchase token", .tags(.unit))
    func rejectEmptyToken() async throws {
        let app = try await Application.make(.testing)
        try app.initializeConfiguration()

        let service = DefaultPlayStoreValidationService(app: app)

        do {
            _ = try await service.verify(productId: "com.app.product", purchaseToken: "")
            Issue.record("Expected PlayStoreValidationError to be thrown")
        } catch let error as PlayStoreValidationError {
            #expect(error == .invalidToken)
        }

        try await app.asyncShutdown()
    }

    @Test("Service rejects empty product ID", .tags(.unit))
    func rejectEmptyProductId() async throws {
        let app = try await Application.make(.testing)
        try app.initializeConfiguration()

        let service = DefaultPlayStoreValidationService(app: app)

        do {
            _ = try await service.verify(productId: "", purchaseToken: "some-token")
            Issue.record("Expected PlayStoreValidationError to be thrown")
        } catch let error as PlayStoreValidationError {
            #expect(error == .verificationFailed("Product ID cannot be empty"))
        }

        try await app.asyncShutdown()
    }

    // MARK: - Mock Service Tests (protocol testability)

    @Test("Mock service can return success result", .tags(.unit))
    func mockServiceSuccess() async throws {
        let mockService = MockPlayStoreValidationService()
        let date = Date()
        mockService.resultToReturn = PlayStoreValidationResult(
            transactionId: "GPA.1234-5678",
            productId: "com.app.product",
            purchaseDate: date
        )

        let result = try await mockService.verify(productId: "com.app.product", purchaseToken: "test-token")
        #expect(result.transactionId == "GPA.1234-5678")
        #expect(result.productId == "com.app.product")
        #expect(result.purchaseDate == date)
        #expect(mockService.verifyCallCount == 1)
        #expect(mockService.lastProductId == "com.app.product")
        #expect(mockService.lastPurchaseToken == "test-token")
    }

    @Test("Mock service can throw invalidToken error", .tags(.unit))
    func mockServiceInvalidToken() async throws {
        let mockService = MockPlayStoreValidationService()
        mockService.errorToThrow = .invalidToken

        do {
            _ = try await mockService.verify(productId: "any", purchaseToken: "any")
            Issue.record("Expected error to be thrown")
        } catch let error as PlayStoreValidationError {
            #expect(error == .invalidToken)
        }
        #expect(mockService.verifyCallCount == 1)
    }

    @Test("Mock service can throw purchaseNotFound error", .tags(.unit))
    func mockServicePurchaseNotFound() async throws {
        let mockService = MockPlayStoreValidationService()
        mockService.errorToThrow = .purchaseNotFound

        do {
            _ = try await mockService.verify(productId: "prod", purchaseToken: "token")
            Issue.record("Expected error to be thrown")
        } catch let error as PlayStoreValidationError {
            #expect(error == .purchaseNotFound)
        }
    }

    @Test("Mock service tracks call count correctly", .tags(.unit))
    func mockServiceCallTracking() async throws {
        let mockService = MockPlayStoreValidationService()
        mockService.resultToReturn = PlayStoreValidationResult(
            transactionId: "t1", productId: "p1", purchaseDate: Date()
        )

        _ = try await mockService.verify(productId: "p1", purchaseToken: "first")
        _ = try await mockService.verify(productId: "p2", purchaseToken: "second")
        _ = try await mockService.verify(productId: "p3", purchaseToken: "third")

        #expect(mockService.verifyCallCount == 3)
        #expect(mockService.lastProductId == "p3")
        #expect(mockService.lastPurchaseToken == "third")
    }

    @Test("Mock service reset clears state", .tags(.unit))
    func mockServiceReset() async throws {
        let mockService = MockPlayStoreValidationService()
        mockService.resultToReturn = PlayStoreValidationResult(
            transactionId: "t1", productId: "p1", purchaseDate: Date()
        )
        _ = try await mockService.verify(productId: "p1", purchaseToken: "test")

        mockService.reset()

        #expect(mockService.verifyCallCount == 0)
        #expect(mockService.lastProductId == nil)
        #expect(mockService.lastPurchaseToken == nil)
        #expect(mockService.resultToReturn == nil)
        #expect(mockService.errorToThrow == nil)
    }

    // MARK: - GooglePlayConfig Tests

    @Test("GooglePlayConfig captures all fields", .tags(.unit))
    func googlePlayConfigFields() {
        let config = GooglePlayConfig(
            serviceAccountEmail: "test@project.iam.gserviceaccount.com",
            privateKey: "-----BEGIN RSA PRIVATE KEY-----\ntest\n-----END RSA PRIVATE KEY-----",
            packageName: "com.example.app",
            pubsubVerificationToken: "test_verification_token"
        )

        #expect(config.serviceAccountEmail == "test@project.iam.gserviceaccount.com")
        #expect(config.privateKey.contains("RSA PRIVATE KEY"))
        #expect(config.packageName == "com.example.app")
        #expect(config.pubsubVerificationToken == "test_verification_token")
    }

    @Test("Testing configuration provides Google Play config", .tags(.unit))
    func testingConfigProvidesGoogleConfig() throws {
        let config = TestingConfiguration()
        let google = try config.google
        #expect(!google.serviceAccountEmail.isEmpty)
        #expect(!google.privateKey.isEmpty)
        #expect(!google.packageName.isEmpty)
    }
}

// MARK: - Mock Implementation

/// Mock implementation of PlayStoreValidationService for testing.
/// Demonstrates the protocol can be mocked for controller tests in later stories.
final class MockPlayStoreValidationService: PlayStoreValidationService, @unchecked Sendable {
    var resultToReturn: PlayStoreValidationResult?
    var errorToThrow: PlayStoreValidationError?
    var genericErrorToThrow: (any Error)?
    var verifyCallCount = 0
    var lastProductId: String?
    var lastPurchaseToken: String?

    func verify(productId: String, purchaseToken: String) async throws -> PlayStoreValidationResult {
        verifyCallCount += 1
        lastProductId = productId
        lastPurchaseToken = purchaseToken

        if let error = genericErrorToThrow {
            throw error
        }

        if let error = errorToThrow {
            throw error
        }

        guard let result = resultToReturn else {
            throw PlayStoreValidationError.configurationError("Mock not configured")
        }

        return result
    }

    func reset() {
        resultToReturn = nil
        errorToThrow = nil
        genericErrorToThrow = nil
        verifyCallCount = 0
        lastProductId = nil
        lastPurchaseToken = nil
    }
}
