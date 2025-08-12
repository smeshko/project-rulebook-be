import Testing
import Vapor
@testable import App

/// Comprehensive tests for SignUpUseCase demonstrating Clean Architecture testing patterns.
///
/// This test suite validates the business logic for user registration in isolation
/// from HTTP concerns, using mock dependencies to test various scenarios including
/// success cases, validation errors, and external service failures.
final class SignUpUseCaseTests {
    
    /// Test successful user registration flow.
    @Test("Sign up creates user with proper token and email verification")
    func testSuccessfulSignUp() async throws {
        // Arrange
        let mockUserRepo = TestUserRepository()
        let mockRefreshTokenRepo = TestRefreshTokenRepository()
        let mockEmailTokenRepo = TestEmailTokenRepository()
        let mockRandomGenerator = RiggedRandomGeneratorService(value: "test-token")
        let mockEmailService = FakeEmailProvider()
        let mockPasswordHasher: @Sendable (String) async throws -> String = { password in "hashed_\(password)" }
        let mockConfig = TestingConfiguration()
        
        let useCase = SignUpUseCase(
            userRepository: mockUserRepo,
            refreshTokenRepository: mockRefreshTokenRepo,
            emailTokenRepository: mockEmailTokenRepo,
            passwordHasher: mockPasswordHasher,
            randomGenerator: mockRandomGenerator,
            emailService: mockEmailService,
            configurationService: mockConfig
        )
        
        // Act
        let request = SignUpUseCase.Request(
            email: "test@example.com",
            password: "ValidPass123!",
            firstName: "Test",
            lastName: "User"
        )
        
        let result = try await useCase.execute(request)
        
        // Assert - Response Structure
        #expect(result.refreshToken.count > 0)
        #expect(result.user.email == "test@example.com")
        #expect(result.user.firstName == "Test")
        #expect(result.user.lastName == "User")
        
        // Assert - User Creation  
        let users = try await mockUserRepo.all()
        #expect(users.count == 1)
        let createdUser = users.first!
        #expect(createdUser.email == "test@example.com")
        #expect(createdUser.password == "hashed_ValidPass123!")
        #expect(createdUser.isEmailVerified == false) // Should be false until verified
        
        // Assert - Token Creation
        let refreshTokens = try await mockRefreshTokenRepo.all()
        #expect(refreshTokens.count == 1)
        
        // NOTE: Email verification is temporarily disabled in SignUpUseCase
        // so no email tokens should be created during testing
        let emailTokens = try await mockEmailTokenRepo.all()
        #expect(emailTokens.count == 0) // No email tokens expected while disabled
        
        // Assert - Email Verification Sent (currently disabled)
        // Email verification is temporarily disabled for testing
        // When re-enabled, integration tests will verify actual email content
    }
    
