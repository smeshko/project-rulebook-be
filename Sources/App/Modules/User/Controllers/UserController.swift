import Fluent
import Vapor

/// User controller responsible for handling HTTP requests related to user management.
///
/// This controller handles all user-related operations including profile retrieval,
/// updates, listing (admin), and account deletion with inline business logic.
struct UserController {

    /// Get current authenticated user's profile.
    ///
    /// - Parameter req: HTTP request with authenticated user
    /// - Returns: User profile data
    func getCurrentUser(_ req: Request) async throws -> User.Detail.Response {
        let user = try req.auth.require(UserAccountModel.self)
        return try .init(from: user)
    }

    /// Delete the current authenticated user's account.
    ///
    /// Performs cascade deletion of all related tokens before deleting the user.
    ///
    /// - Parameter req: HTTP request with authenticated user
    /// - Returns: HTTP status indicating success
    func delete(_ req: Request) async throws -> HTTPStatus {
        let user = try req.auth.require(UserAccountModel.self)
        let userID = try user.requireID()

        // Cascade delete: tokens first, then user
        try await req.repositories.refreshTokens.delete(forUserID: userID)
        try await req.repositories.emailTokens.delete(forUserID: userID)
        try await req.repositories.passwordTokens.delete(forUserID: userID)
        try await req.repositories.users.delete(id: userID)

        return .ok
    }

    /// List all users (admin only).
    ///
    /// - Parameter req: HTTP request with authenticated admin user
    /// - Returns: List of all users
    func list(_ req: Request) async throws -> [User.List.Response] {
        // Admin authorization handled by EnsureAdminUserMiddleware
        _ = try req.auth.require(UserAccountModel.self)

        let users = try await req.repositories.users.all()
        return try users.map { try User.List.Response(from: $0) }
    }

    /// Update current authenticated user's profile.
    ///
    /// Only updates fields that are explicitly provided (non-nil).
    ///
    /// - Parameter req: HTTP request with authenticated user and update data
    /// - Returns: Updated user profile data
    func patch(_ req: Request) async throws -> User.Update.Response {
        let updateData = try req.content.decode(User.Update.Request.self)
        let user = try req.auth.require(UserAccountModel.self)

        // Apply updates only to non-nil fields
        if let email = updateData.email {
            user.email = email
        }
        if let firstName = updateData.firstName {
            user.firstName = firstName
        }
        if let lastName = updateData.lastName {
            user.lastName = lastName
        }

        try await req.repositories.users.update(user)
        return try .init(from: user)
    }
}
