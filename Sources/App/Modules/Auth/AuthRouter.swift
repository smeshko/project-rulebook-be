import Vapor
import VaporToOpenAPI

struct AuthRouter: RouteCollection {
    let controller = AuthController()

    func boot(routes: RoutesBuilder) throws {
        let api = routes
            .grouped("api")
            .grouped("v1")
            .grouped("auth")
            .groupedOpenAPI(tags: .init(name: "Auth", description: "User authentication and account management"))

        api
            .grouped(UserCredentialsAuthenticator())
            .post("sign-in", use: controller.signIn)
            .openAPI(
                description: "Authenticate user with email and password. Returns JWT access token and refresh token for subsequent API requests.",
                body: .type(Auth.Login.Request.self),
                response: .type(Auth.Login.Response.self)
            )

        api
            .post("sign-up", use: controller.signUp)
            .openAPI(
                description: "Create new user account with email and password. Sends email verification link and returns JWT tokens.",
                body: .type(Auth.SignUp.Request.self),
                response: .type(Auth.SignUp.Response.self)
            )

        api
            .post("apple-auth", use: controller.authWithApple)
            .openAPI(
                description: "Authenticate or create account using Apple Sign In. Returns JWT tokens for the associated user account.",
                body: .type(Auth.Apple.Request.self),
                response: .type(Auth.Apple.Response.self)
            )

        api
            .post("refresh", use: controller.refreshAccessToken)
            .openAPI(
                description: "Exchange refresh token for new access token. Use when access token expires to maintain authenticated session.",
                body: .type(Auth.TokenRefresh.Request.self),
                response: .type(Auth.TokenRefresh.Response.self)
            )

        api
            .post("reset-password", use: controller.resetPassword)
            .openAPI(description: "Request password reset email. Sends recovery link to user's email address if account exists.", body: .type(Auth.PasswordReset.Request.self))
            .response(statusCode: .ok, description: "Password reset email sent if account exists")

        api
            .grouped(UserAccountModel.guard())
            .post("logout", use: controller.logout)
            .openAPI(
                description: "Invalidate current refresh token and end authenticated session. Requires valid JWT access token.",
                auth: .bearer(id: "bearerAuth")
            )
            .response(statusCode: .ok, description: "Successfully logged out")
    }
}
