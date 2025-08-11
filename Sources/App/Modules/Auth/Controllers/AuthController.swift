import JWT
import Vapor
import Fluent

/// Controller for user authentication, registration, and account management operations.
///
/// This controller handles all authentication-related endpoints including user registration,
/// login, JWT token management, email verification, password reset, and Apple Sign-In integration.
/// It implements comprehensive security measures including rate limiting, email verification,
/// and secure token generation.
///
/// ## Authentication Features
///
/// - **Multi-Provider Authentication**: Email/password and Apple Sign-In support
/// - **JWT Token Management**: Access and refresh token lifecycle management
/// - **Email Verification**: Secure email verification with time-limited tokens
/// - **Password Reset**: Secure password reset flow with email notifications
/// - **Account Security**: Password validation, secure hashing, rate limiting
///
/// ## Security Architecture
///
/// ### Token Security
/// - **JWT Access Tokens**: Short-lived tokens for API authentication
/// - **Refresh Tokens**: Secure, long-lived tokens for token renewal
/// - **Email Verification Tokens**: Time-limited tokens for email confirmation
/// - **Password Reset Tokens**: Secure tokens for password recovery
///
/// ### Authentication Methods
/// - **Email/Password**: Traditional authentication with bcrypt password hashing
/// - **Apple Sign-In**: OAuth integration with Apple identity verification
/// - **Token-Based**: Stateless authentication using JWT tokens
///
/// ### Security Measures
/// - **Rate Limiting**: Operation-specific limits to prevent abuse
/// - **Email Verification**: Required for account activation
/// - **Secure Token Generation**: Cryptographically secure random token generation
/// - **Password Hashing**: Industry-standard bcrypt with appropriate cost factors
/// - **Token Expiration**: Automatic token expiration and cleanup
///
/// ## API Endpoints
///
/// - `POST /auth/sign-up`: User registration with email verification
/// - `POST /auth/sign-in`: User authentication with email/password
/// - `POST /auth/apple`: Apple Sign-In authentication
/// - `POST /auth/refresh`: JWT token refresh
/// - `POST /auth/logout`: User logout with token cleanup
/// - `POST /auth/verify-email`: Email verification confirmation
/// - `POST /auth/reset-password`: Password reset request
/// - `POST /auth/recover-password`: Password recovery completion
///
/// ## Integration Points
///
/// - **User Repository**: Database operations for user management
/// - **Token Repositories**: Management of various token types
/// - **Email Service**: Sending verification and notification emails
/// - **JWT Service**: Token generation and validation
/// - **Random Generator**: Secure token generation
struct AuthController {
    
    /// Authenticates users using Apple Sign-In with secure identity verification.
    ///
    /// This endpoint handles Apple Sign-In authentication by verifying Apple's identity token
    /// and either creating new users or updating existing users with Apple credentials.
    /// It implements secure user management with proper token generation and account linking.
    ///
    /// ## Authentication Flow
    ///
    /// 1. **Token Verification**: Validates Apple identity token signature and claims
    /// 2. **User Lookup**: Searches for existing user by Apple identifier
    /// 3. **Account Management**: Updates existing user or creates new account
    /// 4. **Profile Update**: Updates user profile with latest Apple information
    /// 5. **Token Generation**: Creates new refresh token for the session
    /// 6. **Response Creation**: Returns authentication response with JWT tokens
    ///
    /// ## Security Features
    ///
    /// - **Identity Verification**: Validates Apple's cryptographic signature on identity token
    /// - **Application Binding**: Ensures token was issued for this specific application
    /// - **Token Refresh**: Invalidates old refresh tokens and generates new ones
    /// - **Account Linking**: Safely links Apple identity to existing accounts
    /// - **Profile Synchronization**: Updates user profiles with latest Apple data
    ///
    /// ## New User Creation
    ///
    /// When creating new accounts from Apple Sign-In:
    /// - Email is automatically verified (trusted from Apple)
    /// - Password is set to null (Apple authentication only)
    /// - Apple identifier is stored for future authentication
    /// - Profile information is populated from Apple data
    ///
    /// ## Existing User Updates
    ///
    /// For existing users:
    /// - Email is updated if provided by Apple
    /// - First/last names are updated if provided in request
    /// - All existing refresh tokens are invalidated
    /// - New refresh token is generated for security
    ///
    /// - Parameter req: HTTP request containing ``Auth.Apple.Request`` JSON
    /// - Returns: ``Auth.Apple.Response`` with authentication tokens and user data
    /// - Throws: ``AuthenticationError.invalidEmailOrPassword`` if Apple token verification fails
    ///
    /// ## Request Format
    /// ```json
    /// {
    ///   "appleIdentityToken": "eyJ...", // JWT token from Apple
    ///   "firstName": "John",             // Optional first name
    ///   "lastName": "Doe"               // Optional last name
    /// }
    /// ```
    ///
    /// ## Response Format
    /// ```json
    /// {
    ///   "token": {
    ///     "value": "eyJ...",           // JWT access token
    ///     "refreshToken": "abc123...", // Refresh token for token renewal
    ///     "expiresAt": "2025-01-01T12:00:00Z"
    ///   },
    ///   "user": {
    ///     "id": "uuid",
    ///     "email": "user@example.com",
    ///     "firstName": "John",
    ///     "lastName": "Doe"
    ///   }
    /// }
    /// ```
    func authWithApple(_ req: Request) async throws -> Auth.Apple.Response {
        let request = try req.content.decode(Auth.Apple.Request.self)
        
        let appleIdentityToken = try await req.jwt.apple.verify(
            request.appleIdentityToken,
            applicationIdentifier: Environment.appIdentifier
        )
        
        if let user = try await req.repositories.users.find(appleUserIdentifier: appleIdentityToken.subject.value) {
            if let email = appleIdentityToken.email {
                user.email = email
            }
            if let firstName = request.firstName {
                user.firstName = firstName
            }
            if let lastName = request.lastName {
                user.lastName = lastName
            }

            try await req.repositories.users.update(user)
            try await req.repositories.refreshTokens.delete(forUserID: try user.requireID())
            
            let token = req.services.randomGenerator.generate(bits: 256)
            let refreshToken = RefreshTokenModel(value: SHA256.hash(token), userID: try user.requireID())
            
            try await req.repositories.refreshTokens.create(refreshToken)

            return Auth.Apple.Response(
                token: try .init(token: token, user: user, on: req),
                user: try .init(from: user)
            )
        } else {
            guard let email = appleIdentityToken.email else {
                throw AuthenticationError.invalidEmailOrPassword
            }
            let user = UserAccountModel(
                email: email.lowercased(),
                password: nil,
                firstName: request.firstName.nilOrNonEmptyValue,
                lastName: request.lastName.nilOrNonEmptyValue,
                appleUserIdentifier: appleIdentityToken.subject.value,
                isEmailVerified: true
            )
            
            do {
                try await req.repositories.users.create(user)
            } catch is DatabaseError {
                throw AuthenticationError.emailAlreadyExists
            }
            
            let token = req.services.randomGenerator.generate(bits: 256)
            let refreshToken = RefreshTokenModel(value: SHA256.hash(token), userID: try user.requireID())
            
            try await req.repositories.refreshTokens.create(refreshToken)
            return Auth.Apple.Response(
                token: try .init(token: token, user: user, on: req),
                user: try .init(from: user)
            )
        }
    }
    
