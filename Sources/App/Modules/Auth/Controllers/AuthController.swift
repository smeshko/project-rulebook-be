import JWT
import Vapor
import Fluent
import Crypto

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
        // 1. Decode request (HTTP concern)
        let appleRequest = try req.content.decode(Auth.Apple.Request.self)

        // 2. Verify Apple identity token
        let appleIdentityToken = try await req.jwt.apple.verify(
            appleRequest.appleIdentityToken,
            applicationIdentifier: try req.application.configuration.security.appIdentifier
        )

        // 3. Look up existing user by Apple identifier
        let user: UserAccountModel
        if let existingUser = try await req.repositories.users.find(appleUserIdentifier: appleIdentityToken.subject.value) {
            // 3a. Update existing user with latest Apple information
            if let email = appleIdentityToken.email {
                existingUser.email = email
            }
            if let firstName = appleRequest.firstName {
                existingUser.firstName = firstName
            }
            if let lastName = appleRequest.lastName {
                existingUser.lastName = lastName
            }
            try await req.repositories.users.update(existingUser)
            user = existingUser
        } else {
            // 3b. Create new user account with Apple identity
            guard let email = appleIdentityToken.email else {
                throw AuthenticationError.invalidEmailOrPassword
            }

            let newUser = UserAccountModel(
                email: email.lowercased(),
                password: nil, // Apple authentication only
                firstName: appleRequest.firstName.nilOrNonEmptyValue,
                lastName: appleRequest.lastName.nilOrNonEmptyValue,
                appleUserIdentifier: appleIdentityToken.subject.value,
                isEmailVerified: true // Trust Apple's email verification
            )

            // Create user account (handles unique email constraint)
            do {
                try await req.repositories.users.create(newUser)
            } catch {
                let errorString = String(reflecting: error)

                let isPostgreSQLDuplicateEmail = errorString.contains("sqlState: 23505") &&
                    (errorString.contains("uq:users.email") ||
                     errorString.contains("Key (email)") ||
                     errorString.contains("duplicate key") && errorString.contains("email"))

                let isSQLiteDuplicateEmail = errorString.contains("UNIQUE constraint failed: users.email")

                if isPostgreSQLDuplicateEmail || isSQLiteDuplicateEmail {
                    throw AuthenticationError.emailAlreadyExists
                }

                throw error
            }
            user = newUser
        }

        // 4. Clean up existing refresh tokens and create new session
        try await req.repositories.refreshTokens.delete(forUserID: user.requireID())

        // 5. Generate new refresh token
        let tokenValue = req.services.randomGenerator.generate(bits: 256)
        let refreshToken = RefreshTokenModel(
            value: SHA256.hash(tokenValue),
            userID: try user.requireID()
        )
        try await req.repositories.refreshTokens.create(refreshToken)

        // 6. Return HTTP response
        return Auth.Apple.Response(
            token: try .init(token: tokenValue, user: user, on: req),
            user: try .init(from: user)
        )
    }
    
    func signIn(_ req: Request) async throws -> Auth.Login.Response {
        // 1. Extract authenticated user (HTTP concern - middleware already validated credentials)
        let user = try req.auth.require(UserAccountModel.self)

        // 2. Clean up existing refresh tokens for security (single session)
        try await req.repositories.refreshTokens.delete(forUserID: user.requireID())

        // 3. Generate new refresh token for this session
        let tokenValue = req.services.randomGenerator.generate(bits: 256)
        let refreshToken = RefreshTokenModel(
            value: SHA256.hash(tokenValue),
            userID: try user.requireID()
        )
        try await req.repositories.refreshTokens.create(refreshToken)

        // 4. Return HTTP response
        return Auth.Login.Response(
            token: try .init(token: tokenValue, user: user, on: req),
            user: try .init(from: user)
        )
    }
    
    func signUp(_ req: Request) async throws -> Auth.SignUp.Response {
        // 1. Validate request (HTTP concern)
        try Auth.SignUp.Request.validate(content: req)
        let registerRequest = try req.content.decode(Auth.SignUp.Request.self)

        // 2. Hash password securely
        let hashedPassword = try await req.password.async.hash(registerRequest.password)

        // 3. Create user model with normalized email
        let user = UserAccountModel(
            email: registerRequest.email.lowercased(),
            password: hashedPassword,
            firstName: registerRequest.firstName.nilOrNonEmptyValue,
            lastName: registerRequest.lastName.nilOrNonEmptyValue
        )

        // 4. Create user account (handles unique email constraint)
        do {
            try await req.repositories.users.create(user)
        } catch {
            // Check if this is a unique constraint failure for email
            // Use String(reflecting:) to get the full error details for proper matching
            let errorString = String(reflecting: error)

            // Check for PostgreSQL unique constraint violation (code 23505) for email
            // Look for key indicators: sqlState code, constraint name, or column reference
            let isPostgreSQLDuplicateEmail = errorString.contains("sqlState: 23505") &&
                (errorString.contains("uq:users.email") ||
                 errorString.contains("Key (email)") ||
                 errorString.contains("duplicate key") && errorString.contains("email"))

            // Check for SQLite unique constraint failures
            let isSQLiteDuplicateEmail = errorString.contains("UNIQUE constraint failed: users.email")

            if isPostgreSQLDuplicateEmail || isSQLiteDuplicateEmail {
                throw AuthenticationError.emailAlreadyExists
            }

            throw error
        }

        // 5. Generate refresh token for immediate authentication
        let tokenValue = req.services.randomGenerator.generate(bits: 256)
        let userID = try user.requireID()
        let refreshToken = RefreshTokenModel(
            value: SHA256.hash(tokenValue),
            userID: userID
        )
        try await req.repositories.refreshTokens.create(refreshToken)

        // 6. Return HTTP response
        return Auth.SignUp.Response(
            token: try .init(token: tokenValue, user: user, on: req),
            user: try .init(from: user)
        )
    }
    
    func refreshAccessToken(_ req: Request) async throws -> Auth.TokenRefresh.Response {
        // 1. Decode request (HTTP concern)
        let accessTokenRequest = try req.content.decode(Auth.TokenRefresh.Request.self)

        // 2. Hash the refresh token for lookup (tokens are stored hashed)
        let hashedRefreshToken = SHA256.hash(accessTokenRequest.refreshToken)

        // 3. Find the refresh token in the database
        guard let storedToken = try await req.repositories.refreshTokens.find(token: hashedRefreshToken) else {
            throw AuthenticationError.refreshTokenOrUserNotFound
        }

        // 4. Check if token has expired
        guard storedToken.expiresAt > .now else {
            throw AuthenticationError.refreshTokenHasExpired
        }

        // 5. Find the associated user
        guard let user = try await req.repositories.users.find(id: storedToken.$user.id) else {
            throw UserError.userNotFound
        }

        // 6. Delete old refresh token (single-use security)
        try await req.repositories.refreshTokens.delete(id: storedToken.requireID())

        // 7. Generate new refresh token
        let newRefreshTokenValue = req.services.randomGenerator.generate(bits: 256)
        let newRefreshToken = try RefreshTokenModel(
            value: SHA256.hash(newRefreshTokenValue),
            userID: user.requireID()
        )
        try await req.repositories.refreshTokens.create(newRefreshToken)

        // 8. Generate new JWT access token
        let tokenPayload = try TokenPayload(with: user)
        let accessToken = try req.jwt.sign(tokenPayload)

        // 9. Return HTTP response
        return Auth.TokenRefresh.Response(
            refreshToken: newRefreshTokenValue,
            accessToken: accessToken
        )
    }
    
    func logout(_ req: Request) async throws -> HTTPStatus {
        // 1. Extract authenticated user (HTTP concern)
        let user = try req.auth.require(UserAccountModel.self)

        // 2. Business logic: Clean up all refresh tokens for security
        try await req.repositories.refreshTokens.delete(forUserID: user.requireID())

        // 3. Handle HTTP authentication state (HTTP concern)
        req.auth.logout(UserAccountModel.self)

        // 4. Return HTTP response
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

// MARK: - Helper Extensions

private extension Optional where Wrapped == String {
    /// Returns nil if the string is nil or empty/whitespace-only, otherwise returns the trimmed string.
    var nilOrNonEmptyValue: String? {
        guard let self else { return nil }
        let trimmed = self.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

