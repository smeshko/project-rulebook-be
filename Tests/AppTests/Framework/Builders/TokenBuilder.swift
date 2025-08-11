@testable import App
import Foundation
import Vapor

/// Builder pattern for creating token model instances in tests.
///
/// This builder provides a fluent interface for creating test tokens (refresh, email, password)
/// with custom properties, making test code more readable and maintainable.
///
/// ## Usage
/// ```swift
/// let refreshToken = try TokenBuilder(app: app)
///     .userId(userId)
///     .token("test_token_value")
///     .expiresIn(hours: 24)
///     .buildRefreshToken()
/// ```
final class TokenBuilder {
    private let app: Application
    
    // Common token properties
    private var id: UUID?
    private var userId: UUID?
    private var tokenValue: String = "default_test_token"
    private var expiresAt: Date?
    private var createdAt: Date?
    private var updatedAt: Date?
    private var deletedAt: Date?
    
    /// Initialize the builder with an application instance.
    init(app: Application) {
        self.app = app
    }
    
    // MARK: - Builder Methods
    
    /// Set the token ID.
    func id(_ id: UUID?) -> Self {
        self.id = id
        return self
    }
    
    /// Set the user ID this token belongs to.
    func userId(_ userId: UUID) -> Self {
        self.userId = userId
        return self
    }
    
    /// Set the token value.
    func token(_ value: String) -> Self {
        self.tokenValue = value
        return self
    }
    
    /// Set the exact expiration date.
    func expiresAt(_ date: Date) -> Self {
        self.expiresAt = date
        return self
    }
    
    /// Set the creation timestamp.
    func createdAt(_ date: Date?) -> Self {
        self.createdAt = date
        return self
    }
    
    /// Set the last update timestamp.
    func updatedAt(_ date: Date?) -> Self {
        self.updatedAt = date
        return self
    }
    
    /// Set the deletion timestamp (for soft deletes).
    func deletedAt(_ date: Date?) -> Self {
        self.deletedAt = date
        return self
    }
    
    // MARK: - Convenience Methods
    
    /// Set expiration time relative to now in hours.
    func expiresIn(hours: Double) -> Self {
        self.expiresAt = Date().addingTimeInterval(hours * 3600)
        return self
    }
    
    /// Set expiration time relative to now in minutes.
    func expiresIn(minutes: Double) -> Self {
        self.expiresAt = Date().addingTimeInterval(minutes * 60)
        return self
    }
    
    /// Set expiration time relative to now in days.
    func expiresIn(days: Double) -> Self {
        self.expiresAt = Date().addingTimeInterval(days * 24 * 3600)
        return self
    }
    
    /// Configure the token as expired.
    func asExpired() -> Self {
        self.expiresAt = Date().addingTimeInterval(-3600) // 1 hour ago
        return self
    }
    
    /// Configure the token as deleted.
    func asDeleted(deletedAt: Date = Date()) -> Self {
        return self.deletedAt(deletedAt)
    }
    
    /// Configure with a secure random token value.
    func withSecureToken() -> Self {
        self.tokenValue = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        return self
    }
    
    // MARK: - Build Methods for Different Token Types
    
    /// Build a RefreshTokenModel instance.
    ///
    /// - Returns: A configured RefreshTokenModel
    /// - Throws: Any errors from model creation
    func buildRefreshToken() throws -> RefreshTokenModel {
        guard let userId = userId else {
            throw TokenBuilderError.missingUserId
        }
        
        let token = RefreshTokenModel()
        token.id = id
        token.$user.id = userId
        token.value = tokenValue
        token.expiresAt = expiresAt ?? Date().addingTimeInterval(7 * 24 * 3600) // 7 days default
        
        // Set timestamps if provided
        if let createdAt = createdAt {
            token.createdAt = createdAt
        }
        
        if let updatedAt = updatedAt {
            token.updatedAt = updatedAt
        }
        
        if let deletedAt = deletedAt {
            token.deletedAt = deletedAt
        }
        
        return token
    }
    
