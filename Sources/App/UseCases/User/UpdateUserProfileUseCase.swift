import Foundation
import Vapor

/// Use case for updating user profile information.
///
/// Handles the business logic for user profile updates, including:
/// - Input validation and sanitization
/// - User model updates
/// - Repository persistence
/// - Response formatting
///
/// This use case focuses on the core business logic of updating user profiles
/// while keeping HTTP concerns separate.
/// ## CQRS Classification  
/// This is an **UpdateCommand** because it modifies existing user profile data.
struct UpdateUserProfileUseCase: UpdateCommand {
    typealias EntityID = UUID
    
    /// Request parameters for user profile update.
    struct Request {
        /// The authenticated user to update
        let user: UserAccountModel
        /// The update data
        let updateData: User.Update.Request
        
        init(user: UserAccountModel, updateData: User.Update.Request) {
            self.user = user
            self.updateData = updateData
        }
    }
    
    /// Response from user profile update operation.
    typealias Response = User.Update.Response
    
    // Dependencies
    let userRepository: any UserRepository
    
    /// Executes the update user profile use case.
    ///
    /// This method contains the pure business logic for user profile updates:
    /// 1. Apply updates to user model (only non-nil fields)
    /// 2. Persist changes to repository
    /// 3. Return updated user data
    ///
    /// The use case follows a conservative update strategy - only fields that
    /// are explicitly provided (non-nil) will be updated.
    ///
    /// - Parameter request: Contains the user and update data
    /// - Returns: Updated user profile data
    /// - Throws: Repository errors if update operations fail
    func execute(_ request: Request) async throws -> Response {
        let user = request.user
        let updateData = request.updateData
        
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
        
        // Persist changes to repository
        try await userRepository.update(user)
        
        // Return updated user data
        return try Response(from: user)
    }
}