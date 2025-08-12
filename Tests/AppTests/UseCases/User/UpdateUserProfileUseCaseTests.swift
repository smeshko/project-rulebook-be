import Testing
import Vapor
@testable import App

/// Tests for UpdateUserProfileUseCase demonstrating Command testing patterns in CQRS.
///
/// This test suite validates state-changing operations that modify user profile data.
/// Command testing focuses on state changes, validation, authorization, and proper
/// error handling for various failure scenarios.
final class UpdateUserProfileUseCaseTests {
    
    /// Test successful profile update with all fields.
    @Test("Update user profile modifies all provided fields correctly")
    func testSuccessfulProfileUpdate() async throws {
        // Arrange
        let mockUserRepo = TestUserRepository()
        let useCase = UpdateUserProfileUseCase(userRepository: mockUserRepo)
        
        let originalUser = UserAccountModel(
            email: "original@example.com",
            password: "hashed",
            firstName: "Original",
            lastName: "User",
            isEmailVerified: true
        )
        originalUser.id = UUID()
        mockUserRepo.entities.append(originalUser)
        
        // Act
        let request = UpdateUserProfileUseCase.Request(
            user: originalUser,
            newEmail: "updated@example.com",
            newFirstName: "Updated",
            newLastName: "Name"
        )
        
        let result = try await useCase.execute(request)
        
        // Assert - Response Structure
        #expect(result.user.email == "updated@example.com")
        #expect(result.user.firstName == "Updated")
        #expect(result.user.lastName == "Name")
        #expect(result.success == true)
        
        // Assert - State Change Verification
        #expect(mockUserRepo.updateCalled == true)
        let updatedUser = mockUserRepo.entities.first!
        #expect(updatedUser.email == "updated@example.com")
        #expect(updatedUser.firstName == "Updated")
        #expect(updatedUser.lastName == "Name")
        
        // Assert - Unchanged fields remain the same
        #expect(updatedUser.password == "hashed") // Password unchanged
        #expect(updatedUser.isEmailVerified == true) // Verification status unchanged
    }
    
    /// Test partial profile update (only some fields).
    @Test("Update user profile handles partial updates correctly")
    func testPartialProfileUpdate() async throws {
        // Arrange
        let mockUserRepo = TestUserRepository()
        let useCase = UpdateUserProfileUseCase(userRepository: mockUserRepo)
        
        let user = UserAccountModel(
            email: "partial@example.com",
            password: "hashed",
            firstName: "Original",
            lastName: "User",
            isEmailVerified: true
        )
        user.id = UUID()
        mockUserRepo.entities.append(user)
        
        // Act - Update only first name
        let request = UpdateUserProfileUseCase.Request(
            user: user,
            newEmail: nil, // Don't change email
            newFirstName: "NewFirst",
            newLastName: nil // Don't change last name
        )
        
        let result = try await useCase.execute(request)
        
        // Assert - Only specified field changed
        #expect(result.user.firstName == "NewFirst")
        #expect(result.user.email == "partial@example.com") // Unchanged
        #expect(result.user.lastName == "User") // Unchanged
        
        // Assert - State changes applied
        let updatedUser = mockUserRepo.entities.first!
        #expect(updatedUser.firstName == "NewFirst")
        #expect(updatedUser.email == "partial@example.com")
        #expect(updatedUser.lastName == "User")
    }
    
    /// Test empty string handling in updates.
    @Test("Update user profile handles empty strings appropriately")  
    func testEmptyStringHandling() async throws {
        // Arrange
        let mockUserRepo = TestUserRepository()
        let useCase = UpdateUserProfileUseCase(userRepository: mockUserRepo)
        
        let user = UserAccountModel(
            email: "empty@example.com",
            password: "hashed",
            firstName: "Original",
            lastName: "User",
            isEmailVerified: true
        )
        user.id = UUID()
        mockUserRepo.entities.append(user)
        
        // Act - Provide empty strings
        let updateData = User.Update.Request(
            email: "", // Empty email
            firstName: "   ", // Whitespace only
            lastName: "Valid" // Valid name
        )
        let request = UpdateUserProfileUseCase.Request(
            user: user,
            updateData: updateData
        )
        
        let result = try await useCase.execute(request)
        
        // Assert - Empty strings handled appropriately
        #expect(result.user.email == "empty@example.com") // Email unchanged (empty not allowed)
        #expect(result.user.firstName == nil) // Whitespace converted to nil
        #expect(result.user.lastName == "Valid") // Valid value updated
        
        // Verify state changes
        let updatedUser = mockUserRepo.entities.first!
        #expect(updatedUser.email == "empty@example.com")
        #expect(updatedUser.firstName == nil)
        #expect(updatedUser.lastName == "Valid")
    }
    
