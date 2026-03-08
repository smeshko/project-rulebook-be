@testable import App
import Testing
import VaporTesting

@Suite(.serialized)
struct AppStoreValidationServiceTests {

    // MARK: - AppStoreValidationResult Tests

    @Test("Validation result captures all required fields", .tags(.unit))
    func validationResultFields() {
        let date = Date(timeIntervalSince1970: 1700000000)
        let result = AppStoreValidationResult(
            transactionId: "txn_123",
            productId: "com.app.credits.100",
            bundleId: "com.test.app",
            purchaseDate: date,
            environment: "Sandbox"
        )

        #expect(result.transactionId == "txn_123")
        #expect(result.productId == "com.app.credits.100")
        #expect(result.bundleId == "com.test.app")
        #expect(result.purchaseDate == date)
        #expect(result.environment == "Sandbox")
    }

    // MARK: - AppStoreValidationError Tests

    @Test("Error cases are equatable", .tags(.unit))
    func errorEquatable() {
        #expect(AppStoreValidationError.invalidSignature == AppStoreValidationError.invalidSignature)
        #expect(AppStoreValidationError.invalidCertificateChain == AppStoreValidationError.invalidCertificateChain)
        #expect(AppStoreValidationError.bundleIdMismatch == AppStoreValidationError.bundleIdMismatch)
        #expect(AppStoreValidationError.configurationError("a") == AppStoreValidationError.configurationError("a"))
        #expect(AppStoreValidationError.configurationError("a") != AppStoreValidationError.configurationError("b"))
        #expect(AppStoreValidationError.verificationFailed("x") == AppStoreValidationError.verificationFailed("x"))
        #expect(AppStoreValidationError.invalidSignature != AppStoreValidationError.bundleIdMismatch)
    }

    @Test("All error cases are distinct", .tags(.unit))
    func errorCasesDistinct() {
        let cases: [AppStoreValidationError] = [
            .invalidSignature,
            .invalidCertificateChain,
            .bundleIdMismatch,
            .configurationError("test"),
            .verificationFailed("test"),
        ]

        for i in 0..<cases.count {
            for j in (i + 1)..<cases.count {
                #expect(cases[i] != cases[j], "Expected \(cases[i]) != \(cases[j])")
            }
        }
    }

    @Test("Error conforms to Error protocol", .tags(.unit))
    func errorConformsToError() {
        let error: Error = AppStoreValidationError.invalidSignature
        #expect(error is AppStoreValidationError)
    }

    // MARK: - DefaultAppStoreValidationService Tests

    @Test("Service rejects invalid JWS with appropriate error", .tags(.unit))
    func rejectInvalidJWS() async throws {
        let app = try await Application.make(.testing)
        try app.initializeConfiguration()

        let service = DefaultAppStoreValidationService(app: app)

        do {
            _ = try await service.verify(signedTransaction: "not-a-valid-jws")
            Issue.record("Expected AppStoreValidationError to be thrown")
        } catch let error as AppStoreValidationError {
            switch error {
            case .invalidSignature, .invalidCertificateChain:
                break // Expected
            default:
                Issue.record("Expected invalidSignature or invalidCertificateChain, got \(error)")
            }
        }

        try await app.asyncShutdown()
    }

    @Test("Service rejects empty signed transaction", .tags(.unit))
    func rejectEmptyTransaction() async throws {
        let app = try await Application.make(.testing)
        try app.initializeConfiguration()

        let service = DefaultAppStoreValidationService(app: app)

        do {
            _ = try await service.verify(signedTransaction: "")
            Issue.record("Expected AppStoreValidationError to be thrown")
        } catch let error as AppStoreValidationError {
            switch error {
            case .invalidSignature, .invalidCertificateChain:
                break // Expected
            default:
                Issue.record("Expected invalidSignature or invalidCertificateChain, got \(error)")
            }
        }

        try await app.asyncShutdown()
    }

    @Test("Service rejects tampered JWS with three parts", .tags(.unit))
    func rejectTamperedJWS() async throws {
        let app = try await Application.make(.testing)
        try app.initializeConfiguration()

        let service = DefaultAppStoreValidationService(app: app)

        // A JWS has three base64url-encoded parts separated by dots
        let tamperedJWS = "eyJhbGciOiJFUzI1NiJ9.eyJ0ZXN0IjoidGVzdCJ9.invalid_signature"

        do {
            _ = try await service.verify(signedTransaction: tamperedJWS)
            Issue.record("Expected AppStoreValidationError to be thrown")
        } catch let error as AppStoreValidationError {
            switch error {
            case .invalidSignature, .invalidCertificateChain:
                break // Expected
            default:
                Issue.record("Expected invalidSignature or invalidCertificateChain, got \(error)")
            }
        }

        try await app.asyncShutdown()
    }

