import Testing
import XCTVapor
@testable import App

/// Swift Testing version of XCTAssertResponseError
/// 
/// Validates that an HTTP response contains the expected AppError with correct status and error details.
/// - Parameters:
///   - res: The HTTP response to validate
///   - error: The expected AppError
///   - sourceLocation: Source location for issue reporting
func expectResponseError(_ res: XCTHTTPResponse, _ error: AppError, sourceLocation: SourceLocation = #_sourceLocation) {
    #expect(res.status == error.status, "Response status should match error status", sourceLocation: sourceLocation)
    
    do {
        let errorContent = try res.content.decode(ErrorResponse.self)
        #expect(errorContent.errorIdentifier == error.identifier, "Error identifier should match", sourceLocation: sourceLocation)
        #expect(errorContent.reason == error.reason, "Error reason should match", sourceLocation: sourceLocation)
    } catch {
        Issue.record("Failed to decode error response: \(error)", sourceLocation: sourceLocation)
    }
}

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
    _ res: XCTHTTPResponse, 
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

/// Swift Testing version of XCTAssertNotNilAsync
/// 
/// Validates that an async expression returns a non-nil value.
/// - Parameters:
///   - expression: The async expression to evaluate
///   - sourceLocation: Source location for issue reporting
func expectNotNilAsync<T>(
    _ expression: @autoclosure () async throws -> T?, 
    sourceLocation: SourceLocation = #_sourceLocation
) async {
    do {
        let result = try await expression()
        #expect(result != nil, "Expression should not return nil", sourceLocation: sourceLocation)
    } catch {
        Issue.record("Expression threw error: \(error)", sourceLocation: sourceLocation)
    }
}

/// Swift Testing helper for validating that async operations complete successfully
/// 
/// Similar to XCTAssertNoThrow but for async operations.
/// - Parameters:
///   - expression: The async expression that should not throw
///   - sourceLocation: Source location for issue reporting
func expectNoThrowAsync<T>(
    _ expression: @autoclosure () async throws -> T,
    sourceLocation: SourceLocation = #_sourceLocation
) async {
    do {
        _ = try await expression()
    } catch {
        Issue.record("Expression should not throw but threw: \(error)", sourceLocation: sourceLocation)
    }
}

/// Swift Testing helper for validating that async operations throw expected errors
/// 
/// Similar to XCTAssertThrowsError but for async operations.
/// - Parameters:
///   - expression: The async expression that should throw
///   - sourceLocation: Source location for issue reporting
func expectThrowsAsync<T>(
    _ expression: @autoclosure () async throws -> T,
    sourceLocation: SourceLocation = #_sourceLocation
) async {
    do {
        _ = try await expression()
        Issue.record("Expression should throw but completed successfully", sourceLocation: sourceLocation)
    } catch {
        // Expected to throw - this is success
    }
}