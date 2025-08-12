import Foundation
import Vapor

/// Use case for user logout operations.
///
/// Handles the business logic for logging out users, including:
/// - Invalidating all refresh tokens for the user
/// - Clearing authentication state
/// - Ensuring secure logout process
///
/// This use case demonstrates the minimal pattern for extracting business logic
/// from controllers into testable, reusable components.
///
/// ## CQRS Classification
/// This is a **Command** because it modifies system state by deleting refresh tokens.
struct LogoutUseCase: Command {
    
    /// Request parameters for logout operation.
    struct Request {
        /// The authenticated user to logout
        let user: UserAccountModel
    }
    
    /// Response from logout operation.
    struct Response {
        /// Timestamp when logout completed
        let loggedOutAt: Date
    }
    
    // Dependencies
    let refreshTokenRepository: any RefreshTokenRepository
    
    /// Executes the logout use case.
    ///
    /// This method contains the pure business logic for user logout:
    /// 1. Invalidate all refresh tokens for the user
    /// 2. Record the logout timestamp
    /// 3. Return confirmation
    ///
    /// - Parameter request: Contains the user to logout
    /// - Returns: Confirmation of successful logout
    /// - Throws: Repository errors if token cleanup fails
    func execute(_ request: Request) async throws -> Response {
        // Business logic: Clean up all refresh tokens for security
        try await refreshTokenRepository.delete(forUserID: request.user.requireID())
        
        // Return response with timestamp
        return Response(loggedOutAt: Date.now)
    }
}