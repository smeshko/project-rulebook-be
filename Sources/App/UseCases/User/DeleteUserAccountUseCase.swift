import Foundation
import Vapor

/// Use case for deleting a user account.
///
/// Handles the business logic for user account deletion, including:
/// - User account removal from repository
/// - Cascading cleanup (handled by database constraints and repository)
/// - Response status
///
/// This use case focuses on the core business logic of account deletion
/// while keeping HTTP concerns separate.
struct DeleteUserAccountUseCase: UseCase {
    
    /// Request parameters for user account deletion.
    struct Request {
        /// The authenticated user to delete
        let user: UserAccountModel
        
        init(user: UserAccountModel) {
            self.user = user
        }
    }
    
    /// Response from user account deletion operation.
    struct Response {
        /// Confirmation that deletion was successful
        let deleted: Bool
        /// Timestamp when deletion occurred
        let deletedAt: Date
        
        init(deleted: Bool = true, deletedAt: Date = Date.now) {
            self.deleted = deleted
            self.deletedAt = deletedAt
        }
    }
    
    // Dependencies
    let userRepository: any UserRepository
    
    /// Executes the delete user account use case.
    ///
    /// This method contains the pure business logic for user account deletion:
    /// 1. Delete the user from the repository
    /// 2. Return confirmation of deletion
    ///
    /// Note: Cascading deletions of related records (refresh tokens, email tokens, etc.)
    /// should be handled by database foreign key constraints or repository implementation
    /// to ensure data consistency.
    ///
    /// - Parameter request: Contains the authenticated user to delete
    /// - Returns: Confirmation of successful deletion
    /// - Throws: Repository errors if deletion operations fail
    func execute(_ request: Request) async throws -> Response {
        let user = request.user
        
        // Delete the user account (cascading handled by repository/database)
        try await userRepository.delete(id: user.requireID())
        
        // Return confirmation of deletion
        return Response()
    }
}