    // MARK: - Mock Service Tests (protocol testability)

    @Test("Mock service can return success result", .tags(.unit))
    func mockServiceSuccess() async throws {
        let mockService = MockAppStoreValidationService()
        let date = Date()
        mockService.resultToReturn = AppStoreValidationResult(
            transactionId: "mock_txn",
            productId: "com.app.product",
            bundleId: "com.test.app",
            purchaseDate: date,
            environment: "Sandbox"
        )

        let result = try await mockService.verify(signedTransaction: "any-signed-data")
        #expect(result.transactionId == "mock_txn")
        #expect(result.productId == "com.app.product")
        #expect(result.bundleId == "com.test.app")
        #expect(result.environment == "Sandbox")
        #expect(mockService.verifyCallCount == 1)
        #expect(mockService.lastSignedTransaction == "any-signed-data")
    }

    @Test("Mock service can throw invalidSignature error", .tags(.unit))
    func mockServiceInvalidSignature() async throws {
        let mockService = MockAppStoreValidationService()
        mockService.errorToThrow = .invalidSignature

        do {
            _ = try await mockService.verify(signedTransaction: "any")
            Issue.record("Expected error to be thrown")
        } catch let error as AppStoreValidationError {
            #expect(error == .invalidSignature)
        }
        #expect(mockService.verifyCallCount == 1)
    }

    @Test("Mock service can throw bundleIdMismatch error", .tags(.unit))
    func mockServiceBundleIdMismatch() async throws {
        let mockService = MockAppStoreValidationService()
        mockService.errorToThrow = .bundleIdMismatch

        do {
            _ = try await mockService.verify(signedTransaction: "signed-data")
            Issue.record("Expected error to be thrown")
        } catch let error as AppStoreValidationError {
            #expect(error == .bundleIdMismatch)
        }
    }

    @Test("Mock service tracks call count correctly", .tags(.unit))
    func mockServiceCallTracking() async throws {
        let mockService = MockAppStoreValidationService()
        mockService.resultToReturn = AppStoreValidationResult(
            transactionId: "t1", productId: "p1", bundleId: "b1",
            purchaseDate: Date(), environment: "Sandbox"
        )

        _ = try await mockService.verify(signedTransaction: "first")
        _ = try await mockService.verify(signedTransaction: "second")
        _ = try await mockService.verify(signedTransaction: "third")

        #expect(mockService.verifyCallCount == 3)
        #expect(mockService.lastSignedTransaction == "third")
    }

    @Test("Mock service reset clears state", .tags(.unit))
    func mockServiceReset() async throws {
        let mockService = MockAppStoreValidationService()
        mockService.resultToReturn = AppStoreValidationResult(
            transactionId: "t1", productId: "p1", bundleId: "b1",
            purchaseDate: Date(), environment: "Sandbox"
        )
        _ = try await mockService.verify(signedTransaction: "test")

        mockService.reset()

        #expect(mockService.verifyCallCount == 0)
        #expect(mockService.lastSignedTransaction == nil)
        #expect(mockService.resultToReturn == nil)
        #expect(mockService.errorToThrow == nil)
    }
}

// MARK: - Mock Implementation

/// Mock implementation of AppStoreValidationService for testing.
/// Demonstrates the protocol can be mocked for controller tests in later stories.
final class MockAppStoreValidationService: AppStoreValidationService, @unchecked Sendable {
    var resultToReturn: AppStoreValidationResult?
    var errorToThrow: AppStoreValidationError?
    var verifyCallCount = 0
    var lastSignedTransaction: String?

    func verify(signedTransaction: String) async throws -> AppStoreValidationResult {
        verifyCallCount += 1
        lastSignedTransaction = signedTransaction

        if let error = errorToThrow {
            throw error
        }

        guard let result = resultToReturn else {
            throw AppStoreValidationError.configurationError("Mock not configured")
        }

        return result
    }

    func reset() {
        resultToReturn = nil
        errorToThrow = nil
        verifyCallCount = 0
        lastSignedTransaction = nil
    }
}
