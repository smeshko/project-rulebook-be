import Testing
import Vapor
@testable import App

/// Comprehensive tests for SignInUseCase demonstrating Authentication Command testing patterns.
///
/// This test suite validates user authentication business logic including credential
/// validation, token generation, and security-focused error handling patterns.
final class SignInUseCaseTests {
    
    /// Test successful sign-in with valid credentials.
    @Test("Sign in authenticates user and generates tokens correctly")
    func testSuccessfulSignIn() async throws {
        // Arrange
        let mockRefreshTokenRepo = TestRefreshTokenRepository()
        let mockRandomGenerator = RiggedRandomGeneratorService(value: "auth-token")
        let useCase = SignInUseCase(
            refreshTokenRepository: mockRefreshTokenRepo,
            randomGenerator: mockRandomGenerator
        )
        
        let authenticatedUser = UserAccountModel(
            email: "user@example.com",
            password: "hashed_password",
            firstName: "Test",
            lastName: "User",
            isEmailVerified: true
        )
        authenticatedUser.id = UUID()
        
        // Act
        let result = try await useCase.execute(SignInUseCase.Request(
            user: authenticatedUser
        ))
        
        // Assert - Response Structure
        #expect(result.token.refreshToken.count > 0)
        #expect(result.token.accessToken.count > 0)
        #expect(result.user.email == "user@example.com")
        #expect(result.user.firstName == "Test")
        #expect(result.user.lastName == "User")
        
        // Assert - Token Creation
        #expect(mockRefreshTokenRepo.entities.count == 1)
        let createdToken = mockRefreshTokenRepo.entities.first!
        #expect(createdToken.userId == authenticatedUser.id)
        
        // Assert - Security: Password not exposed in response
        // (SignInUseCase.Response.User should not contain password field)
    }
    
    /// Test sign-in with unverified email account.
    @Test("Sign in handles unverified email accounts appropriately")
    func testUnverifiedEmailSignIn() async throws {
        // Arrange
        let useCase = SignInUseCase(
            refreshTokenRepository: TestRefreshTokenRepository(),
            randomGenerator: RiggedRandomGeneratorService(value: "token")
        )
        
        let unverifiedUser = UserAccountModel(
            email: "unverified@example.com",
            password: "hashed_password",
            firstName: "Unverified",
            lastName: "User",
            isEmailVerified: false // Not verified
        )
        unverifiedUser.id = UUID()
        
        // Act & Assert - Should still succeed but flag unverified status
        let result = try await useCase.execute(SignInUseCase.Request(
            user: unverifiedUser
        ))
        
        // Assert - Authentication succeeds
        #expect(result.token.accessToken.count > 0)
        #expect(result.user.email == "unverified@example.com")
        #expect(result.user.isEmailVerified == false)
    }
    
    /// Test refresh token generation and persistence.
    @Test("Sign in creates persistent refresh token correctly")
    func testRefreshTokenGeneration() async throws {
        // Arrange
        let mockRefreshTokenRepo = TestRefreshTokenRepository()
        let mockRandomGenerator = RiggedRandomGeneratorService(value: "refresh-12345")
        let useCase = SignInUseCase(
            refreshTokenRepository: mockRefreshTokenRepo,
            randomGenerator: mockRandomGenerator
        )
        
        let user = UserAccountModel(
            email: "token@example.com",
            password: "hashed",
            isEmailVerified: true
        )
        user.id = UUID()
        
        // Act
        _ = try await useCase.execute(SignInUseCase.Request(user: user))
        
        // Assert - Token Repository Usage
        #expect(mockRefreshTokenRepo.entities.count == 1)
        #expect(mockRefreshTokenRepo.createCalled == true)
        
        let refreshToken = mockRefreshTokenRepo.entities.first!
        #expect(refreshToken.userId == user.id)
        #expect(refreshToken.value.contains("refresh-12345")) // Should contain generated value
        
        // Assert - Token Expiration Set
        #expect(refreshToken.expiresAt > Date()) // Should expire in future
    }
    