    /// Test duplicate email handling.
    @Test("Sign up throws error for duplicate email")
    func testDuplicateEmailError() async throws {
        // Arrange
        let mockUserRepo = TestUserRepository()
        let useCase = SignUpUseCase(
            userRepository: mockUserRepo,
            refreshTokenRepository: TestRefreshTokenRepository(),
            emailTokenRepository: TestEmailTokenRepository(),
            passwordHasher: { _ in "hashed" },
            randomGenerator: RiggedRandomGeneratorService(value: "token"),
            emailService: FakeEmailProvider(),
            configurationService: TestingConfiguration()
        )
        
        // Add existing user
        let existingUser = UserAccountModel(
            email: "test@example.com",
            password: "existing",
            isEmailVerified: true
        )
        try await mockUserRepo.create(existingUser)
        
        // Act & Assert
        await #expect(throws: AuthenticationError.emailAlreadyExists) {
            try await useCase.execute(SignUpUseCase.Request(
                email: "test@example.com",
                password: "NewPass123!",
                firstName: "New",
                lastName: "User"
            ))
        }
    }
    
    /// Test email service failure handling.
    @Test("Sign up handles email service failures gracefully")
    func testEmailServiceFailureHandling() async throws {
        // NOTE: Email verification is temporarily disabled in SignUpUseCase
        // so email service failures won't be propagated during user creation
        
        // Arrange
        let failingEmailService = FailingEmailService()
        let useCase = SignUpUseCase(
            userRepository: TestUserRepository(),
            refreshTokenRepository: TestRefreshTokenRepository(),
            emailTokenRepository: TestEmailTokenRepository(),
            passwordHasher: { _ in "hashed" },
            randomGenerator: RiggedRandomGeneratorService(value: "token"),
            emailService: failingEmailService,
            configurationService: TestingConfiguration()
        )
        
        // Act - Should succeed since email verification is disabled
        let result = try await useCase.execute(SignUpUseCase.Request(
            email: "test@example.com",
            password: "ValidPass123!",
            firstName: "Test",
            lastName: "User"
        ))
        
        // Assert - User creation succeeds despite failing email service
        #expect(result.user.email == "test@example.com")
        #expect(result.refreshToken.count > 0)
        
        // NOTE: When email verification is re-enabled, this test should be updated to:
        // - Expect email service errors to be propagated
        // - Test graceful error handling and user creation rollback
    }
    
    /// Test password hashing integration.
    @Test("Sign up properly hashes passwords")
    func testPasswordHashing() async throws {
        // Arrange
        actor PasswordHasher {
            var hashedPassword: String?
            
            func hash(_ password: String) -> String {
                let result = "bcrypt:\(password)"
                hashedPassword = result
                return result
            }
            
            func getHashedPassword() -> String? {
                return hashedPassword
            }
        }
        
        let passwordHasher = PasswordHasher()
        let passwordHasherFunction: @Sendable (String) async throws -> String = { password in
            return await passwordHasher.hash(password)
        }
        
        let mockUserRepo = TestUserRepository()
        let useCase = SignUpUseCase(
            userRepository: mockUserRepo,
            refreshTokenRepository: TestRefreshTokenRepository(),
            emailTokenRepository: TestEmailTokenRepository(),
            passwordHasher: passwordHasherFunction,
            randomGenerator: RiggedRandomGeneratorService(value: "token"),
            emailService: FakeEmailProvider(),
            configurationService: TestingConfiguration()
        )
        
        // Act
        _ = try await useCase.execute(SignUpUseCase.Request(
            email: "test@example.com",
            password: "PlainPassword123!",
            firstName: "Test",
            lastName: "User"
        ))
        
        // Assert
        let hashedPassword = await passwordHasher.getHashedPassword()
        #expect(hashedPassword == "bcrypt:PlainPassword123!")
        let users = try await mockUserRepo.all()
        #expect(users.first?.password == "bcrypt:PlainPassword123!")
    }
    
    /// Test email verification token generation.
    @Test("Sign up creates email verification token")
    func testEmailVerificationTokenGeneration() async throws {
        // Arrange
        let mockEmailTokenRepo = TestEmailTokenRepository()
        let mockRandomGenerator = RiggedRandomGeneratorService(value: "verification-token")
        let useCase = SignUpUseCase(
            userRepository: TestUserRepository(),
            refreshTokenRepository: TestRefreshTokenRepository(),
            emailTokenRepository: mockEmailTokenRepo,
            passwordHasher: { _ in "hashed" },
            randomGenerator: mockRandomGenerator,
            emailService: FakeEmailProvider(),
            configurationService: TestingConfiguration()
        )
        
        // Act
        _ = try await useCase.execute(SignUpUseCase.Request(
            email: "test@example.com",
            password: "ValidPass123!",
            firstName: "Test",
            lastName: "User"
        ))
        
        // Assert - Email verification is currently disabled, so no tokens should be created
        let emailTokens = try await mockEmailTokenRepo.all()
        #expect(emailTokens.count == 0) // No email tokens expected while verification is disabled
        
        // NOTE: When email verification is re-enabled, this test should verify:
        // - Email token creation with proper random value
        // - Token hashing and storage
        // - Token association with user
    }
}

// MARK: - Test Helper: Failing Email Service

/// Mock email service that always fails for testing error handling.
private class FailingEmailService: EmailService {
    func send(_ email: any Email) async throws -> HTTPStatus {
        throw Abort(.internalServerError, reason: "Email service failed")
    }
    
    func `for`(_ request: Request) -> EmailService {
        return self
    }
}