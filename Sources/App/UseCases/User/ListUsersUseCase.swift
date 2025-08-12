import Foundation
import Vapor

/// Use case for listing users (admin operation).
///
/// Handles the business logic for retrieving a list of all users, including:
/// - User list retrieval from repository
/// - Response formatting for list view
///
/// This use case focuses on the core business logic of user listing
/// while keeping HTTP concerns separate.
struct ListUsersUseCase: UseCase {
    
    /// Request parameters for user listing.
    struct Request {
        /// The authenticated admin user making the request
        let adminUser: UserAccountModel
        
        init(adminUser: UserAccountModel) {
            self.adminUser = adminUser
        }
    }
    
    /// Response from user listing operation.
    typealias Response = [User.List.Response]
    
    // Dependencies
    let userRepository: any UserRepository
    
    /// Executes the list users use case.
    ///
    /// This method contains the pure business logic for user listing:
    /// 1. Retrieve all users from repository
    /// 2. Convert to appropriate list response format
    ///
    /// Note: Admin authorization is handled by the EnsureAdminUserMiddleware
    /// before this use case is called, so we don't need to check it here.
    ///
    /// - Parameter request: Contains the admin user making the request
    /// - Returns: List of user data formatted for listing
    /// - Throws: Repository errors for data access
    func execute(_ request: Request) async throws -> Response {
        // Retrieve all users from repository
        let users = try await userRepository.all()
        
        // Convert to list response format
        return try users.map { user in
            try User.List.Response(from: user)
        }
    }
}