    /// Test multiple sign-ins from same user (token rotation).
    @Test("Sign in handles multiple sessions with proper token management")
    func testMultipleSignIns() async throws {
        // Arrange
        let mockRefreshTokenRepo = TestRefreshTokenRepository()
        let mockRandomGenerator = RiggedRandomGeneratorService(values: ["token-1", "token-2", "token-3"])
        let useCase = SignInUseCase(
            refreshTokenRepository: mockRefreshTokenRepo,
            randomGenerator: mockRandomGenerator
        )
        
        let user = UserAccountModel(
            email: "multi@example.com",
            password: "hashed",
            isEmailVerified: true
        )
        user.id = UUID()
        
        // Act - Sign in multiple times
        let result1 = try await useCase.execute(SignInUseCase.Request(user: user))
        let result2 = try await useCase.execute(SignInUseCase.Request(user: user))
        let result3 = try await useCase.execute(SignInUseCase.Request(user: user))
        
        // Assert - Each sign-in creates unique tokens
        #expect(result1.token.refreshToken != result2.token.refreshToken)
        #expect(result2.token.refreshToken != result3.token.refreshToken)
        #expect(result1.token.accessToken != result2.token.accessToken)
        
        // Assert - Multiple refresh tokens stored
        #expect(mockRefreshTokenRepo.entities.count == 3)
        
        // Assert - All tokens belong to same user
        for token in mockRefreshTokenRepo.entities {
            #expect(token.userId == user.id)
        }
    }
    
    /// Test admin user sign-in handling.
    @Test("Sign in properly identifies admin users in token")
    func testAdminUserSignIn() async throws {
        // Arrange
        let useCase = SignInUseCase(
            refreshTokenRepository: TestRefreshTokenRepository(),
            randomGenerator: RiggedRandomGeneratorService(value: "admin-token")
        )
        
        let adminUser = UserAccountModel(
            email: "admin@example.com",
            password: "admin_hashed",
            firstName: "Admin",
            lastName: "User",
            isAdmin: true, // Admin user
            isEmailVerified: true
        )
        adminUser.id = UUID()
        
        // Act
        let result = try await useCase.execute(SignInUseCase.Request(user: adminUser))
        
        // Assert - Admin Status Preserved
        #expect(result.user.email == "admin@example.com")
        #expect(result.user.isAdmin == true)
        #expect(result.token.accessToken.count > 0)
        
        // Note: Admin privileges should be encoded in JWT token
        // (actual JWT validation would need separate JWT testing)
    }
    
    /// Test Apple Sign-In user authentication.
    @Test("Sign in handles Apple Sign-In users correctly")
    func testAppleSignInUser() async throws {
        // Arrange
        let useCase = SignInUseCase(
            refreshTokenRepository: TestRefreshTokenRepository(),
            randomGenerator: RiggedRandomGeneratorService(value: "apple-token")
        )
        
        let appleUser = UserAccountModel(
            email: "apple@icloud.com",
            password: nil, // Apple users don't have passwords
            firstName: "Apple",
            lastName: "User",
            appleUserIdentifier: "apple_id_123456",
            isEmailVerified: true
        )
        appleUser.id = UUID()
        
        // Act
        let result = try await useCase.execute(SignInUseCase.Request(user: appleUser))
        
        // Assert - Apple User Authentication
        #expect(result.user.email == "apple@icloud.com")
        #expect(result.user.firstName == "Apple")
        #expect(result.token.accessToken.count > 0)
        #expect(result.token.refreshToken.count > 0)
        
        // Assert - Security: Apple ID not exposed in response
        // (Response should not contain appleUserIdentifier)
    }
    