    /// Test repository failure handling.
    @Test("Update user profile handles repository failures gracefully")
    func testRepositoryFailureHandling() async throws {
        // Arrange
        let failingUserRepo = FailingUserRepository()
        let useCase = UpdateUserProfileUseCase(userRepository: failingUserRepo)
        
        let user = UserAccountModel(
            email: "failure@example.com",
            password: "hashed",
            isEmailVerified: true
        )
        user.id = UUID()
        
        // Act & Assert
        await #expect(throws: UserError.userNotFound) {
            let updateData = User.Update.Request(
                email: "new@example.com",
                firstName: "New",
                lastName: "User"
            )
            try await useCase.execute(UpdateUserProfileUseCase.Request(
                user: user,
                updateData: updateData
            ))
        }
    }
    
    /// Test command idempotency (calling with same values).
    @Test("Update user profile is idempotent with same values")
    func testCommandIdempotency() async throws {
        // Arrange
        let mockUserRepo = TestUserRepository()
        let useCase = UpdateUserProfileUseCase(userRepository: mockUserRepo)
        
        let user = UserAccountModel(
            email: "idempotent@example.com",
            password: "hashed",
            firstName: "Test",
            lastName: "User",
            isEmailVerified: true
        )
        user.id = UUID()
        mockUserRepo.entities.append(user)
        
        let request = UpdateUserProfileUseCase.Request(
            user: user,
            newEmail: "same@example.com",
            newFirstName: "Same",
            newLastName: "Name"
        )
        
        // Act - Execute command twice with same data
        let result1 = try await useCase.execute(request)
        let result2 = try await useCase.execute(request)
        
        // Assert - Both calls succeed with same result
        #expect(result1.user.email == result2.user.email)
        #expect(result1.user.firstName == result2.user.firstName)
        #expect(result1.user.lastName == result2.user.lastName)
        #expect(result1.success == result2.success)
        
        // Assert - Repository called twice (not cached)
        #expect(mockUserRepo.updateCallCount == 2)
    }
    
    /// Test email validation in updates.
    @Test("Update user profile validates email format")
    func testEmailValidation() async throws {
        // Arrange
        let mockUserRepo = TestUserRepository()
        let useCase = UpdateUserProfileUseCase(userRepository: mockUserRepo)
        
        let user = UserAccountModel(
            email: "valid@example.com",
            password: "hashed",
            isEmailVerified: true
        )
        user.id = UUID()
        mockUserRepo.entities.append(user)
        
        // Act & Assert - Invalid email format
        await #expect(throws: UserError.invalidEmail) {
            try await useCase.execute(UpdateUserProfileUseCase.Request(
                user: user,
                newEmail: "not-an-email", // Invalid format
                newFirstName: "Valid",
                newLastName: "Name"
            ))
        }
    }
    
    /// Test concurrent modification handling.
    @Test("Update user profile handles concurrent modifications")
    func testConcurrentModificationHandling() async throws {
        // Arrange
        let mockUserRepo = TestUserRepository()
        let useCase = UpdateUserProfileUseCase(userRepository: mockUserRepo)
        
        let user = UserAccountModel(
            email: "concurrent@example.com", 
            password: "hashed",
            firstName: "Original",
            lastName: "User",
            isEmailVerified: true
        )
        user.id = UUID()
        mockUserRepo.entities.append(user)
        
        // Simulate concurrent modification by changing the user externally
        let request1 = UpdateUserProfileUseCase.Request(
            user: user,
            newEmail: "first@example.com",
            newFirstName: "First",
            newLastName: nil
        )
        
        let request2 = UpdateUserProfileUseCase.Request(
            user: user,
            newEmail: "second@example.com",
            newFirstName: "Second", 
            newLastName: nil
        )
        
        // Act - Execute concurrently (simulate)
        let result1 = try await useCase.execute(request1)
        let result2 = try await useCase.execute(request2)
        
        // Assert - Both succeed (last write wins in this simple case)
        #expect(result1.success == true)
        #expect(result2.success == true)
        #expect(result2.user.email == "second@example.com") // Last update wins
        #expect(result2.user.firstName == "Second")
    }
    
    /// Test audit trail for commands (state change tracking).
    @Test("Update user profile tracks state changes for audit")
    func testStateChangeAuditTrail() async throws {
        // Arrange
        let trackingUserRepo = TrackingUserRepository()
        let useCase = UpdateUserProfileUseCase(userRepository: trackingUserRepo)
        
        let user = UserAccountModel(
            email: "audit@example.com",
            password: "hashed",
            firstName: "Before",
            lastName: "Update",
            isEmailVerified: true
        )
        user.id = UUID()
        trackingUserRepo.entities.append(user)
        
        // Act
        _ = try await useCase.execute(UpdateUserProfileUseCase.Request(
            user: user,
            newEmail: "after@example.com",
            newFirstName: "After",
            newLastName: "Update"
        ))
        
        // Assert - Changes tracked
        #expect(trackingUserRepo.changeLog.count == 1)
        let change = trackingUserRepo.changeLog.first!
        #expect(change.contains("email: audit@example.com -> after@example.com"))
        #expect(change.contains("firstName: Before -> After"))
    }
}

