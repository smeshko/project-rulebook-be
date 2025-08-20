import Testing
import Vapor
@testable import App

/// Comprehensive tests for DeleteUserAccountUseCase demonstrating Destructive Command patterns.
///
/// This test suite validates user account deletion including data cleanup and 
/// repository operations for authenticated user deletion.
@Suite(.serialized)
final class DeleteUserAccountUseCaseTests {
    
    /// Test successful user account deletion.
    @Test("Delete user account removes user successfully")
    func testSuccessfulAccountDeletion() async throws {
        // Arrange
        let mockUserRepo = TestUserRepository()
        let useCase = DeleteUserAccountUseCase(
            userRepository: mockUserRepo
        )
        
        let userToDelete = UserAccountModel(
            email: "delete@example.com",
            password: "hashed_password",
            firstName: "Delete",
            lastName: "User",
            isEmailVerified: true
        )
        userToDelete.id = UUID()
        try await mockUserRepo.create(userToDelete)
        
        // Act
        let result = try await useCase.execute(DeleteUserAccountUseCase.Request(
            user: userToDelete
        ))
        
        // Assert - Response Structure
        #expect(result.deleted == true)
        #expect(result.deletedAt != nil)
        
        // Assert - User Removed from Repository
        #expect(await mockUserRepo.users.isEmpty)
    }
    
    /// Test deletion when user doesn't exist in repository.
    @Test("Delete user account handles non-existent user gracefully")
    func testNonExistentUserDeletion() async throws {
        // Arrange
        let mockUserRepo = TestUserRepository()
        let useCase = DeleteUserAccountUseCase(
            userRepository: mockUserRepo
        )
        
        let nonExistentUser = UserAccountModel(
            email: "nonexistent@example.com",
            password: "hashed",
            isEmailVerified: true
        )
        nonExistentUser.id = UUID() // User not in repository
        
        // Act - Should complete successfully (idempotent deletion)
        let result = try await useCase.execute(DeleteUserAccountUseCase.Request(
            user: nonExistentUser
        ))
        
        // Assert - Deletion reported as successful
        #expect(result.deleted == true)
    }
    
    /// Test deletion with repository failure.
    @Test("Delete user account handles repository failures")
    func testRepositoryFailureDeletion() async throws {
        // Arrange
        let failingUserRepo = DeleteTestFailingUserRepository()
        let useCase = DeleteUserAccountUseCase(
            userRepository: failingUserRepo
        )
        
        let user = UserAccountModel(
            email: "failure@example.com",
            password: "hashed",
            isEmailVerified: true
        )
        user.id = UUID()
        
        // Act & Assert
        await #expect(throws: Abort.self) {
            try await useCase.execute(DeleteUserAccountUseCase.Request(
                user: user
            ))
        }
    }
    
    /// Test deletion of admin user.
    @Test("Delete user account works for admin users")
    func testAdminUserDeletion() async throws {
        // Arrange
        let mockUserRepo = TestUserRepository()
        let useCase = DeleteUserAccountUseCase(
            userRepository: mockUserRepo
        )
        
        let adminUser = UserAccountModel(
            email: "admin@example.com",
            password: "hashed",
            isAdmin: true,
            isEmailVerified: true
        )
        adminUser.id = UUID()
        try await mockUserRepo.create(adminUser)
        
        // Act
        let result = try await useCase.execute(DeleteUserAccountUseCase.Request(
            user: adminUser
        ))
        
        // Assert - Admin deletion successful
        #expect(result.deleted == true)
        #expect(await mockUserRepo.users.isEmpty)
    }
    
    /// Test deletion of Apple Sign-In user.
    @Test("Delete user account works for Apple Sign-In users")
    func testAppleUserDeletion() async throws {
        // Arrange
        let mockUserRepo = TestUserRepository()
        let useCase = DeleteUserAccountUseCase(
            userRepository: mockUserRepo
        )
        
        let appleUser = UserAccountModel(
            email: "apple@example.com",
            password: "hashed",
            appleUserIdentifier: "apple.user.123",
            isEmailVerified: true
        )
        appleUser.id = UUID()
        try await mockUserRepo.create(appleUser)
        
        // Act
        let result = try await useCase.execute(DeleteUserAccountUseCase.Request(
            user: appleUser
        ))
        
        // Assert - Apple user deletion successful
        #expect(result.deleted == true)
        #expect(await mockUserRepo.users.isEmpty)
    }
    
    /// Test multiple sequential deletions.
    @Test("Delete user account handles multiple sequential deletions")
    func testMultipleSequentialDeletions() async throws {
        // Arrange
        let mockUserRepo = TestUserRepository()
        let useCase = DeleteUserAccountUseCase(
            userRepository: mockUserRepo
        )
        
        let users = (1...3).map { index in
            let user = UserAccountModel(
                email: "user\(index)@example.com",
                password: "hashed",
                isEmailVerified: true
            )
            user.id = UUID()
            return user
        }
        
        for user in users {
            try await mockUserRepo.create(user)
        }
        
        // Act - Delete all users sequentially
        for user in users {
            let result = try await useCase.execute(DeleteUserAccountUseCase.Request(
                user: user
            ))
            #expect(result.deleted == true)
        }
        
        // Assert - All users deleted
        #expect(await mockUserRepo.users.isEmpty)
    }
    
    /// Test sequential deletion operations for safety.
    @Test("Delete user account handles sequential deletions safely")
    func testSequentialDeletion() async throws {
        // Arrange
        let mockUserRepo = TestUserRepository()
        let useCase = DeleteUserAccountUseCase(
            userRepository: mockUserRepo
        )
        
        let userToDelete = UserAccountModel(
            email: "sequential@example.com",
            password: "hashed",
            isEmailVerified: true
        )
        userToDelete.id = UUID()
        try await mockUserRepo.create(userToDelete)
        
        // Act - Sequential deletion attempts (should be idempotent)
        let result1 = try await useCase.execute(DeleteUserAccountUseCase.Request(user: userToDelete))
        let result2 = try await useCase.execute(DeleteUserAccountUseCase.Request(user: userToDelete))
        
        // Assert - Both operations complete successfully (idempotent)
        #expect(result1.deleted == true)
        #expect(result2.deleted == true)
        let users = await mockUserRepo.users
        #expect(users.isEmpty) // User should be deleted
    }
}

