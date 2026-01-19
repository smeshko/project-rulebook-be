import Testing
import Vapor
import Fluent
import VaporTesting
@testable import App

// MARK: - Response Error Assertions

/// Swift Testing version of XCTAssertResponseError
///
/// Validates that an HTTP response contains the expected AppError with correct status and error details.
/// - Parameters:
///   - res: The HTTP response to validate
///   - error: The expected AppError
///   - sourceLocation: Source location for issue reporting
func expectResponseError(_ res: TestingHTTPResponse, _ error: AppError, sourceLocation: SourceLocation = #_sourceLocation) {
    #expect(res.status == error.status, "Response status should match error status", sourceLocation: sourceLocation)

    do {
        let errorContent = try res.content.decode(ErrorResponse.self)
        #expect(errorContent.errorIdentifier == error.identifier, "Error identifier should match", sourceLocation: sourceLocation)
        #expect(errorContent.reason == error.reason, "Error reason should match", sourceLocation: sourceLocation)
    } catch {
        Issue.record("Failed to decode error response: \(error)", sourceLocation: sourceLocation)
    }
}

/// Validates error response with specific status and identifier.
///
/// - Parameters:
///   - response: The HTTP response to validate.
///   - status: Expected HTTP status code.
///   - identifier: Expected error identifier string.
func expectError(
    _ response: TestingHTTPResponse,
    status: HTTPStatus,
    identifier: String,
    sourceLocation: SourceLocation = #_sourceLocation
) {
    #expect(
        response.status == status,
        "Expected status \(status.code) but got \(response.status.code)",
        sourceLocation: sourceLocation
    )

    do {
        let errorContent = try response.content.decode(ErrorResponse.self)
        #expect(
            errorContent.error == true,
            "Expected error field to be true",
            sourceLocation: sourceLocation
        )
        #expect(
            errorContent.errorIdentifier == identifier,
            "Expected error identifier '\(identifier)' but got '\(errorContent.errorIdentifier ?? "nil")'",
            sourceLocation: sourceLocation
        )
    } catch {
        Issue.record("Failed to decode error response: \(error)", sourceLocation: sourceLocation)
    }
}

// MARK: - Content Assertions

/// Swift Testing version of XCTAssertContent
///
/// Decodes response content and validates it using a closure.
/// - Parameters:
///   - type: The type to decode the response content to
///   - res: The HTTP response containing the content
///   - closure: Validation closure that receives the decoded content
///   - sourceLocation: Source location for issue reporting
func expectContent<T: Decodable>(
    _ type: T.Type,
    _ res: TestingHTTPResponse,
    _ closure: (T) throws -> Void,
    sourceLocation: SourceLocation = #_sourceLocation
) {
    do {
        let content = try res.content.decode(type)
        try closure(content)
    } catch {
        Issue.record("Failed to decode or validate content: \(error)", sourceLocation: sourceLocation)
    }
}

/// Validates HTTP response status and decodes content.
///
/// - Parameters:
///   - response: The HTTP response to validate.
///   - status: Expected HTTP status (default: .ok).
///   - type: The type to decode the response to.
///   - validate: Optional validation closure.
/// - Returns: The decoded content.
@discardableResult
func expectSuccess<T: Decodable>(
    _ response: TestingHTTPResponse,
    status: HTTPStatus = .ok,
    as type: T.Type,
    sourceLocation: SourceLocation = #_sourceLocation,
    validate: (T) throws -> Void = { _ in }
) throws -> T {
    #expect(
        response.status == status,
        "Expected status \(status.code) but got \(response.status.code)",
        sourceLocation: sourceLocation
    )

    let content = try response.content.decode(T.self)
    try validate(content)
    return content
}

// MARK: - Header Assertions

/// Validates response contains expected headers.
///
/// - Parameters:
///   - response: The HTTP response to validate.
///   - headers: Dictionary of expected header name-value pairs.
func expectHeaders(
    _ response: TestingHTTPResponse,
    contains headers: [String: String],
    sourceLocation: SourceLocation = #_sourceLocation
) {
    for (name, value) in headers {
        let actual = response.headers.first(name: name)
        #expect(
            actual == value,
            "Expected header '\(name): \(value)' but got '\(actual ?? "missing")'",
            sourceLocation: sourceLocation
        )
    }
}

/// Validates response has a specific header present.
func expectHeaderExists(
    _ response: TestingHTTPResponse,
    name: String,
    sourceLocation: SourceLocation = #_sourceLocation
) {
    let value = response.headers.first(name: name)
    #expect(
        value != nil,
        "Expected header '\(name)' to be present but it was missing",
        sourceLocation: sourceLocation
    )
}

// MARK: - Database Assertions

