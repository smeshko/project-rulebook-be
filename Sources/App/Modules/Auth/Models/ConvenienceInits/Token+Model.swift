import Vapor

extension Auth.TokenRefresh.Response: Content {
    init(
        token: String,
        user: UserAccountModel,
        on req: Request
    ) async throws {
        self.init(
            refreshToken: token,
            accessToken: try await req.jwt.sign(TokenPayload(with: user))
        )
    }
}
