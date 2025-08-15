import Vapor
import JWT

private let accessTokenLifetime: Double = 15 * 60 // 15 minutes

extension TokenPayload: Authenticatable {
    init(with user: UserAccountModel) throws {
        self.init(
            userID: try user.requireID(),
            fullName: "\(user.firstName ?? "") \(user.lastName ?? "")",
            email: user.email,
            isAdmin: user.isAdmin,
            expiresAt: Date().addingTimeInterval(accessTokenLifetime)
        )
    }
}
