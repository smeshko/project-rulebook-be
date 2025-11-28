import Vapor
import VaporToOpenAPI

struct UserRouter: RouteCollection {
    
    let userController = UserController()
    
    func boot(routes: RoutesBuilder) throws {
        user(routes: routes)
    }
}

private extension UserRouter {
    func user(routes: RoutesBuilder) {
        let api = routes
            .grouped("api")
            .grouped("user")
            .groupedOpenAPI(tags: .init(name: "User", description: "User profile management and account operations"))

        let protectedAPI = api
            .grouped(UserAccountModel.guard())

        protectedAPI
            .delete("delete", use: userController.delete)
            .openAPI(
                description: "Permanently delete current user account and all associated data. Requires authentication.",
                auth: .bearer(id: "bearerAuth")
            )

        protectedAPI
            .get("me", use: userController.getCurrentUser)
            .openAPI(
                description: "Retrieve current authenticated user's profile information including email, name, and account status.",
                auth: .bearer(id: "bearerAuth")
            )

        protectedAPI
            .patch("update", use: userController.patch)
            .openAPI(
                description: "Update current user's profile information (email, first name, last name). Only modifies provided fields.",
                auth: .bearer(id: "bearerAuth")
            )

        protectedAPI
            .grouped(EnsureAdminUserMiddleware())
            .get("list", use: userController.list)
            .openAPI(
                description: "List all user accounts in the system. Requires admin privileges for security and privacy.",
                auth: .bearer(id: "bearerAuth")
            )
    }
}