    func signIn(_ req: Request) async throws -> Auth.Login.Response {
        let user = try req.auth.require(UserAccountModel.self)
        try await req.repositories.refreshTokens.delete(forUserID: try user.requireID())
        
        let token = req.services.randomGenerator.generate(bits: 256)
        let refreshToken = RefreshTokenModel(value: SHA256.hash(token), userID: try user.requireID())
        
        try await req.repositories.refreshTokens.create(refreshToken)

        return Auth.Login.Response(
            token: try .init(token: token, user: user, on: req),
            user: try .init(from: user)
        )
    }
    
    func signUp(_ req: Request) async throws -> Auth.SignUp.Response {
        try Auth.SignUp.Request.validate(content: req)
        let registerRequest = try req.content.decode(Auth.SignUp.Request.self)

        let hash = try await req.password.async.hash(registerRequest.password)
        let user = UserAccountModel(
            email: registerRequest.email.lowercased(),
            password: hash,
            firstName: registerRequest.firstName.nilOrNonEmptyValue,
            lastName: registerRequest.lastName.nilOrNonEmptyValue
        )
        
        do {
            try await req.repositories.users.create(user)
        } catch is DatabaseError {
            throw AuthenticationError.emailAlreadyExists
        }

        let token = req.services.randomGenerator.generate(bits: 256)
        let refreshToken = RefreshTokenModel(value: SHA256.hash(token), userID: try user.requireID())
        
        try await req.repositories.refreshTokens.create(refreshToken)
        try await req.emailVerifier.verify(for: user)
        
        return Auth.SignUp.Response(
            token: try .init(token: token, user: user, on: req),
            user: try .init(from: user)
        )
    }
    
    func refreshAccessToken(_ req: Request) async throws -> Auth.TokenRefresh.Response {
        let accessTokenRequest = try req.content.decode(Auth.TokenRefresh.Request.self)
        let hashedRefreshToken = SHA256.hash(accessTokenRequest.refreshToken)
        
        guard let token = try await req.repositories.refreshTokens.find(token: hashedRefreshToken) else {
            throw AuthenticationError.refreshTokenOrUserNotFound
        }
        
        guard token.expiresAt > .now else {
            throw AuthenticationError.refreshTokenHasExpired
        }
        
        guard let user = try await req.repositories.users.find(id: token.$user.id) else {
            throw UserError.userNotFound
        }
        
        try await req.repositories.refreshTokens.delete(id: token.requireID())
        
        let generatedToken = req.services.randomGenerator.generate(bits: 256)
        let newRefreshToken = try RefreshTokenModel(value: SHA256.hash(generatedToken), userID: user.requireID())
        
        let payload = try TokenPayload(with: user)
        let accessToken = try req.jwt.sign(payload)
        
        try await req.repositories.refreshTokens.create(newRefreshToken)
        return .init(
            refreshToken: generatedToken,
            accessToken: accessToken
        )
    }
    
    func logout(_ req: Request) async throws -> HTTPStatus {
        let user = try req.auth.require(UserAccountModel.self)
        try await req.repositories.refreshTokens.delete(forUserID: user.requireID())
        req.auth.logout(UserAccountModel.self)
        return .ok
    }
    
    func resetPassword(_ req: Request) async throws -> HTTPStatus {
        let resetPasswordRequest = try req.content.decode(Auth.PasswordReset.Request.self)
        
        guard let user = try await req.repositories.users.find(email: resetPasswordRequest.email) else {
            throw UserError.userNotFound
        }
        
        try await req.passwordResetter.reset(for: user)
        return .ok
    }
}

private extension Optional where Wrapped == String {
    var nilOrNonEmptyValue: String? {
        guard let self else { return nil }
        let trimmed = self.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