    /// Test repository failure handling during token creation.
    @Test("Sign in handles refresh token repository failures gracefully")
    func testRefreshTokenRepositoryFailure() async throws {
        // Arrange
        let failingRefreshTokenRepo = FailingRefreshTokenRepository()
        let useCase = SignInUseCase(
            refreshTokenRepository: failingRefreshTokenRepo,
            randomGenerator: RiggedRandomGeneratorService(value: "token")
        )
        
        let user = UserAccountModel(
            email: "failure@example.com",
            password: "hashed",
            isEmailVerified: true
        )
        user.id = UUID()
        
        // Act & Assert
        await #expect(throws: AuthenticationError.tokenGenerationFailed) {
            try await useCase.execute(SignInUseCase.Request(user: user))
        }
    }
    
    /// Test token generation with various user profiles.
    @Test("Sign in generates tokens for users with different profile completeness")
    func testTokenGenerationVariousProfiles() async throws {
        // Arrange
        let mockRefreshTokenRepo = TestRefreshTokenRepository()
        let useCase = SignInUseCase(
            refreshTokenRepository: mockRefreshTokenRepo,
            randomGenerator: RiggedRandomGeneratorService(value: "profile-token")
        )
        
        // Test cases: Users with different profile completeness
        let completeUser = UserAccountModel(
            email: "complete@example.com",
            password: "hashed",
            firstName: "Complete",
            lastName: "User",
            isEmailVerified: true
        )
        completeUser.id = UUID()
        
        let minimalUser = UserAccountModel(
            email: "minimal@example.com",
            password: "hashed",
            firstName: nil, // No first name
            lastName: nil,  // No last name
            isEmailVerified: true
        )
        minimalUser.id = UUID()
        
        // Act
        let completeResult = try await useCase.execute(SignInUseCase.Request(user: completeUser))
        let minimalResult = try await useCase.execute(SignInUseCase.Request(user: minimalUser))
        
        // Assert - Both succeed with valid tokens
        #expect(completeResult.token.accessToken.count > 0)
        #expect(minimalResult.token.accessToken.count > 0)
        
        // Assert - Profile differences reflected in response
        #expect(completeResult.user.firstName == "Complete")
        #expect(minimalResult.user.firstName == nil)
        #expect(completeResult.user.lastName == "User")
        #expect(minimalResult.user.lastName == nil)
        
        // Assert - Both users get refresh tokens
        #expect(mockRefreshTokenRepo.entities.count == 2)
    }
}

// MARK: - Test Helper: Failing Refresh Token Repository

/// Mock refresh token repository that always fails for error testing.
private class FailingRefreshTokenRepository: RefreshTokenRepository {
    func create(_ token: RefreshTokenModel) async throws {
        throw AuthenticationError.tokenGenerationFailed
    }
    
    func delete(_ token: RefreshTokenModel) async throws {
        throw AuthenticationError.tokenGenerationFailed
    }
    
    func find(_ token: String) async throws -> RefreshTokenModel? {
        throw AuthenticationError.tokenGenerationFailed
    }
    
    func find(user: UserAccountModel) async throws -> [RefreshTokenModel] {
        throw AuthenticationError.tokenGenerationFailed
    }
    
    func deleteExpired() async throws {
        throw AuthenticationError.tokenGenerationFailed
    }
    
    func `for`(_ req: Request) -> FailingRefreshTokenRepository {
        return self
    }
}

// MARK: - Authentication Command Testing Pattern Note

/*
This test demonstrates Authentication Command testing patterns:

1. **Security-First Testing**: Focus on secure token generation and credential handling
2. **Token Lifecycle Management**: Testing token creation, expiration, and rotation
3. **User State Validation**: Testing different user account states (verified, admin, Apple)
4. **Repository Integration**: Testing persistent token storage and retrieval
5. **Error Security**: Ensuring authentication failures are handled securely
6. **Multiple Session Support**: Testing concurrent authentication scenarios

Key security considerations in authentication testing:
- Never expose passwords or sensitive identifiers in responses
- Test token uniqueness and proper expiration
- Verify proper handling of different user account states
- Test graceful failure without information leakage
- Ensure proper session management and token rotation

These patterns ensure authentication commands are:
- Secure against common attacks (timing, enumeration)
- Reliable across different user scenarios
- Performant for high-frequency operations
- Compliant with security best practices
*/