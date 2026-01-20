import Testing
import Vapor
import VaporTesting
@testable import App

// MARK: - API Schema Validator

/// Validates API responses against expected schema structures.
///
/// Use this to ensure API responses maintain consistent structure across changes,
/// catching contract-breaking changes early in the development cycle.
///
/// ## Usage
/// ```swift
/// @Test("Signup response matches schema", .tags(.contract, .auth))
/// func signupResponseSchema() async throws {
///     try await app.test(.POST, "/api/v1/auth/sign-up", beforeRequest: { req in
///         try req.content.encode(signupData)
///     }, afterResponse: { res async throws in
///         try APISchemaValidator.validateSuccess(res, as: Auth.SignUp.Response.self) { response in
///             #expect(response.user.id != nil)
///             #expect(!response.token.accessToken.isEmpty)
///         }
///     })
/// }
/// ```
enum APISchemaValidator {

    // MARK: - Success Response Validation

    /// Validates a successful response and decodes the content.
    ///
    /// - Parameters:
    ///   - response: The HTTP response to validate.
    ///   - type: The expected response type.
    ///   - expectedStatus: Expected HTTP status (default: .ok).
    ///   - validate: Optional closure to validate decoded content.
    /// - Returns: The decoded response content.
    /// - Throws: If decoding fails or status doesn't match.
    @discardableResult
    static func validateSuccess<T: Decodable>(
        _ response: TestingHTTPResponse,
        as type: T.Type,
        expectedStatus: HTTPStatus = .ok,
        sourceLocation: SourceLocation = #_sourceLocation,
        validate: ((T) throws -> Void)? = nil
    ) throws -> T {
        #expect(
            response.status == expectedStatus,
            "Expected status \(expectedStatus.code) but got \(response.status.code)",
            sourceLocation: sourceLocation
        )

