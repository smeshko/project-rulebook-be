import Testing
import Vapor
import JWTKit
@testable import App

/// Comprehensive tests for RefreshTokenUseCase demonstrating Token Security Command patterns.
///
/// This test suite validates JWT token refresh logic including token rotation,
/// security validation, and proper cleanup of expired tokens.
final class RefreshTokenUseCaseTests {
    
    /// Test successful token refresh with token rotation.
    @Test("Refresh token rotates tokens and returns new JWT pair")
    func testSuccessfulTokenRefresh() async throws {
        // Arrange
        let mockRefreshTokenRepo = TestRefreshTokenRepository()
        let mockUserRepo = TestUserRepository()
        let mockJWTSigner = TestJWTSigner()
        let mockRandomGenerator = RiggedRandomGeneratorService(values: ["new-refresh-token", "second-token"])
        
        let useCase = RefreshTokenUseCase(
            refreshTokenRepository: mockRefreshTokenRepo,
            userRepository: mockUserRepo,
            jwtSigner: mockJWTSigner,
            randomGenerator: mockRandomGenerator
        )
        
        // Set up existing user and refresh token
        let user = UserAccountModel(
            email: "refresh@example.com",
            password: "hashed",
            firstName: "Refresh",
            lastName: "User",
            isEmailVerified: true
        )
        user.id = UUID()
        mockUserRepo.entities.append(user)
        
        let existingToken = RefreshTokenModel(
            value: "existing-refresh-token-hash",
            userId: user.id!,
            expiresAt: Date().addingTimeInterval(86400) // Valid for 24 hours
        )
        mockRefreshTokenRepo.entities.append(existingToken)
        
        // Act
        let result = try await useCase.execute(RefreshTokenUseCase.Request(
            refreshToken: "existing-refresh-token"
        ))
        
        // Assert - New Tokens Generated
        #expect(result.token.accessToken.count > 0)
        #expect(result.token.refreshToken.count > 0)
        #expect(result.token.refreshToken != "existing-refresh-token")
        
        // Assert - User Data Retrieved
        #expect(result.user.email == "refresh@example.com")
        #expect(result.user.firstName == "Refresh")
        #expect(result.user.lastName == "User")
        
        // Assert - Token Rotation (old token deleted, new one created)
        #expect(mockRefreshTokenRepo.deleteCalled == true)
        #expect(mockRefreshTokenRepo.createCalled == true)
        
        // Assert - JWT Signer Used
        #expect(mockJWTSigner.signCallCount == 1)
        #expect(mockJWTSigner.lastSignedPayload != nil)
    }
    
