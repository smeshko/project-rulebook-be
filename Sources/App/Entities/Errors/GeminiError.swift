import Foundation

/// Error cases specific to the Google Gemini API integration.
enum GeminiError: Error {
    case authenticationFailed
    case rateLimitExceeded(retryAfter: TimeInterval?)
    case invalidRequest(String)
    case serverError(Int)
    case emptyResponse
    case invalidResponse(Error)
    case requestFailed(Error)
    case apiError(String)
}