    /// Build an EmailTokenModel instance.
    ///
    /// - Returns: A configured EmailTokenModel
    /// - Throws: Any errors from model creation
    func buildEmailToken() throws -> EmailTokenModel {
        guard let userId = userId else {
            throw TokenBuilderError.missingUserId
        }
        
        let token = EmailTokenModel()
        token.id = id
        token.$user.id = userId
        token.value = tokenValue
        token.expiresAt = expiresAt ?? Date().addingTimeInterval(15 * 60) // 15 minutes default
        
        // Set timestamps if provided
        if let createdAt = createdAt {
            token.createdAt = createdAt
        }
        
        if let updatedAt = updatedAt {
            token.updatedAt = updatedAt
        }
        
        if let deletedAt = deletedAt {
            token.deletedAt = deletedAt
        }
        
        return token
    }
    
    /// Build a PasswordTokenModel instance.
    ///
    /// - Returns: A configured PasswordTokenModel
    /// - Throws: Any errors from model creation
    func buildPasswordToken() throws -> PasswordTokenModel {
        guard let userId = userId else {
            throw TokenBuilderError.missingUserId
        }
        
        let token = PasswordTokenModel()
        token.id = id
        token.$user.id = userId
        token.value = tokenValue
        token.expiresAt = expiresAt ?? Date().addingTimeInterval(3600) // 1 hour default
        
        // Set timestamps if provided
        if let createdAt = createdAt {
            token.createdAt = createdAt
        }
        
        if let updatedAt = updatedAt {
            token.updatedAt = updatedAt
        }
        
        if let deletedAt = deletedAt {
            token.deletedAt = deletedAt
        }
        
        return token
    }
    
    // MARK: - Build and Save Methods
    
    /// Build and save a refresh token to the database.
    ///
    /// - Returns: The saved RefreshTokenModel with ID assigned
    /// - Throws: Database errors or build errors
    func buildAndSaveRefreshToken() async throws -> RefreshTokenModel {
        let token = try buildRefreshToken()
        try await token.create(on: app.db)
        return token
    }
    
    /// Build and save an email token to the database.
    ///
    /// - Returns: The saved EmailTokenModel with ID assigned
    /// - Throws: Database errors or build errors
    func buildAndSaveEmailToken() async throws -> EmailTokenModel {
        let token = try buildEmailToken()
        try await token.create(on: app.db)
        return token
    }
    
    /// Build and save a password token to the database.
    ///
    /// - Returns: The saved PasswordTokenModel with ID assigned
    /// - Throws: Database errors or build errors
    func buildAndSavePasswordToken() async throws -> PasswordTokenModel {
        let token = try buildPasswordToken()
        try await token.create(on: app.db)
        return token
    }
}

// MARK: - Static Factory Methods

extension TokenBuilder {
    /// Create a refresh token builder with standard defaults.
    static func refreshToken(app: Application, userId: UUID) -> TokenBuilder {
        return TokenBuilder(app: app)
            .userId(userId)
            .token("refresh_\(UUID().uuidString)")
            .expiresIn(days: 7)
    }
    
    /// Create an email verification token builder with standard defaults.
    static func emailToken(app: Application, userId: UUID) -> TokenBuilder {
        return TokenBuilder(app: app)
            .userId(userId)
            .token("email_\(UUID().uuidString)")
            .expiresIn(minutes: 15)
    }
    
    /// Create a password reset token builder with standard defaults.
    static func passwordToken(app: Application, userId: UUID) -> TokenBuilder {
        return TokenBuilder(app: app)
            .userId(userId)
            .token("password_\(UUID().uuidString)")
            .expiresIn(hours: 1)
    }
    
    /// Create an expired token builder for testing expired token scenarios.
    static func expired(app: Application, userId: UUID, type: TokenType) -> TokenBuilder {
        let prefix = type.rawValue
        return TokenBuilder(app: app)
            .userId(userId)
            .token("\(prefix)_expired_\(UUID().uuidString)")
            .asExpired()
    }
}

// MARK: - Supporting Types

enum TokenType: String {
    case refresh = "refresh"
    case email = "email"
    case password = "password"
}

enum TokenBuilderError: Error, LocalizedError {
    case missingUserId
    
    var errorDescription: String? {
        switch self {
        case .missingUserId:
            return "User ID is required but was not provided"
        }
    }
}