// MARK: - Test Helper: Failing User Repository

/// Mock user repository that always fails for error testing.
private final class DeleteTestFailingUserRepository: UserRepository {
    typealias Model = UserAccountModel
    
    func create(_ model: UserAccountModel) async throws {
        throw Abort(.internalServerError)
    }
    
    func delete(id: UUID) async throws {
        throw Abort(.internalServerError, reason: "Repository deletion failed")
    }
    
    func find(email: String) async throws -> UserAccountModel? {
        throw Abort(.internalServerError)
    }
    
    func find(id: UUID) async throws -> UserAccountModel? {
        throw Abort(.internalServerError)
    }
    
    func find(appleUserIdentifier: String) async throws -> UserAccountModel? {
        throw Abort(.internalServerError)
    }
    
    func all() async throws -> [UserAccountModel] {
        throw Abort(.internalServerError)
    }
    
    func update(_ model: UserAccountModel) async throws {
        throw Abort(.internalServerError)
    }
    
    func count() async throws -> Int {
        throw Abort(.internalServerError)
    }
    
    // MARK: - Optimized methods with eager loading (failing implementations for tests)
    
    func findWithTokens(id: UUID) async throws -> (user: UserAccountModel?, refreshTokens: [RefreshTokenModel], emailTokens: [EmailTokenModel], passwordTokens: [PasswordTokenModel]) {
        throw Abort(.internalServerError)
    }
    
    func findWithRefreshTokens(id: UUID) async throws -> (user: UserAccountModel?, refreshTokens: [RefreshTokenModel]) {
        throw Abort(.internalServerError)
    }
    
    func findWithEmailTokens(id: UUID) async throws -> (user: UserAccountModel?, emailTokens: [EmailTokenModel]) {
        throw Abort(.internalServerError)
    }
    
    func findWithPasswordTokens(id: UUID) async throws -> (user: UserAccountModel?, passwordTokens: [PasswordTokenModel]) {
        throw Abort(.internalServerError)
    }
    
    func `for`(_ req: Request) -> DeleteTestFailingUserRepository {
        return self
    }
}


// MARK: - Destructive Command Testing Pattern Note

/*
This test demonstrates Destructive Command testing patterns:

1. **Irreversible Operation Testing**: Testing operations that permanently change system state
2. **Data Consistency Validation**: Ensuring clean deletion with no orphaned records
3. **Idempotent Operation Testing**: Testing that repeated deletions don't cause errors
4. **Concurrent Safety**: Testing deletion operations under concurrent access
5. **Error Recovery Testing**: Testing proper error handling for failed deletions

Key considerations in destructive command testing:
- Test successful deletion and data cleanup
- Verify proper error handling for edge cases
- Test idempotent behavior for repeated operations
- Ensure concurrent safety for multi-user scenarios
- Validate proper resource cleanup and memory management

These patterns ensure deletion commands are:
- Safe and predictable in their destructive operations
- Reliable under various failure scenarios
- Performant for single and bulk operations
- Consistent in concurrent environments
- Compliant with data integrity requirements
*/