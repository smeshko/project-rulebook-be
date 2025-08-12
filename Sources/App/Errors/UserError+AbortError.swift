import Vapor

extension UserError: DebuggableError {}
extension UserError: CustomStringConvertible {}
extension UserError: CustomDebugStringConvertible {}
extension UserError: LocalizedError {}
extension UserError: AppError {}

extension UserError: AbortError {
    public var status: HTTPResponseStatus {
        switch self {
        case .userNotFound: .notFound
        case .userAlreadyFollowsUser: .badRequest
        case .userNotFollowingUser: .badRequest
        case .insufficientPermissions: .forbidden
        }
    }
}
