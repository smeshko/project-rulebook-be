@testable import App
import Foundation
import Vapor

/// Main factory for creating test data with consistent defaults and relationships.
///
/// This factory provides a centralized place to create test data objects
/// with sensible defaults and proper relationships between entities.
/// Use this factory to ensure consistent test data across different test suites.
struct TestDataFactory {
    private let app: Application
    
    init(app: Application) {
        self.app = app
    }
    
    // MARK: - User Creation
    
    /// Creates a user builder with default values.
    func user() -> UserBuilder {
        UserBuilder(app: app)
    }
    
    /// Creates a standard test user with common defaults.
    func createUser(
        email: String = "test@example.com",
        firstName: String = "Test",
        lastName: String = "User"
    ) async throws -> UserAccountModel {
        try await user()
            .email(email)
            .firstName(firstName)
            .lastName(lastName)
            .buildAndSave()
    }
    
    /// Creates an admin user for testing administrative functionality.
    func createAdminUser(
        email: String = "admin@example.com",
        firstName: String = "Admin",
        lastName: String = "User"
    ) async throws -> UserAccountModel {
        try await user()
            .email(email)
            .firstName(firstName)
            .lastName(lastName)
            .isAdmin(true)
            .isEmailVerified(true)
            .buildAndSave()
    }
    
    /// Creates an unverified user for testing email verification flows.
    func createUnverifiedUser(
        email: String = "unverified@example.com"
    ) async throws -> UserAccountModel {
        try await user()
            .email(email)
            .isEmailVerified(false)
            .buildAndSave()
    }
    
    // MARK: - Token Creation
    
    /// Creates a token builder with default values.
    func token() -> TokenBuilder {
        TokenBuilder(app: app)
    }
    
    /// Creates a refresh token for a given user.
    func createRefreshToken(
        for user: UserAccountModel,
        token: String = "test_refresh_token"
    ) throws -> RefreshTokenModel {
        guard let userId = user.id else {
            throw TestDataError.missingUserId
        }
        
        return try self.token()
            .userId(userId)
            .token(token)
            .buildRefreshToken()
    }
    
    /// Creates an email verification token for a given user.
    func createEmailToken(
        for user: UserAccountModel,
        token: String = "test_email_token"
    ) throws -> EmailTokenModel {
        guard let userId = user.id else {
            throw TestDataError.missingUserId
        }
        
        return try self.token()
            .userId(userId)
            .token(token)
            .buildEmailToken()
    }
    
    /// Creates a password reset token for a given user.
    func createPasswordToken(
        for user: UserAccountModel,
        token: String = "test_password_token"
    ) throws -> PasswordTokenModel {
        guard let userId = user.id else {
            throw TestDataError.missingUserId
        }
        
        return try self.token()
            .userId(userId)
            .token(token)
            .buildPasswordToken()
    }
    
    // MARK: - Batch Creation Helpers
    
    /// Creates multiple users with sequential email addresses.
    func createUsers(count: Int, emailPrefix: String = "user") async throws -> [UserAccountModel] {
        var users: [UserAccountModel] = []
        
        for i in 1...count {
            let user = try await createUser(
                email: "\(emailPrefix)\(i)@example.com",
                firstName: "User",
                lastName: "\(i)"
            )
            users.append(user)
        }
        
        return users
    }
    
    /// Creates a complete user with associated tokens for testing authentication flows.
    func createUserWithTokens(
        email: String = "test@example.com",
        isVerified: Bool = true
    ) async throws -> UserWithTokens {
        let user = try await createUser(email: email)
        user.isEmailVerified = isVerified
        try await user.save(on: app.db)
        
        let refreshToken = try createRefreshToken(for: user)
        let emailToken = isVerified ? nil : try createEmailToken(for: user)
        
        return UserWithTokens(
            user: user,
            refreshToken: refreshToken,
            emailToken: emailToken
        )
    }
}

// MARK: - Test Data Structures

/// Container for a user with associated tokens.
struct UserWithTokens {
    let user: UserAccountModel
    let refreshToken: RefreshTokenModel
    let emailToken: EmailTokenModel?
}

// MARK: - Test Data Errors

enum TestDataError: Error, LocalizedError {
    case missingUserId
    case invalidTokenType
    
    var errorDescription: String? {
        switch self {
        case .missingUserId:
            return "User ID is required but was nil"
        case .invalidTokenType:
            return "Invalid token type requested"
        }
    }
}