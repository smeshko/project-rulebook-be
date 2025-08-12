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
        let mockPasswordHasher = { (password: String) async throws -> String in "hashed_\(password)" }
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
        #expect(result.token.refreshToken.count > 0)
        #expect(result.token.accessToken.count > 0)
        #expect(result.user.email == "test@example.com")
        #expect(result.user.firstName == "Test")
        #expect(result.user.lastName == "User")
        
        // Assert - User Creation
        #expect(mockUserRepo.entities.count == 1)
        let createdUser = mockUserRepo.entities.first!
        #expect(createdUser.email == "test@example.com")
        #expect(createdUser.password == "hashed_ValidPass123!")
        #expect(createdUser.isEmailVerified == false) // Should be false until verified
        
        // Assert - Token Creation
        #expect(mockRefreshTokenRepo.entities.count == 1)
        #expect(mockEmailTokenRepo.entities.count == 1)
        
        // Assert - Email Verification Sent
        #expect(mockEmailService.sentEmails.count == 1)
        #expect(mockEmailService.sentEmails.first?.to == "test@example.com")
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
        mockUserRepo.entities.append(existingUser)
        
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
        
        // Act & Assert - Should propagate email service error
        await #expect(throws: EmailError.sendingFailed) {
            try await useCase.execute(SignUpUseCase.Request(
                email: "test@example.com",
                password: "ValidPass123!",
                firstName: "Test",
                lastName: "User"
            ))
        }
    }
    
    /// Test password hashing integration.
    @Test("Sign up properly hashes passwords")
    func testPasswordHashing() async throws {
        // Arrange
        var hashedPassword: String?
        let passwordHasher = { (password: String) async throws -> String in
            hashedPassword = "bcrypt:\(password)"
            return hashedPassword!
        }
        
        let mockUserRepo = TestUserRepository()
        let useCase = SignUpUseCase(
            userRepository: mockUserRepo,
            refreshTokenRepository: TestRefreshTokenRepository(),
            emailTokenRepository: TestEmailTokenRepository(),
            passwordHasher: passwordHasher,
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
        #expect(hashedPassword == "bcrypt:PlainPassword123!")
        #expect(mockUserRepo.entities.first?.password == "bcrypt:PlainPassword123!")
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
        
        // Assert
        #expect(mockEmailTokenRepo.entities.count == 1)
        let emailToken = mockEmailTokenRepo.entities.first!
        #expect(emailToken.value.contains("verification-token")) // Should contain the generated token hash
    }
}

// MARK: - Test Helper: Failing Email Service

/// Mock email service that always fails for testing error handling.
private class FailingEmailService: EmailService {
    func send(_ email: EmailMessage) async throws {
        throw EmailError.sendingFailed(reason: "Test failure")
    }
}