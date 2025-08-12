import Foundation
import Vapor

/// Use case for retrieving the current authenticated user's profile.
///
/// Handles the business logic for getting the current user's profile data,
/// including authentication validation and response formatting.
///
/// This use case focuses on retrieving user profile data in a format
/// appropriate for client consumption.
struct GetCurrentUserUseCase: UseCase {
    
    /// Request parameters for getting current user.
    struct Request {
        /// The authenticated user
        let user: UserAccountModel
        
        init(user: UserAccountModel) {
            self.user = user
        }
    }
    
    /// Response from get current user operation.
    typealias Response = User.Detail.Response
    
    /// Executes the get current user use case.
    ///
    /// This method contains the pure business logic for retrieving current user:
    /// 1. Takes the authenticated user (already validated by middleware)
    /// 2. Converts to appropriate response format
    ///
    /// Note: User authentication is handled by Vapor middleware before 
    /// this use case is called, ensuring the user is already validated.
    ///
    /// - Parameter request: Contains the authenticated user
    /// - Returns: User profile data
    /// - Throws: Model conversion errors
    func execute(_ request: Request) async throws -> Response {
        let user = request.user
        
        // Convert user model to response format
        return try Response(from: user)
    }
}