// MARK: - Test Helpers

/// Mock user repository that always fails for error testing.
private class FailingUserRepository: UserRepository {
    func create(_ user: UserAccountModel) async throws {
        throw UserError.userNotFound
    }
    
    func update(_ user: UserAccountModel) async throws {
        throw UserError.userNotFound
    }
    
    func delete(id: UUID) async throws {
        throw UserError.userNotFound
    }
    
    func find(id: UUID?) async throws -> UserAccountModel? {
        throw UserError.userNotFound
    }
    
    func find(email: String) async throws -> UserAccountModel? {
        throw UserError.userNotFound
    }
    
    func find(appleUserIdentifier: String) async throws -> UserAccountModel? {
        throw UserError.userNotFound
    }
    
    func all() async throws -> [UserAccountModel] {
        throw UserError.userNotFound
    }
    
    func count() async throws -> Int {
        throw UserError.userNotFound
    }
    
    func `for`(_ req: Request) -> FailingUserRepository {
        return self
    }
}

/// Mock user repository that tracks changes for audit testing.
private class TrackingUserRepository: UserRepository {
    var entities: [UserAccountModel] = []
    var changeLog: [String] = []
    
    func update(_ user: UserAccountModel) async throws {
        if let index = entities.firstIndex(where: { $0.id == user.id }) {
            let oldUser = entities[index]
            var changes: [String] = []
            
            if oldUser.email != user.email {
                changes.append("email: \(oldUser.email) -> \(user.email)")
            }
            if oldUser.firstName != user.firstName {
                changes.append("firstName: \(oldUser.firstName ?? "nil") -> \(user.firstName ?? "nil")")
            }
            if oldUser.lastName != user.lastName {
                changes.append("lastName: \(oldUser.lastName ?? "nil") -> \(user.lastName ?? "nil")")
            }
            
            changeLog.append(changes.joined(separator: ", "))
            entities[index] = user
        }
    }
    
    // ... other required methods with basic implementations
    func create(_ user: UserAccountModel) async throws { entities.append(user) }
    func delete(id: UUID) async throws { entities.removeAll { $0.id == id } }
    func find(id: UUID?) async throws -> UserAccountModel? { entities.first { $0.id == id } }
    func find(email: String) async throws -> UserAccountModel? { entities.first { $0.email == email } }
    func find(appleUserIdentifier: String) async throws -> UserAccountModel? { entities.first { $0.appleUserIdentifier == appleUserIdentifier } }
    func all() async throws -> [UserAccountModel] { entities }
    func count() async throws -> Int { entities.count }
    func `for`(_ req: Request) -> TrackingUserRepository { return self }
}

// MARK: - CQRS Command Testing Pattern Note

/*
This test demonstrates Command testing patterns in CQRS:

1. **State Changes**: Commands should modify system state - verify changes occurred
2. **Validation**: Commands should validate input and reject invalid data  
3. **Error Handling**: Commands should handle failures gracefully with proper errors
4. **Idempotency**: Commands should be safe to retry with same parameters
5. **Audit Trail**: Commands should track state changes for compliance/debugging
6. **Authorization**: Commands should enforce proper authorization (tested separately)

These patterns differ from Query testing which focuses on:
- Data accuracy without side effects
- Response formatting
- Performance optimization
- Read-only operations
*/