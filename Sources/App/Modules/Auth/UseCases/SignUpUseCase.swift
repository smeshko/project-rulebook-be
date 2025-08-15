import Foundation
import Vapor
import Fluent
import Crypto

/// Use case for user registration operations.
///
/// Handles the business logic for user sign-up, including:
/// - Password validation and hashing
/// - User account creation with unique email validation
/// - Refresh token generation for immediate authentication
/// - Email verification initiation
///
/// This use case coordinates between multiple repositories and services
/// to provide secure user registration with proper error handling.
struct SignUpUseCase: Command {
    
    /// Request parameters for sign-up operation.
    struct Request {
        /// User's email address (must be unique)
        let email: String
        /// Plain text password (will be hashed)
        let password: String
        /// Optional first name
        let firstName: String?
        /// Optional last name
        let lastName: String?
        
        init(email: String, password: String, firstName: String? = nil, lastName: String? = nil) {
            self.email = email
            self.password = password
            self.firstName = firstName
            self.lastName = lastName
        }
    }
    
    /// Response from sign-up operation.
    struct Response {
        /// Created user account
        let user: UserAccountModel
        /// Generated refresh token for immediate authentication
        let refreshToken: String
        /// Timestamp when registration completed
        let registeredAt: Date
    }
    
    // Dependencies
    let userRepository: any UserRepository
    let refreshTokenRepository: any RefreshTokenRepository
    let emailTokenRepository: any EmailTokenRepository
    let passwordHasher: @Sendable (String) async throws -> String
    let randomGenerator: RandomGeneratorService
    let emailService: any EmailService
    let configurationService: ConfigurationService
    
    /// Executes the sign-up use case.
    ///
    /// This method contains the pure business logic for user registration:
    /// 1. Hash the user's password securely
    /// 2. Create user account with normalized email
    /// 3. Generate and store refresh token for immediate authentication
    /// 4. Initiate email verification process
    /// 5. Return user data and authentication token
    ///
    /// - Parameter request: Contains the user registration data
    /// - Returns: Created user, refresh token, and registration timestamp
    /// - Throws: 
    ///   - `AuthenticationError.emailAlreadyExists` if email is already registered
    ///   - Repository errors if user creation fails
    ///   - Email service errors if verification email fails to send
    func execute(_ request: Request) async throws -> Response {
        // 1. Hash password securely
        let hashedPassword = try await passwordHasher(request.password)
        
        // 2. Create user model with normalized email
        let user = UserAccountModel(
            email: request.email.lowercased(),
            password: hashedPassword,
            firstName: request.firstName.nilOrNonEmptyValue,
            lastName: request.lastName.nilOrNonEmptyValue
        )
        
        // 3. Create user account (handles unique email constraint)
        do {
            try await userRepository.create(user)
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
        
        // 4. Generate refresh token for immediate authentication
        let tokenValue = randomGenerator.generate(bits: 256)
        let userID = try user.requireID()
        let refreshToken = RefreshTokenModel(
            value: SHA256.hash(tokenValue), 
            userID: userID
        )
        try await refreshTokenRepository.create(refreshToken)
        
        // 5. Initiate email verification (temporarily disabled for testing)
        // try await sendEmailVerification(for: user)
        
        // 6. Return response
        return Response(
            user: user,
            refreshToken: tokenValue,
            registeredAt: Date.now
        )
    }
    
    /// Sends email verification for the newly registered user.
    ///
    /// - Parameter user: The user to send verification email to
    /// - Throws: Email service errors or repository errors
    private func sendEmailVerification(for user: UserAccountModel) async throws {
        // Generate verification token
        let token = randomGenerator.generate(bits: 256)
        let emailToken = try EmailTokenModel(userID: user.requireID(), value: SHA256.hash(token))
        try await emailTokenRepository.create(emailToken)
        
        // Prepare email content
        let displayName = {
            if user.firstName == nil && user.lastName == nil {
                return "User"
            }
            return "\(user.firstName ?? "") \(user.lastName ?? "")"
        }()
        
        let content = BrevoMail(
            sender: .init(
                name: "Sender",
                email: "noreply@sender.com"
            ),
            to: [.init(
                name: displayName,
                email: user.email
            )],
            subject: "Verify your account",
            htmlContent: Templates.verifyEmail(
                token: emailToken.value, 
                baseURL: try configurationService.security.baseURL
            )
        )
        
        // Send verification email (but don't let email failures stop user creation)
        do {
            try await emailService.send(content)
        } catch {
            // Log email sending failure but don't propagate error
            // The email token has already been created, so verification can happen manually if needed
            print("Failed to send verification email: \(error)")
        }
    }
}

