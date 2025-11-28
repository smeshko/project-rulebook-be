import Vapor
import VaporToOpenAPI

struct AuthRouter: RouteCollection {
    let controller = AuthController()

    func boot(routes: RoutesBuilder) throws {
        let api = routes
            .grouped("api")
            .grouped("auth")
            .groupedOpenAPI(tags: .init(name: "Auth", description: "User authentication and account management"))

        api
            .grouped(UserCredentialsAuthenticator())
            .post("sign-in", use: controller.signIn)
            .openAPI(description: "Authenticate user with email and password. Returns JWT access token and refresh token for subsequent API requests.")

        api
            .post("sign-up", use: controller.signUp)
            .openAPI(description: "Create new user account with email and password. Sends email verification link and returns JWT tokens.")

        api
            .post("apple-auth", use: controller.authWithApple)
            .openAPI(description: "Authenticate or create account using Apple Sign In. Returns JWT tokens for the associated user account.")

        api
            .post("refresh", use: controller.refreshAccessToken)
            .openAPI(description: "Exchange refresh token for new access token. Use when access token expires to maintain authenticated session.")

        api
            .post("reset-password", use: controller.resetPassword)
            .openAPI(description: "Request password reset email. Sends recovery link to user's email address if account exists.")

        api
            .grouped(UserAccountModel.guard())
            .post("logout", use: controller.logout)
            .openAPI(
                description: "Invalidate current refresh token and end authenticated session. Requires valid JWT access token.",
                auth: .bearer(id: "bearerAuth")
            )
    }
}
