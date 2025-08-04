import Vapor

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
        
        let protectedAPI = api
            .grouped(UserAccountModel.guard())

        protectedAPI.delete("delete", use: userController.delete)
        protectedAPI.get("me", use: userController.getCurrentUser)
        protectedAPI.patch("update", use: userController.patch)

        protectedAPI
            .grouped(EnsureAdminUserMiddleware())
            .get("list", use: userController.list)
    }
}