        do {
            let content = try response.content.decode(T.self)
            try validate?(content)
            return content
        } catch let error as DecodingError {
            Issue.record(
                "Failed to decode response as \(T.self): \(describeDecodingError(error))",
                sourceLocation: sourceLocation
            )
            throw error
        }
    }

    /// Validates a created resource response (201).
    @discardableResult
    static func validateCreated<T: Decodable>(
        _ response: TestingHTTPResponse,
        as type: T.Type,
        sourceLocation: SourceLocation = #_sourceLocation,
        validate: ((T) throws -> Void)? = nil
    ) throws -> T {
        try validateSuccess(
            response,
            as: type,
            expectedStatus: .created,
            sourceLocation: sourceLocation,
            validate: validate
        )
    }

    /// Validates a no-content response (204).
    static func validateNoContent(
        _ response: TestingHTTPResponse,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        #expect(
            response.status == .noContent,
            "Expected status 204 but got \(response.status.code)",
            sourceLocation: sourceLocation
        )
    }

    // MARK: - Error Response Validation

    /// Validates an error response matches expected format.
    ///
    /// Ensures the error response follows the standard `ErrorResponse` structure
    /// with `error: true`, a reason message, and optional error identifier.
    ///
    /// - Parameters:
    ///   - response: The HTTP response to validate.
    ///   - expectedStatus: Expected HTTP error status.
    ///   - expectedIdentifier: Optional expected error identifier.
    ///   - reasonContains: Optional substring that should appear in reason.
    static func validateError(
        _ response: TestingHTTPResponse,
        expectedStatus: HTTPStatus,
        expectedIdentifier: String? = nil,
        reasonContains: String? = nil,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        #expect(
            response.status == expectedStatus,
            "Expected status \(expectedStatus.code) but got \(response.status.code)",
            sourceLocation: sourceLocation
        )

        do {
            let errorResponse = try response.content.decode(ErrorResponse.self)

            #expect(
                errorResponse.error == true,
                "Expected error field to be true",
                sourceLocation: sourceLocation
            )

            #expect(
                !errorResponse.reason.isEmpty,
                "Error reason should not be empty",
                sourceLocation: sourceLocation
            )

            if let expectedIdentifier {
                #expect(
                    errorResponse.errorIdentifier == expectedIdentifier,
                    "Expected error identifier '\(expectedIdentifier)' but got '\(errorResponse.errorIdentifier ?? "nil")'",
                    sourceLocation: sourceLocation
                )
            }

            if let reasonContains {
                #expect(
                    errorResponse.reason.localizedCaseInsensitiveContains(reasonContains),
                    "Expected reason to contain '\(reasonContains)' but got '\(errorResponse.reason)'",
                    sourceLocation: sourceLocation
                )
            }
        } catch {
            Issue.record(
                "Failed to decode error response: \(error)",
                sourceLocation: sourceLocation
            )
        }
    }

    /// Validates a bad request (400) error.
    static func validateBadRequest(
        _ response: TestingHTTPResponse,
        identifier: String? = nil,
        reasonContains: String? = nil,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        validateError(
            response,
            expectedStatus: .badRequest,
            expectedIdentifier: identifier,
            reasonContains: reasonContains,
            sourceLocation: sourceLocation
        )
    }

    /// Validates an unauthorized (401) error.
    static func validateUnauthorized(
        _ response: TestingHTTPResponse,
        identifier: String? = nil,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        validateError(
            response,
            expectedStatus: .unauthorized,
            expectedIdentifier: identifier,
            sourceLocation: sourceLocation
        )
    }

    /// Validates a forbidden (403) error.
    static func validateForbidden(
        _ response: TestingHTTPResponse,
        identifier: String? = nil,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        validateError(
            response,
            expectedStatus: .forbidden,
            expectedIdentifier: identifier,
            sourceLocation: sourceLocation
        )
    }

    /// Validates a not found (404) error.
    static func validateNotFound(
        _ response: TestingHTTPResponse,
        identifier: String? = nil,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        validateError(
            response,
            expectedStatus: .notFound,
            expectedIdentifier: identifier,
            sourceLocation: sourceLocation
        )
    }

    /// Validates a conflict (409) error.
    static func validateConflict(
        _ response: TestingHTTPResponse,
        identifier: String? = nil,
        reasonContains: String? = nil,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        validateError(
            response,
            expectedStatus: .conflict,
            expectedIdentifier: identifier,
            reasonContains: reasonContains,
            sourceLocation: sourceLocation
        )
    }

    /// Validates a rate limited (429) error.
    static func validateRateLimited(
        _ response: TestingHTTPResponse,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        validateError(
            response,
            expectedStatus: .tooManyRequests,
            sourceLocation: sourceLocation
        )

        // Rate limited responses should include Retry-After header
        let retryAfter = response.headers.first(name: "Retry-After")
        #expect(
            retryAfter != nil,
            "Rate limited response should include Retry-After header",
            sourceLocation: sourceLocation
        )
    }

    // MARK: - Header Validation

    /// Validates response contains expected headers.
    static func validateHeaders(
        _ response: TestingHTTPResponse,
        contains headers: [String: String],
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        for (name, expectedValue) in headers {
            let actualValue = response.headers.first(name: name)
            #expect(
                actualValue == expectedValue,
                "Expected header '\(name): \(expectedValue)' but got '\(actualValue ?? "missing")'",
                sourceLocation: sourceLocation
            )
        }
    }

    /// Validates response has JSON content type.
    static func validateJSONContentType(
        _ response: TestingHTTPResponse,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        let contentType = response.headers.first(name: .contentType)
        #expect(
            contentType?.contains("application/json") == true,
            "Expected JSON content type but got '\(contentType ?? "none")'",
            sourceLocation: sourceLocation
        )
    }

    // MARK: - List Response Validation

    /// Validates a list/array response.
    @discardableResult
    static func validateList<T: Decodable>(
        _ response: TestingHTTPResponse,
        of type: T.Type,
        expectedCount: Int? = nil,
        minCount: Int? = nil,
        maxCount: Int? = nil,
        sourceLocation: SourceLocation = #_sourceLocation,
        validate: (([T]) throws -> Void)? = nil
    ) throws -> [T] {
        #expect(
            response.status == .ok,
            "Expected status 200 but got \(response.status.code)",
            sourceLocation: sourceLocation
        )

        let items = try response.content.decode([T].self)

        if let expectedCount {
            #expect(
                items.count == expectedCount,
                "Expected \(expectedCount) items but got \(items.count)",
                sourceLocation: sourceLocation
            )
        }

        if let minCount {
            #expect(
                items.count >= minCount,
                "Expected at least \(minCount) items but got \(items.count)",
                sourceLocation: sourceLocation
            )
        }

        if let maxCount {
            #expect(
                items.count <= maxCount,
                "Expected at most \(maxCount) items but got \(items.count)",
                sourceLocation: sourceLocation
            )
        }

        try validate?(items)
        return items
    }

    // MARK: - Private Helpers

    private static func describeDecodingError(_ error: DecodingError) -> String {
        switch error {
        case .keyNotFound(let key, let context):
            return "Missing key '\(key.stringValue)' at path: \(context.codingPath.map(\.stringValue).joined(separator: "."))"
        case .typeMismatch(let type, let context):
            return "Type mismatch for \(type) at path: \(context.codingPath.map(\.stringValue).joined(separator: "."))"
        case .valueNotFound(let type, let context):
            return "Value not found for \(type) at path: \(context.codingPath.map(\.stringValue).joined(separator: "."))"
        case .dataCorrupted(let context):
            return "Data corrupted at path: \(context.codingPath.map(\.stringValue).joined(separator: "."))"
        @unknown default:
            return error.localizedDescription
        }
    }
}

// MARK: - AppError Validation Extension

extension APISchemaValidator {
    /// Validates response matches a specific AppError.
    ///
    /// Use this when you have a known AppError type and want to verify
    /// the response matches its expected status and identifier.
    static func validateAppError(
        _ response: TestingHTTPResponse,
        _ expectedError: AppError,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        validateError(
            response,
            expectedStatus: expectedError.status,
            expectedIdentifier: expectedError.identifier,
            sourceLocation: sourceLocation
        )
    }
}
