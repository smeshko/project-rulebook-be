import Vapor
import VaporToOpenAPI

struct FrontendRouter: RouteCollection {
    
    let controller = FrontendController()
    
    func boot(routes: RoutesBuilder) throws {
        let frontend = routes
            .groupedOpenAPI(tags: .init(name: "Frontend", description: "HTML web pages for email verification and password reset"))

        frontend
            .get("verify-email", use: controller.verifyEmail)
            .openAPI(description: "Email verification page. User clicks link from verification email with token query parameter. Returns HTML success/error page.")

        frontend
            .get("reset-password", use: controller.resetPassword)
            .openAPI(description: "Password reset form page. User clicks link from password reset email with token query parameter. Returns HTML form to enter new password.")

        frontend
            .post("reset-password", use: controller.resetPasswordAction)
            .openAPI(description: "Process password reset form submission. Validates token and updates password. Returns HTML success/error page.")
    }
}
