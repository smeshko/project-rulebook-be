import Foundation

public enum FeedbackError: String, IdentifiableError {
    case gameTitleRequired = "game_title_required"
    case descriptionRequired = "description_required"
    case invalidFeedbackType = "invalid_feedback_type"
    case descriptionTooLong = "description_too_long"
    case gameTitleTooLong = "game_title_too_long"

    public var identifier: String {
        rawValue
    }

    public var reason: String {
        switch self {
        case .gameTitleRequired:
            return "Game title is required"
        case .descriptionRequired:
            return "Description is required"
        case .invalidFeedbackType:
            return "Invalid feedback type. Valid types are: incorrect, incomplete, other"
        case .descriptionTooLong:
            return "Description must not exceed 5000 characters"
        case .gameTitleTooLong:
            return "Game title must not exceed 500 characters"
        }
    }
}