/// Validates entity exists in database.
///
/// - Parameters:
///   - type: The model type to query.
///   - id: The ID of the entity to find.
///   - database: The database to query.
/// - Returns: The found model.
@discardableResult
func expectExists<T: Model>(
    _ type: T.Type,
    id: T.IDValue,
    on database: Database,
    sourceLocation: SourceLocation = #_sourceLocation
) async throws -> T where T.IDValue: Equatable {
    let model = try await T.find(id, on: database)
    #expect(
        model != nil,
        "Expected \(T.self) with id \(id) to exist",
        sourceLocation: sourceLocation
    )
    return model!
}

/// Validates entity does NOT exist in database.
///
/// - Parameters:
///   - type: The model type to query.
///   - id: The ID of the entity that should not exist.
///   - database: The database to query.
func expectNotExists<T: Model>(
    _ type: T.Type,
    id: T.IDValue,
    on database: Database,
    sourceLocation: SourceLocation = #_sourceLocation
) async throws where T.IDValue: Equatable {
    let model = try await T.find(id, on: database)
    #expect(
        model == nil,
        "Expected \(T.self) with id \(id) to NOT exist but it was found",
        sourceLocation: sourceLocation
    )
}

/// Validates the count of entities in database.
///
/// - Parameters:
///   - type: The model type to count.
///   - expectedCount: The expected number of entities.
///   - database: The database to query.
func expectCount<T: Model>(
    _ type: T.Type,
    equals expectedCount: Int,
    on database: Database,
    sourceLocation: SourceLocation = #_sourceLocation
) async throws {
    let actualCount = try await T.query(on: database).count()
    #expect(
        actualCount == expectedCount,
        "Expected \(expectedCount) \(T.self) records but found \(actualCount)",
        sourceLocation: sourceLocation
    )
}

// MARK: - Timing Assertions

/// Validates operation completes within time limit.
///
/// - Parameters:
///   - seconds: Maximum allowed execution time.
///   - operation: The async operation to time.
/// - Returns: The operation result.
@discardableResult
func expectCompletes<T>(
    within seconds: Double,
    sourceLocation: SourceLocation = #_sourceLocation,
    operation: () async throws -> T
) async throws -> T {
    let start = ContinuousClock.now
    let result = try await operation()
    let elapsed = ContinuousClock.now - start

    #expect(
        elapsed < .seconds(seconds),
        "Operation took \(elapsed) but expected < \(seconds)s",
        sourceLocation: sourceLocation
    )

    return result
}

/// Validates operation takes at least a minimum time (useful for rate limiting tests).
///
/// - Parameters:
///   - seconds: Minimum expected execution time.
///   - operation: The async operation to time.
/// - Returns: The operation result.
@discardableResult
func expectTakesAtLeast<T>(
    _ seconds: Double,
    sourceLocation: SourceLocation = #_sourceLocation,
    operation: () async throws -> T
) async throws -> T {
    let start = ContinuousClock.now
    let result = try await operation()
    let elapsed = ContinuousClock.now - start

    #expect(
        elapsed >= .seconds(seconds),
        "Operation took \(elapsed) but expected >= \(seconds)s",
        sourceLocation: sourceLocation
    )

    return result
}

// MARK: - Collection Assertions

/// Validates array contains expected elements.
func expectContains<T: Equatable>(
    _ array: [T],
    elements: [T],
    sourceLocation: SourceLocation = #_sourceLocation
) {
    for element in elements {
        #expect(
            array.contains(element),
            "Expected array to contain \(element)",
            sourceLocation: sourceLocation
        )
    }
}

/// Validates array has expected count.
func expectCount<T>(
    _ array: [T],
    equals expectedCount: Int,
    sourceLocation: SourceLocation = #_sourceLocation
) {
    #expect(
        array.count == expectedCount,
        "Expected \(expectedCount) elements but found \(array.count)",
        sourceLocation: sourceLocation
    )
}

// MARK: - String Assertions

/// Validates string contains expected substring.
func expectContains(
    _ string: String,
    substring: String,
    sourceLocation: SourceLocation = #_sourceLocation
) {
    #expect(
        string.contains(substring),
        "Expected '\(string)' to contain '\(substring)'",
        sourceLocation: sourceLocation
    )
}

/// Validates string matches expected pattern.
func expectMatches(
    _ string: String,
    pattern: String,
    sourceLocation: SourceLocation = #_sourceLocation
) {
    let regex = try? NSRegularExpression(pattern: pattern)
    let range = NSRange(string.startIndex..., in: string)
    let match = regex?.firstMatch(in: string, range: range)

    #expect(
        match != nil,
        "Expected '\(string)' to match pattern '\(pattern)'",
        sourceLocation: sourceLocation
    )
}

