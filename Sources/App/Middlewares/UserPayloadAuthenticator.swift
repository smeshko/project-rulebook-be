import Vapor
import JWT

struct UserPayloadAuthenticator: JWTAuthenticator {
    typealias Payload = TokenPayload

    func authenticate(jwt: Payload, for request: Request) async throws {
        guard let user = try await request.repositories.users.find(id: jwt.userID) else {
            throw AuthenticationError.userNotAuthorized
        }
        request.auth.login(user)
    }
}