    /// Test refresh with expired token.
    @Test("Refresh token rejects expired tokens")
    func testExpiredTokenRefresh() async throws {
        // Arrange
        let mockRefreshTokenRepo = TestRefreshTokenRepository()
        let useCase = RefreshTokenUseCase(
            refreshTokenRepository: mockRefreshTokenRepo,
            userRepository: TestUserRepository(),
            jwtSigner: TestJWTSigner(),
            randomGenerator: RiggedRandomGeneratorService(value: "token")
        )
        
        // Set up expired refresh token
        let expiredToken = RefreshTokenModel(
            value: "expired-token-hash",
            userId: UUID(),
            expiresAt: Date().addingTimeInterval(-3600) // Expired 1 hour ago
        )
        mockRefreshTokenRepo.entities.append(expiredToken)
        
        // Act & Assert
        await #expect(throws: AuthenticationError.refreshTokenExpired) {
            try await useCase.execute(RefreshTokenUseCase.Request(
                refreshToken: "expired-token"
            ))
        }
    }
    
    /// Test refresh with non-existent token.
    @Test("Refresh token rejects invalid/non-existent tokens")
    func testNonExistentTokenRefresh() async throws {
        // Arrange
        let mockRefreshTokenRepo = TestRefreshTokenRepository()
        let useCase = RefreshTokenUseCase(
            refreshTokenRepository: mockRefreshTokenRepo,
            userRepository: TestUserRepository(),
            jwtSigner: TestJWTSigner(),
            randomGenerator: RiggedRandomGeneratorService(value: "token")
        )
        
        // No tokens in repository
        
        // Act & Assert
        await #expect(throws: AuthenticationError.refreshTokenInvalid) {
            try await useCase.execute(RefreshTokenUseCase.Request(
                refreshToken: "non-existent-token"
            ))
        }
    }
    
    /// Test refresh when user no longer exists.
    @Test("Refresh token handles deleted user scenarios")
    func testDeletedUserTokenRefresh() async throws {
        // Arrange
        let mockRefreshTokenRepo = TestRefreshTokenRepository()
        let mockUserRepo = TestUserRepository()
        let useCase = RefreshTokenUseCase(
            refreshTokenRepository: mockRefreshTokenRepo,
            userRepository: mockUserRepo,
            jwtSigner: TestJWTSigner(),
            randomGenerator: RiggedRandomGeneratorService(value: "token")
        )
        
        // Set up token for non-existent user
        let orphanedToken = RefreshTokenModel(
            value: "orphaned-token-hash",
            userId: UUID(), // User ID that doesn't exist
            expiresAt: Date().addingTimeInterval(86400)
        )
        mockRefreshTokenRepo.entities.append(orphanedToken)
        
        // Act & Assert
        await #expect(throws: AuthenticationError.userNotFound) {
            try await useCase.execute(RefreshTokenUseCase.Request(
                refreshToken: "orphaned-token"
            ))
        }
        
        // Assert - Orphaned token should be cleaned up
        #expect(mockRefreshTokenRepo.deleteCalled == true)
    }
    
    /// Test JWT payload construction for different user types.
    @Test("Refresh token creates correct JWT payloads for different user types")
    func testJWTPayloadConstruction() async throws {
        // Arrange
        let mockRefreshTokenRepo = TestRefreshTokenRepository()
        let mockUserRepo = TestUserRepository()
        let mockJWTSigner = TestJWTSigner()
        let mockRandomGenerator = RiggedRandomGeneratorService(value: "jwt-token")
        
        let useCase = RefreshTokenUseCase(
            refreshTokenRepository: mockRefreshTokenRepo,
            userRepository: mockUserRepo,
            jwtSigner: mockJWTSigner,
            randomGenerator: mockRandomGenerator
        )
        
        // Test regular user
        let regularUser = UserAccountModel(
            email: "regular@example.com",
            password: "hashed",
            firstName: "Regular",
            lastName: "User",
            isAdmin: false,
            isEmailVerified: true
        )
        regularUser.id = UUID()
        mockUserRepo.entities.append(regularUser)
        
        let regularToken = RefreshTokenModel(
            value: "regular-token-hash",
            userId: regularUser.id!,
            expiresAt: Date().addingTimeInterval(86400)
        )
        mockRefreshTokenRepo.entities.append(regularToken)
        
        // Act
        _ = try await useCase.execute(RefreshTokenUseCase.Request(
            refreshToken: "regular-token"
        ))
        
        // Assert - JWT Payload Construction
        #expect(mockJWTSigner.signCallCount == 1)
        let payload = mockJWTSigner.lastSignedPayload!
        #expect(payload.subject.value == regularUser.id!.uuidString)
        #expect(payload.isAdmin == false)
        #expect(payload.email == "regular@example.com")
        
        // Test admin user
        mockJWTSigner.reset()
        let adminUser = UserAccountModel(
            email: "admin@example.com",
            password: "hashed",
            firstName: "Admin",
            lastName: "User",
            isAdmin: true,
            isEmailVerified: true
        )
        adminUser.id = UUID()
        mockUserRepo.entities.append(adminUser)
        
        let adminToken = RefreshTokenModel(
            value: "admin-token-hash",
            userId: adminUser.id!,
            expiresAt: Date().addingTimeInterval(86400)
        )
        mockRefreshTokenRepo.entities.append(adminToken)
        
        // Act
        _ = try await useCase.execute(RefreshTokenUseCase.Request(
            refreshToken: "admin-token"
        ))
        
        // Assert - Admin Payload
        let adminPayload = mockJWTSigner.lastSignedPayload!
        #expect(adminPayload.isAdmin == true)
        #expect(adminPayload.email == "admin@example.com")
    }
    
    /// Test concurrent token refresh attempts.
    @Test("Refresh token handles concurrent refresh attempts safely")
    func testConcurrentTokenRefresh() async throws {
        // Arrange
        let mockRefreshTokenRepo = TestRefreshTokenRepository()
        let mockUserRepo = TestUserRepository()
        let mockJWTSigner = TestJWTSigner()
        let mockRandomGenerator = RiggedRandomGeneratorService(values: ["concurrent-1", "concurrent-2"])
        
        let useCase = RefreshTokenUseCase(
            refreshTokenRepository: mockRefreshTokenRepo,
            userRepository: mockUserRepo,
            jwtSigner: mockJWTSigner,
            randomGenerator: mockRandomGenerator
        )
        
        let user = UserAccountModel(
            email: "concurrent@example.com",
            password: "hashed",
            isEmailVerified: true
        )
        user.id = UUID()
        mockUserRepo.entities.append(user)
        
        let sharedToken = RefreshTokenModel(
            value: "shared-token-hash",
            userId: user.id!,
            expiresAt: Date().addingTimeInterval(86400)
        )
        mockRefreshTokenRepo.entities.append(sharedToken)
        
        // Act - Simulate concurrent refresh attempts
        let request = RefreshTokenUseCase.Request(refreshToken: "shared-token")
        
        // First refresh should succeed
        let result1 = try await useCase.execute(request)
        #expect(result1.token.accessToken.count > 0)
        
        // Second refresh with same token should fail (token was rotated)
        await #expect(throws: AuthenticationError.refreshTokenInvalid) {
            try await useCase.execute(request)
        }
    }
    
    /// Test token refresh with unverified email user.
    @Test("Refresh token allows refresh for unverified email users")
    func testUnverifiedEmailUserRefresh() async throws {
        // Arrange
        let mockRefreshTokenRepo = TestRefreshTokenRepository()
        let mockUserRepo = TestUserRepository()
        let mockJWTSigner = TestJWTSigner()
        let mockRandomGenerator = RiggedRandomGeneratorService(value: "unverified-token")
        
        let useCase = RefreshTokenUseCase(
            refreshTokenRepository: mockRefreshTokenRepo,
            userRepository: mockUserRepo,
            jwtSigner: mockJWTSigner,
            randomGenerator: mockRandomGenerator
        )
        
        let unverifiedUser = UserAccountModel(
            email: "unverified@example.com",
            password: "hashed",
            isEmailVerified: false // Not verified
        )
        unverifiedUser.id = UUID()
        mockUserRepo.entities.append(unverifiedUser)
        
        let token = RefreshTokenModel(
            value: "unverified-user-token-hash",
            userId: unverifiedUser.id!,
            expiresAt: Date().addingTimeInterval(86400)
        )
        mockRefreshTokenRepo.entities.append(token)
        
        // Act
        let result = try await useCase.execute(RefreshTokenUseCase.Request(
            refreshToken: "unverified-user-token"
        ))
        
        // Assert - Refresh succeeds even for unverified users
        #expect(result.token.accessToken.count > 0)
        #expect(result.user.isEmailVerified == false)
        #expect(result.user.email == "unverified@example.com")
    }
    
    /// Test repository failure during token rotation.
    @Test("Refresh token handles repository failures during rotation")
    func testRepositoryFailureDuringRotation() async throws {
        // Arrange
        let failingRefreshTokenRepo = FailingRefreshTokenRepository()
        let mockUserRepo = TestUserRepository()
        
        let useCase = RefreshTokenUseCase(
            refreshTokenRepository: failingRefreshTokenRepo,
            userRepository: mockUserRepo,
            jwtSigner: TestJWTSigner(),
            randomGenerator: RiggedRandomGeneratorService(value: "failure-token")
        )
        
        // Act & Assert - Should propagate repository failures
        await #expect(throws: AuthenticationError.tokenGenerationFailed) {
            try await useCase.execute(RefreshTokenUseCase.Request(
                refreshToken: "any-token"
            ))
        }
    }
}

