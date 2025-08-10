import Foundation

enum OpenAIError: Error, LocalizedError {
    case authenticationFailed
    case rateLimitExceeded(retryAfter: TimeInterval?)
    case serverError(Int)
    case requestFailed(Error)
    case emptyResponse
    case invalidResponse(Error)
    case apiError(String)
    
    var errorDescription: String? {
        switch self {
        case .authenticationFailed:
            return "OpenAI authentication failed. Please check your API key."
        case .rateLimitExceeded(let retryAfter):
            if let delay = retryAfter {
                return "OpenAI rate limit exceeded. Retry after \(delay) seconds."
            } else {
                return "OpenAI rate limit exceeded. Please try again later."
            }
        case .serverError(let code):
            return "OpenAI server error (HTTP \(code)). Please try again later."
        case .requestFailed(let error):
            return "OpenAI request failed: \(error.localizedDescription)"
        case .emptyResponse:
            return "OpenAI returned an empty response."
        case .invalidResponse(let error):
            return "Invalid response from OpenAI: \(error.localizedDescription)"
        case .apiError(let message):
            return "OpenAI API error: \(message)"
        }
    }
}