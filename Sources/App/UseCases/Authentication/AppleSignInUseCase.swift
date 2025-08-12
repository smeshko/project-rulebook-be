import Foundation
import Vapor
import Fluent
import JWT
import Crypto

/// Use case for Apple Sign-In authentication operations.
///
/// Handles the business logic for Apple Sign-In authentication, including:
/// - Apple identity token verification and validation
/// - User lookup by Apple identifier
/// - New user account creation with Apple identity
/// - Existing user profile updates with latest Apple data
/// - Refresh token management for authentication sessions
/// - Email verification automatic trust (Apple verified)
///
/// This use case coordinates between Apple's JWT verification, user management,
/// and session token generation to provide secure Apple authentication.
struct AppleSignInUseCase: Command {
    
    /// Request parameters for Apple Sign-In operation.
    struct Request {
        /// Apple identity token (JWT) from Apple Sign-In
        let appleIdentityToken: String
        /// Optional first name from Apple Sign-In
        let firstName: String?
        /// Optional last name from Apple Sign-In
        let lastName: String?
        
        init(appleIdentityToken: String, firstName: String? = nil, lastName: String? = nil) {
            self.appleIdentityToken = appleIdentityToken
            self.firstName = firstName
            self.lastName = lastName
        }
    }
    
    /// Response from Apple Sign-In operation.
    struct Response {
        /// Authenticated user (created or updated)
        let user: UserAccountModel
        /// Generated refresh token for session management
        let refreshToken: String
        /// Whether this was a new user registration
        let isNewUser: Bool
        /// Timestamp when Apple Sign-In completed
        let signedInAt: Date
    }
    
    // Dependencies
    let userRepository: any UserRepository
    let refreshTokenRepository: any RefreshTokenRepository
    let appleJWTVerifier: @Sendable (String, String) async throws -> AppleIdentityToken
    let randomGenerator: RandomGeneratorService
    let appIdentifier: String
    
    /// Executes the Apple Sign-In use case.
    ///
    /// This method contains the pure business logic for Apple Sign-In:
    /// 1. Verify Apple identity token signature and claims
    /// 2. Look up existing user by Apple identifier
    /// 3. If user exists: update profile and generate new session
    /// 4. If user doesn't exist: create new account with Apple identity
    /// 5. Generate refresh token and return authentication response
    ///
    /// - Parameter request: Contains Apple identity token and optional profile data
    /// - Returns: User data, refresh token, and authentication metadata
    /// - Throws: 
    ///   - `AuthenticationError.invalidEmailOrPassword` if Apple token verification fails
    ///   - `AuthenticationError.emailAlreadyExists` if email conflicts with existing account
    ///   - Repository errors if user operations fail
    func execute(_ request: Request) async throws -> Response {
        // 1. Verify Apple identity token
        let appleIdentityToken = try await verifyAppleToken(request.appleIdentityToken)
        
        // 2. Look up existing user by Apple identifier
        if let existingUser = try await userRepository.find(appleUserIdentifier: appleIdentityToken.subject.value) {
            // 3a. Update existing user and create new session
            return try await handleExistingUser(existingUser, appleToken: appleIdentityToken, request: request)
        } else {
            // 3b. Create new user account with Apple identity
            return try await handleNewUser(appleToken: appleIdentityToken, request: request)
        }
    }
    
    /// Verifies the Apple identity token using JWKS.
    ///
    /// - Parameter token: The Apple identity token to verify
    /// - Returns: Verified Apple identity token payload
    /// - Throws: JWT verification errors or invalid token errors
    private func verifyAppleToken(_ token: String) async throws -> AppleIdentityToken {
        return try await appleJWTVerifier(token, appIdentifier)
    }
    
    /// Handles authentication for existing Apple users.
    ///
    /// Updates user profile with latest Apple information and creates new session.
    ///
    /// - Parameters:
    ///   - user: Existing user account
    ///   - appleToken: Verified Apple identity token
    ///   - request: Original request with profile updates
    /// - Returns: Authentication response for existing user
    /// - Throws: Repository errors if updates fail
    private func handleExistingUser(
        _ user: UserAccountModel, 
        appleToken: AppleIdentityToken, 
        request: Request
    ) async throws -> Response {
        
        // Update email if provided by Apple
        if let email = appleToken.email {
            user.email = email
        }
        
        // Update names if provided in request
        if let firstName = request.firstName {
            user.firstName = firstName
        }
        if let lastName = request.lastName {
            user.lastName = lastName
        }
        
        // Save user updates
        try await userRepository.update(user)
        
        // Clean up existing tokens and create new session
        let refreshToken = try await createNewSession(for: user)
        
        return Response(
            user: user,
            refreshToken: refreshToken,
            isNewUser: false,
            signedInAt: Date.now
        )
    }
    
    /// Handles authentication for new Apple users.
    ///
    /// Creates new user account with Apple identity and verified email.
    ///
    /// - Parameters:
    ///   - appleToken: Verified Apple identity token
    ///   - request: Original request with profile data
    /// - Returns: Authentication response for new user
    /// - Throws: 
    ///   - `AuthenticationError.invalidEmailOrPassword` if no email provided
    ///   - `AuthenticationError.emailAlreadyExists` if email conflicts
    ///   - Repository errors if user creation fails
    private func handleNewUser(
        appleToken: AppleIdentityToken, 
        request: Request
    ) async throws -> Response {
        
        // Apple must provide email for new users
        guard let email = appleToken.email else {
            throw AuthenticationError.invalidEmailOrPassword
        }
        
        // Create new user account
        let user = UserAccountModel(
            email: email.lowercased(),
            password: nil, // Apple authentication only
            firstName: request.firstName.nilOrNonEmptyValue,
            lastName: request.lastName.nilOrNonEmptyValue,
            appleUserIdentifier: appleToken.subject.value,
            isEmailVerified: true // Trust Apple's email verification
        )
        
        // Create user account (handles unique email constraint)
        do {
            try await userRepository.create(user)
        } catch {
            // Check if this is a unique constraint failure for email
            if error.localizedDescription.contains("UNIQUE constraint failed: users.email") {
                throw AuthenticationError.emailAlreadyExists
            }
            throw error
        }
        
        // Create new session
        let refreshToken = try await createNewSession(for: user)
        
        return Response(
            user: user,
            refreshToken: refreshToken,
            isNewUser: true,
            signedInAt: Date.now
        )
    }
    
    /// Creates a new authentication session for the user.
    ///
    /// Cleans up existing refresh tokens and generates a new one for security.
    ///
    /// - Parameter user: User to create session for
    /// - Returns: Generated refresh token value
    /// - Throws: Repository errors if token operations fail
    private func createNewSession(for user: UserAccountModel) async throws -> String {
        // Clean up existing refresh tokens for security
        try await refreshTokenRepository.delete(forUserID: user.requireID())
        
        // Generate new refresh token
        let tokenValue = randomGenerator.generate(bits: 256)
        let refreshToken = RefreshTokenModel(
            value: SHA256.hash(tokenValue), 
            userID: try user.requireID()
        )
        
        // Store the new refresh token
        try await refreshTokenRepository.create(refreshToken)
        
        return tokenValue
    }
}

// MARK: - Helper Extensions

extension Optional where Wrapped == String {
    var nilOrNonEmptyValue: String? {
        guard let self else { return nil }
        let trimmed = self.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}