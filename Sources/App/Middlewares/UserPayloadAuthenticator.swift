import Vapor
import JWT

struct UserPayloadAuthenticator: AsyncJWTAuthenticator {
    typealias Payload = TokenPayload
    
    func authenticate(jwt: Payload, for request: Request) async throws {
        do {
            let payload = try request.jwt.verify(as: Payload.self)
            guard let user = try await request.repositories.users.find(id: payload.userID) else {
                throw AuthenticationError.userNotAuthorized
            }

            request.auth.login(user)
        } catch {
            throw AuthenticationError.accessTokenHasExpired
        }
    }
}