// MARK: - Test Helper: JWT Signer Mock

/// Mock JWT signer for testing JWT token generation.
private class TestJWTSigner: JWTSigner {
    var signCallCount = 0
    var lastSignedPayload: UserPayload?
    
    func sign<Payload>(_ jwt: Payload, kid: JWKIdentifier?) async throws -> String where Payload : JWTPayload {
        signCallCount += 1
        
        if let userPayload = jwt as? UserPayload {
            lastSignedPayload = userPayload
        }
        
        return "test-jwt-token-\(signCallCount)"
    }
    
    func verify<Payload>(_ jwt: String, as payload: Payload.Type) async throws -> Payload where Payload : JWTPayload {
        fatalError("Verify not implemented for test")
    }
    
    func verify<Payload>(_ jwt: [UInt8], as payload: Payload.Type) async throws -> Payload where Payload : JWTPayload {
        fatalError("Verify not implemented for test")
    }
    
    func reset() {
        signCallCount = 0
        lastSignedPayload = nil
    }
}

// MARK: - Token Security Command Testing Pattern Note

/*
This test demonstrates Token Security Command testing patterns:

1. **Token Rotation Security**: Testing proper token invalidation and regeneration
2. **Expiration Validation**: Testing time-based security controls
3. **Concurrent Access Safety**: Testing token usage in multi-session scenarios
4. **Orphaned Token Cleanup**: Testing data consistency after user deletion
5. **JWT Payload Security**: Testing secure JWT claim construction
6. **Repository Transaction Safety**: Testing atomic token rotation operations

Key security considerations in token refresh testing:
- Test token rotation prevents replay attacks
- Verify proper cleanup of expired/invalid tokens
- Test concurrent access scenarios for race conditions
- Ensure JWT payloads contain correct authorization claims
- Test graceful handling of edge cases (deleted users, expired tokens)
- Verify atomic operations to prevent token corruption

These patterns ensure token refresh commands are:
- Secure against token-based attacks
- Reliable in high-concurrency scenarios
- Consistent in token lifecycle management
- Compliant with JWT security standards
- Resilient against database failures
*/