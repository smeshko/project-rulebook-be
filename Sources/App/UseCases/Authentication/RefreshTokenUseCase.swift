import Foundation
import Vapor
import JWT
import Crypto

/// Use case for JWT access token refresh operations.
///
/// Handles the business logic for refreshing JWT access tokens, including:
/// - Refresh token validation and lookup
/// - Token expiration checking
/// - User account validation
/// - Old token cleanup and new token generation
/// - JWT access token generation with user payload
///
/// This use case implements secure token refresh following best practices
/// with automatic cleanup and rotation of refresh tokens.
struct RefreshTokenUseCase: Command {
    
    /// Request parameters for token refresh operation.
    struct Request {
        /// The refresh token to exchange for new access token
        let refreshToken: String
        
        init(refreshToken: String) {
            self.refreshToken = refreshToken
        }
    }
    
    /// Response from token refresh operation.
    struct Response {
        /// New JWT access token
        let accessToken: String
        /// New refresh token (rotated for security)
        let refreshToken: String
        /// User associated with the token
        let user: UserAccountModel
        /// Timestamp when refresh completed
        let refreshedAt: Date
    }
    
    // Dependencies
    let refreshTokenRepository: any RefreshTokenRepository
    let userRepository: any UserRepository
    let jwtSigner: JWTSigner
    let randomGenerator: RandomGeneratorService
    
    /// Executes the refresh token use case.
    ///
    /// This method contains the pure business logic for token refresh:
    /// 1. Hash and lookup the provided refresh token
    /// 2. Validate token exists and hasn't expired
    /// 3. Lookup and validate associated user account
    /// 4. Delete old refresh token (single-use security)
    /// 5. Generate new refresh token and JWT access token
    /// 6. Return new tokens and user information
    ///
    /// - Parameter request: Contains the refresh token to exchange
    /// - Returns: New access token, refresh token, and user data
    /// - Throws: 
    ///   - `AuthenticationError.refreshTokenOrUserNotFound` if token doesn't exist
    ///   - `AuthenticationError.refreshTokenHasExpired` if token is expired
    ///   - `UserError.userNotFound` if associated user doesn't exist
    ///   - Repository errors if token operations fail
    func execute(_ request: Request) async throws -> Response {
        // 1. Hash the refresh token for lookup (tokens are stored hashed)
        let hashedRefreshToken = SHA256.hash(request.refreshToken)
        
        // 2. Find the refresh token in the database
        guard let storedToken = try await refreshTokenRepository.find(token: hashedRefreshToken) else {
            throw AuthenticationError.refreshTokenOrUserNotFound
        }
        
        // 3. Check if token has expired
        guard storedToken.expiresAt > .now else {
            throw AuthenticationError.refreshTokenHasExpired
        }
        
        // 4. Find the associated user
        guard let user = try await userRepository.find(id: storedToken.$user.id) else {
            throw UserError.userNotFound
        }
        
        // 5. Delete old refresh token (single-use security)
        try await refreshTokenRepository.delete(id: storedToken.requireID())
        
        // 6. Generate new refresh token
        let newRefreshTokenValue = randomGenerator.generate(bits: 256)
        let newRefreshToken = try RefreshTokenModel(
            value: SHA256.hash(newRefreshTokenValue), 
            userID: user.requireID()
        )
        
        // 7. Generate new JWT access token
        let tokenPayload = try TokenPayload(with: user)
        let accessToken = try jwtSigner.sign(tokenPayload)
        
        // 8. Store new refresh token
        try await refreshTokenRepository.create(newRefreshToken)
        
        // 9. Return response with new tokens
        return Response(
            accessToken: accessToken,
            refreshToken: newRefreshTokenValue,
            user: user,
            refreshedAt: Date.now
        )
    }
}