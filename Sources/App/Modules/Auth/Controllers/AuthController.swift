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
        // TODO: Restore this when Apple use case is properly registered
        throw Abort(.notImplemented, reason: "Apple Sign-In use case temporarily disabled during refactoring")
    }
    
    func signIn(_ req: Request) async throws -> Auth.Login.Response {
        // 1. Extract authenticated user (HTTP concern - middleware already validated credentials)
        let user = try req.auth.require(UserAccountModel.self)
        
        // 2. Execute use case (business logic)
        let signInUseCase = try await req.useCases.auth.signIn
        let result = try await signInUseCase.execute(SignInUseCase.Request(user: user))
        
        // 3. Convert to HTTP response
        return Auth.Login.Response(
            token: try .init(token: result.refreshToken, user: result.user, on: req),
            user: try .init(from: result.user)
        )
    }
    
    func signUp(_ req: Request) async throws -> Auth.SignUp.Response {
        print("DEBUG: SignUp controller called")
        
        // 1. Validate request (HTTP concern)
        try Auth.SignUp.Request.validate(content: req)
        let registerRequest = try req.content.decode(Auth.SignUp.Request.self)
        print("DEBUG: Request decoded successfully: \(registerRequest.email)")
        
        // 2. Execute use case (business logic)
        do {
            let signUpUseCase = try await req.useCases.auth.signUp
            print("DEBUG: Use case resolved successfully")
            
            let result = try await signUpUseCase.execute(SignUpUseCase.Request(
                email: registerRequest.email,
                password: registerRequest.password,
                firstName: registerRequest.firstName,
                lastName: registerRequest.lastName
            ))
            print("DEBUG: Use case executed successfully")
            
            // 3. Convert to HTTP response
            let response = Auth.SignUp.Response(
                token: try .init(token: result.refreshToken, user: result.user, on: req),
                user: try .init(from: result.user)
            )
            print("DEBUG: Response created successfully")
            return response
        } catch {
            print("DEBUG: Error in signup: \(error)")
            throw error
        }
    }
    
    func refreshAccessToken(_ req: Request) async throws -> Auth.TokenRefresh.Response {
        // 1. Decode request (HTTP concern)
        let accessTokenRequest = try req.content.decode(Auth.TokenRefresh.Request.self)
        
        // 2. Execute use case (business logic)
        let refreshTokenUseCase = try await req.useCases.auth.refreshToken
        let result = try await refreshTokenUseCase.execute(RefreshTokenUseCase.Request(
            refreshToken: accessTokenRequest.refreshToken
        ))
        
        // 3. Return HTTP response
        return Auth.TokenRefresh.Response(
            refreshToken: result.refreshToken,
            accessToken: result.accessToken
        )
    }
    
    func logout(_ req: Request) async throws -> HTTPStatus {
        // 1. Extract authenticated user (HTTP concern)
        let user = try req.auth.require(UserAccountModel.self)
        
        // 2. Execute use case (business logic)
        let logoutUseCase = try await req.useCases.auth.logout
        _ = try await logoutUseCase.execute(LogoutUseCase.Request(user: user))
        
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

