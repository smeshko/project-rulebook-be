@testable import App
import Foundation
import Vapor

/// Builder pattern for creating UserAccountModel instances in tests.
///
/// This builder provides a fluent interface for creating test users with
/// custom properties, making test code more readable and maintainable.
///
/// ## Usage
/// ```swift
/// let user = try UserBuilder(app: app)
///     .email("test@example.com")
///     .firstName("John")
///     .lastName("Doe")
///     .isAdmin(true)
///     .build()
/// ```
final class UserBuilder {
    private let app: Application
    
    // User properties with defaults
    private var id: UUID?
    private var email: String = "test@example.com"
    private var password: String? = "password123"
    private var firstName: String? = "Test"
    private var lastName: String? = "User"
    private var appleUserIdentifier: String?
    private var isAdmin: Bool = false
    private var isEmailVerified: Bool = true
    private var avatar: UUID?
    private var createdAt: Date?
    private var updatedAt: Date?
    private var deletedAt: Date?
    
    /// Initialize the builder with an application instance.
    init(app: Application) {
        self.app = app
    }
    
    // MARK: - Builder Methods
    
    /// Set the user ID.
    func id(_ id: UUID?) -> Self {
        self.id = id
        return self
    }
    
    /// Set the user's email address.
    func email(_ email: String) -> Self {
        self.email = email
        return self
    }
    
    /// Set the user's password (will be hashed).
    func password(_ password: String?) -> Self {
        self.password = password
        return self
    }
    
    /// Set the user's first name.
    func firstName(_ firstName: String?) -> Self {
        self.firstName = firstName
        return self
    }
    
    /// Set the user's last name.
    func lastName(_ lastName: String?) -> Self {
        self.lastName = lastName
        return self
    }
    
    /// Set the Apple User Identifier for Sign in with Apple.
    func appleUserIdentifier(_ identifier: String?) -> Self {
        self.appleUserIdentifier = identifier
        return self
    }
    
    /// Set whether the user is an administrator.
    func isAdmin(_ isAdmin: Bool) -> Self {
        self.isAdmin = isAdmin
        return self
    }
    
    /// Set whether the user's email is verified.
    func isEmailVerified(_ isVerified: Bool) -> Self {
        self.isEmailVerified = isVerified
        return self
    }
    
    /// Set the user's avatar UUID.
    func avatar(_ avatar: UUID?) -> Self {
        self.avatar = avatar
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
    
    /// Configure the user as an admin with email verified.
    func asAdmin() -> Self {
        return isAdmin(true).isEmailVerified(true)
    }
    
    /// Configure the user as unverified (new user).
    func asUnverified() -> Self {
        return isEmailVerified(false)
    }
    
    /// Configure the user with Apple Sign-In.
    func withAppleSignIn(identifier: String = "apple_test_id") -> Self {
        return appleUserIdentifier(identifier).password(nil) // Apple users don't have passwords
    }
    
    /// Configure the user as deleted.
    func asDeleted(deletedAt: Date = Date()) -> Self {
        return self.deletedAt(deletedAt)
    }
    
    /// Configure with full name.
    func fullName(first: String, last: String) -> Self {
        return firstName(first).lastName(last)
    }
    
    /// Configure with sequential naming for batch creation.
    func sequential(index: Int, prefix: String = "user") -> Self {
        return email("\(prefix)\(index)@example.com")
            .firstName("User")
            .lastName("\(index)")
    }
    
    // MARK: - Build Methods
    
    /// Build the UserAccountModel instance.
    ///
    /// - Returns: A configured UserAccountModel
    /// - Throws: Any errors from password hashing or model creation
    func build() throws -> UserAccountModel {
        let hashedPassword: String?
        
        if let password = password {
            hashedPassword = try app.password.hash(password)
        } else {
            hashedPassword = nil
        }
        
        let user = UserAccountModel(
            id: id,
            email: email,
            password: hashedPassword,
            firstName: firstName,
            lastName: lastName,
            appleUserIdentifier: appleUserIdentifier,
            avatar: avatar,
            isAdmin: isAdmin,
            isEmailVerified: isEmailVerified
        )
        
        // Set timestamps if provided
        if let createdAt = createdAt {
            user.createdAt = createdAt
        }
        
        if let updatedAt = updatedAt {
            user.updatedAt = updatedAt
        }
        
        if let deletedAt = deletedAt {
            user.deletedAt = deletedAt
        }
        
        return user
    }
    
    /// Build and save the user to the database.
    ///
    /// - Returns: The saved UserAccountModel with ID assigned
    /// - Throws: Database errors or build errors
    func buildAndSave() async throws -> UserAccountModel {
        let user = try build()
        try await user.create(on: app.db)
        return user
    }
}

// MARK: - Static Factory Methods

extension UserBuilder {
    /// Create a standard test user builder.
    static func standard(app: Application) -> UserBuilder {
        return UserBuilder(app: app)
            .email("test@example.com")
            .firstName("Test")
            .lastName("User")
            .isEmailVerified(true)
    }
    
    /// Create an admin user builder.
    static func admin(app: Application) -> UserBuilder {
        return UserBuilder(app: app)
            .email("admin@example.com")
            .firstName("Admin")
            .lastName("User")
            .asAdmin()
    }
    
    /// Create an unverified user builder.
    static func unverified(app: Application) -> UserBuilder {
        return UserBuilder(app: app)
            .email("unverified@example.com")
            .firstName("New")
            .lastName("User")
            .asUnverified()
    }
}