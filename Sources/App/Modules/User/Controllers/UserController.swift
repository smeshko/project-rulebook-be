import Fluent
import Vapor

/// User controller responsible for handling HTTP requests related to user management.
///
/// This controller focuses on HTTP concerns (request/response handling, authentication, 
/// content decoding) while delegating business logic to use cases.
///
/// The controller maintains the existing API contract while internally using
/// the new Clean Architecture use case pattern.
struct UserController {
    
    /// Get current authenticated user's profile.
    ///
    /// - Parameter req: HTTP request with authenticated user
    /// - Returns: User profile data
    /// - Throws: Authentication errors, use case execution errors
    func getCurrentUser(_ req: Request) async throws -> User.Detail.Response {
        let user = try req.auth.require(UserAccountModel.self)
        let useCase = try await req.useCases.user.getCurrentUser
        
        let request = GetCurrentUserUseCase.Request(user: user)
        return try await useCase.execute(request)
    }
    
    /// Delete the current authenticated user's account.
    ///
    /// - Parameter req: HTTP request with authenticated user
    /// - Returns: HTTP status indicating success
    /// - Throws: Authentication errors, use case execution errors
    func delete(_ req: Request) async throws -> HTTPStatus {
        let user = try req.auth.require(UserAccountModel.self)
        let useCase = try await req.useCases.user.deleteAccount
        
        let request = DeleteUserAccountUseCase.Request(user: user)
        _ = try await useCase.execute(request)
        
        return .ok
    }
    
    /// List all users (admin only).
    ///
    /// - Parameter req: HTTP request with authenticated admin user
    /// - Returns: List of all users
    /// - Throws: Authentication errors, authorization errors, use case execution errors
    func list(_ req: Request) async throws -> [User.List.Response] {
        let adminUser = try req.auth.require(UserAccountModel.self)
        let useCase = try await req.useCases.user.listUsers
        
        let request = ListUsersUseCase.Request(adminUser: adminUser)
        return try await useCase.execute(request)
    }
    
    /// Update current authenticated user's profile.
    ///
    /// - Parameter req: HTTP request with authenticated user and update data
    /// - Returns: Updated user profile data
    /// - Throws: Authentication errors, validation errors, use case execution errors
    func patch(_ req: Request) async throws -> User.Update.Response {
        let updateData = try req.content.decode(User.Update.Request.self)
        let user = try req.auth.require(UserAccountModel.self)
        let useCase = try await req.useCases.user.updateProfile
        
        let request = UpdateUserProfileUseCase.Request(user: user, updateData: updateData)
        return try await useCase.execute(request)
    }
}
