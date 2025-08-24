import Testing
import VaporTesting
@testable import App

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

