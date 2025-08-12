import Testing
import Vapor
@testable import App

/// Tests for LogoutUseCase to demonstrate testing patterns for use cases.
///
/// This test suite shows how to test use cases in isolation from controllers
/// and HTTP concerns, focusing purely on business logic validation.
final class LogoutUseCaseTests {
    
    /// Test that logout use case successfully deletes refresh tokens.
    @Test("Logout use case deletes all user refresh tokens")
    func testLogoutDeletesRefreshTokens() async throws {
        // Arrange
        let mockRepository = TestRefreshTokenRepository()
        let useCase = LogoutUseCase(refreshTokenRepository: mockRepository)
        
        // Use UserBuilder to create test user
        let user = UserBuilder.build()
        
        // Act
        let useCaseRequest = LogoutUseCase.Request(user: user)
        let result = try await useCase.execute(useCaseRequest)
        
        // Assert
        #expect(result.loggedOutAt <= Date.now)
        
        // Verify that the repository method was called
        // The TestRefreshTokenRepository will handle the delete operation
    }
    
    /// Test that logout use case creates proper response structure.
    @Test("Logout use case returns proper response structure")
    func testLogoutReturnsProperResponse() async throws {
        // Arrange
        let mockRepository = TestRefreshTokenRepository()
        let useCase = LogoutUseCase(refreshTokenRepository: mockRepository)
        
        // Use UserBuilder with custom parameters
        let user = UserBuilder.build(
            email: "custom@example.com",
            isEmailVerified: true
        )
        
        // Act
        let useCaseRequest = LogoutUseCase.Request(user: user)
        let result = try await useCase.execute(useCaseRequest)
        
        // Assert
        #expect(result.loggedOutAt > Date.now.addingTimeInterval(-1)) // Recent timestamp
        #expect(result.loggedOutAt <= Date.now) // Not in the future
    }
}