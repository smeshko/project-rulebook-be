import Vapor

extension FeedbackError: DebuggableError {}
extension FeedbackError: CustomStringConvertible {}
extension FeedbackError: CustomDebugStringConvertible {}
extension FeedbackError: LocalizedError {}
extension FeedbackError: AppError {}

extension FeedbackError: AbortError {
    public var status: HTTPResponseStatus {
        switch self {
        case .gameTitleRequired:
            return .badRequest
        case .descriptionRequired:
            return .badRequest
        case .invalidFeedbackType:
            return .badRequest
        case .descriptionTooLong:
            return .badRequest
        case .gameTitleTooLong:
            return .badRequest
        case .feedbackNotFound:
            return .notFound
        case .invalidFeedbackStatus:
            return .badRequest
        }
    }
}
