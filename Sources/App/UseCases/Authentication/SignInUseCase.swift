import Foundation
import Vapor
import Crypto

/// Use case for user sign-in operations.
///
/// Handles the business logic for user authentication, including:
/// - User credential validation (handled by middleware before this use case)
/// - Existing refresh token cleanup for security
/// - New refresh token generation
/// - User authentication state management
///
/// This use case assumes the user has already been authenticated via middleware
/// and focuses on the business logic of establishing a new authenticated session.
struct SignInUseCase: Command {
    
    /// Request parameters for sign-in operation.
    struct Request {
        /// The authenticated user (validated by middleware)
        let user: UserAccountModel
        
        init(user: UserAccountModel) {
            self.user = user
        }
    }
    
    /// Response from sign-in operation.
    struct Response {
        /// The authenticated user
        let user: UserAccountModel
        /// Generated refresh token for session management
        let refreshToken: String
        /// Timestamp when sign-in completed
        let signedInAt: Date
    }
    
    // Dependencies
    let refreshTokenRepository: any RefreshTokenRepository
    let randomGenerator: RandomGeneratorService
    
    /// Executes the sign-in use case.
    ///
    /// This method contains the pure business logic for user sign-in:
    /// 1. Clean up all existing refresh tokens for security (single session)
    /// 2. Generate new refresh token for this session
    /// 3. Store the refresh token in the repository
    /// 4. Return user data and authentication token
    ///
    /// Note: User credential validation is handled by Vapor middleware before 
    /// this use case is called, ensuring the user is already authenticated.
    ///
    /// - Parameter request: Contains the authenticated user
    /// - Returns: User data, refresh token, and sign-in timestamp
    /// - Throws: Repository errors if token operations fail
    func execute(_ request: Request) async throws -> Response {
        let user = request.user
        
        // 1. Clean up existing refresh tokens for security
        // This ensures only one active session per user at a time
        try await refreshTokenRepository.delete(forUserID: user.requireID())
        
        // 2. Generate new refresh token for this session
        let tokenValue = randomGenerator.generate(bits: 256)
        let refreshToken = RefreshTokenModel(
            value: SHA256.hash(tokenValue), 
            userID: try user.requireID()
        )
        
        // 3. Store the new refresh token
        try await refreshTokenRepository.create(refreshToken)
        
        // 4. Return response with user and token data
        return Response(
            user: user,
            refreshToken: tokenValue,
            signedInAt: Date.now
        )
    }
}