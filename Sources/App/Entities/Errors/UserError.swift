import Foundation

public enum UserError: String, IdentifiableError {
    case userNotFound = "user_not_found"
    case userAlreadyFollowsUser = "user_already_follows"
    case userNotFollowingUser = "user_not_following_user"

    public var identifier: String {
        rawValue
    }
    
    public var reason: String {
        switch self {
        case .userNotFound:
            return "User was not found"
        case .userAlreadyFollowsUser:
            return "User already following other user"
        case .userNotFollowingUser:
            return "User not following other user"
        }
    }
}
