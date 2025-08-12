import Testing
import Vapor
@testable import App

/// Tests for GetCurrentUserUseCase demonstrating Query testing patterns in CQRS.
///
/// This test suite validates read-only operations that should be side-effect free
/// and safe to execute multiple times. Query testing focuses on data retrieval
/// accuracy and proper response formatting.
final class GetCurrentUserUseCaseTests {
    
    /// Test successful user profile retrieval.
    @Test("Get current user returns properly formatted user profile")
    func testSuccessfulUserRetrieval() async throws {
        // Arrange
        let useCase = GetCurrentUserUseCase()
        
        let user = UserAccountModel(
            email: "test@example.com",
            password: "hashed_password",
            firstName: "John",
            lastName: "Doe",
            isEmailVerified: true
        )
        user.id = UUID()
        user.isAdmin = false
        
        // Act
        let result = try await useCase.execute(GetCurrentUserUseCase.Request(user: user))
        
        // Assert - Response Structure
        #expect(result.user.id != nil)
        #expect(result.user.email == "test@example.com")
        #expect(result.user.firstName == "John")
        #expect(result.user.lastName == "Doe")
        #expect(result.user.isAdmin == false)
        #expect(result.user.isEmailVerified == true)
        
        // Assert - Sensitive data not exposed
        // Password should not be in the response (GetCurrentUserUseCase.Response.User doesn't include it)
    }
    
    /// Test user profile with minimal data.
    @Test("Get current user handles users with minimal profile data")
    func testMinimalUserProfile() async throws {
        // Arrange
        let useCase = GetCurrentUserUseCase()
        
        let minimalUser = UserAccountModel(
            email: "minimal@example.com",
            password: "hashed",
            firstName: nil, // No first name
            lastName: nil,  // No last name
            isEmailVerified: false
        )
        minimalUser.id = UUID()
        
        // Act
        let result = try await useCase.execute(GetCurrentUserUseCase.Request(user: minimalUser))
        
        // Assert
        #expect(result.user.email == "minimal@example.com")
        #expect(result.user.firstName == nil)
        #expect(result.user.lastName == nil)
        #expect(result.user.isEmailVerified == false)
        #expect(result.user.isAdmin == false) // Default value
    }
    
    /// Test admin user profile.
    @Test("Get current user properly identifies admin users")
    func testAdminUserProfile() async throws {
        // Arrange
        let useCase = GetCurrentUserUseCase()
        
        let adminUser = UserAccountModel(
            email: "admin@example.com",
            password: "hashed",
            firstName: "Admin",
            lastName: "User",
            isAdmin: true,
            isEmailVerified: true
        )
        adminUser.id = UUID()
        
        // Act
        let result = try await useCase.execute(GetCurrentUserUseCase.Request(user: adminUser))
        
        // Assert
        #expect(result.user.isAdmin == true)
        #expect(result.user.email == "admin@example.com")
    }
    
    /// Test that the use case is side-effect free (Query characteristic).
    @Test("Get current user is side-effect free and idempotent")
    func testSideEffectFreeOperation() async throws {
        // Arrange
        let useCase = GetCurrentUserUseCase()
        let user = UserAccountModel(
            email: "test@example.com",
            password: "hashed",
            firstName: "Test",
            lastName: "User",
            isEmailVerified: true
        )
        user.id = UUID()
        
        let request = GetCurrentUserUseCase.Request(user: user)
        
        // Act - Call multiple times
        let result1 = try await useCase.execute(request)
        let result2 = try await useCase.execute(request)
        let result3 = try await useCase.execute(request)
        
        // Assert - Results are identical (idempotent)
        #expect(result1.user.id == result2.user.id)
        #expect(result1.user.id == result3.user.id)
        #expect(result1.user.email == result2.user.email)
        #expect(result1.user.email == result3.user.email)
        
        // Assert - No side effects on original user object
        #expect(user.email == "test@example.com") // Unchanged
    }
    
    /// Test user with Apple Sign-In profile.
    @Test("Get current user handles Apple Sign-In users")
    func testAppleSignInUser() async throws {
        // Arrange
        let useCase = GetCurrentUserUseCase()
        
        let appleUser = UserAccountModel(
            email: "apple@icloud.com",
            password: nil, // Apple users don't have passwords
            firstName: "Apple",
            lastName: "User",
            appleUserIdentifier: "apple_test_id_123",
            isEmailVerified: true
        )
        appleUser.id = UUID()
        
        // Act
        let result = try await useCase.execute(GetCurrentUserUseCase.Request(user: appleUser))
        
        // Assert
        #expect(result.user.email == "apple@icloud.com")
        #expect(result.user.firstName == "Apple")
        #expect(result.user.lastName == "User")
        #expect(result.user.isEmailVerified == true)
        
        // Note: appleUserIdentifier is not exposed in the response for security
    }
    
    /// Test response serialization structure.
    @Test("Get current user response has correct structure")
    func testResponseStructure() async throws {
        // Arrange
        let useCase = GetCurrentUserUseCase()
        let user = UserAccountModel(
            email: "structure@example.com",
            password: "hashed",
            firstName: "Structure",
            lastName: "Test",
            isEmailVerified: true
        )
        user.id = UUID()
        user.createdAt = Date()
        user.updatedAt = Date()
        
        // Act
        let result = try await useCase.execute(GetCurrentUserUseCase.Request(user: user))
        
        // Assert - Expected fields present
        #expect(result.user.id != nil)
        #expect(result.user.email.count > 0)
        #expect(result.user.firstName != nil)
        #expect(result.user.lastName != nil)
        
        // Assert - Response type is correct
        #expect(type(of: result) == GetCurrentUserUseCase.Response.self)
        #expect(type(of: result.user) == GetCurrentUserUseCase.Response.User.self)
    }
    
    /// Test performance characteristics of query operation.
    @Test("Get current user executes quickly for query performance")
    func testQueryPerformance() async throws {
        // Arrange
        let useCase = GetCurrentUserUseCase()
        let user = UserAccountModel(
            email: "performance@example.com",
            password: "hashed",
            firstName: "Performance",
            lastName: "Test",
            isEmailVerified: true
        )
        user.id = UUID()
        
        let request = GetCurrentUserUseCase.Request(user: user)
        
        // Act & Assert - Should execute very quickly since it's just data transformation
        let startTime = Date()
        
        for _ in 1...100 {
            _ = try await useCase.execute(request)
        }
        
        let executionTime = Date().timeIntervalSince(startTime)
        
        // Should complete 100 iterations in well under 1 second
        #expect(executionTime < 1.0)
    }
}

// MARK: - CQRS Testing Pattern Note

/*
This test demonstrates Query testing patterns in CQRS:

1. **Side-Effect Free**: Queries should not modify any state
2. **Idempotent**: Multiple executions should return identical results  
3. **Fast Execution**: Queries should be optimized for read performance
4. **Data Accuracy**: Focus on correct data retrieval and formatting
5. **Security**: Ensure sensitive data is not exposed in responses

These patterns differ from Command testing which focuses on:
- State changes
- Authorization
- Validation
- Error handling for failures
- Audit logging
*/