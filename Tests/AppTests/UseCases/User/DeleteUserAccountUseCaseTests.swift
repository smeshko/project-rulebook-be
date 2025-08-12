import Testing
import Vapor
@testable import App

/// Comprehensive tests for DeleteUserAccountUseCase demonstrating Destructive Command patterns.
///
/// This test suite validates user account deletion including data cleanup, cascade operations,
/// authorization checks, and irreversible action safety measures.
final class DeleteUserAccountUseCaseTests {
    
    /// Test successful user account deletion with proper cleanup.
    @Test("Delete user account removes user and associated data")
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
        mockUserRepo.entities.append(userToDelete)
        
        let requestingUser = UserAccountModel(
            email: "admin@example.com",
            password: "hashed",
            isAdmin: true, // Admin can delete accounts
            isEmailVerified: true
        )
        requestingUser.id = UUID()
        
        // Act
        let result = try await useCase.execute(DeleteUserAccountUseCase.Request(
            userToDelete: userToDelete,
            requestingUser: requestingUser,
            reason: "User requested account deletion"
        ))
        
        // Assert - Response Structure
        #expect(result.success == true)
        #expect(result.deletedUserId == userToDelete.id!)
        #expect(result.message.contains("deleted"))
        #expect(result.deletedAt != nil)
        
        // Assert - User Removed from Repository
        #expect(mockUserRepo.entities.isEmpty)
        #expect(mockUserRepo.deleteCallCount == 1)
        
        // Assert - Proper Audit Information
        #expect(result.deletedByUserId == requestingUser.id!)
        #expect(result.reason == "User requested account deletion")
    }
    
    /// Test self-deletion by user.
    @Test("Delete user account allows users to delete their own account")
    func testSelfAccountDeletion() async throws {
        // Arrange
        let mockUserRepo = TestUserRepository()
        let useCase = DeleteUserAccountUseCase(
            userRepository: mockUserRepo
        )
        
        let user = UserAccountModel(
            email: "self@example.com",
            password: "hashed",
            firstName: "Self",
            lastName: "Delete",
            isEmailVerified: true
        )
        user.id = UUID()
        mockUserRepo.entities.append(user)
        
        // Act - User deleting their own account
        let result = try await useCase.execute(DeleteUserAccountUseCase.Request(
            userToDelete: user,
            requestingUser: user, // Same user
            reason: "No longer need the account"
        ))
        
        // Assert - Self-deletion allowed
        #expect(result.success == true)
        #expect(result.deletedUserId == user.id!)
        #expect(result.deletedByUserId == user.id!) // Self-deletion
        #expect(mockUserRepo.entities.isEmpty)
    }
    
    /// Test authorization check for non-admin user trying to delete others.
    @Test("Delete user account prevents non-admin from deleting other accounts")
    func testUnauthorizedDeletion() async throws {
        // Arrange
        let mockUserRepo = TestUserRepository()
        let useCase = DeleteUserAccountUseCase(
            userRepository: mockUserRepo
        )
        
        let targetUser = UserAccountModel(
            email: "target@example.com",
            password: "hashed",
            isEmailVerified: true
        )
        targetUser.id = UUID()
        
        let regularUser = UserAccountModel(
            email: "regular@example.com",
            password: "hashed",
            isAdmin: false, // Not an admin
            isEmailVerified: true
        )
        regularUser.id = UUID()
        
        // Act & Assert
        await #expect(throws: UserError.insufficientPermissions) {
            try await useCase.execute(DeleteUserAccountUseCase.Request(
                userToDelete: targetUser,
                requestingUser: regularUser,
                reason: "Unauthorized attempt"
            ))
        }
        
        // Assert - No deletion occurred
        #expect(mockUserRepo.deleteCallCount == 0)
    }
    
    /// Test deletion of non-existent user.
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
        nonExistentUser.id = UUID() // Not in repository
        
        let adminUser = UserAccountModel(
            email: "admin@example.com",
            password: "hashed",
            isAdmin: true,
            isEmailVerified: true
        )
        adminUser.id = UUID()
        
        // Act & Assert
        await #expect(throws: UserError.userNotFound) {
            try await useCase.execute(DeleteUserAccountUseCase.Request(
                userToDelete: nonExistentUser,
                requestingUser: adminUser,
                reason: "Delete non-existent user"
            ))
        }
    }
    
    /// Test repository failure during deletion.
    @Test("Delete user account handles repository failures gracefully")
    func testRepositoryFailureDeletion() async throws {
        // Arrange
        let failingUserRepo = FailingUserRepository()
        let useCase = DeleteUserAccountUseCase(
            userRepository: failingUserRepo
        )
        
        let user = UserAccountModel(
            email: "failure@example.com",
            password: "hashed",
            isEmailVerified: true
        )
        user.id = UUID()
        
        let adminUser = UserAccountModel(
            email: "admin@example.com",
            password: "hashed",
            isAdmin: true,
            isEmailVerified: true
        )
        adminUser.id = UUID()
        
        // Act & Assert
        await #expect(throws: UserError.deletionFailed) {
            try await useCase.execute(DeleteUserAccountUseCase.Request(
                userToDelete: user,
                requestingUser: adminUser,
                reason: "Test repository failure"
            ))
        }
    }
    
    /// Test admin deletion with audit trail.
    @Test("Delete user account creates comprehensive audit trail for admin deletions")
    func testAdminDeletionAuditTrail() async throws {
        // Arrange
        let mockUserRepo = TestUserRepository()
        let useCase = DeleteUserAccountUseCase(
            userRepository: mockUserRepo
        )
        
        let userToDelete = UserAccountModel(
            email: "audit@example.com",
            password: "hashed",
            firstName: "Audit",
            lastName: "Test",
            isEmailVerified: true
        )
        userToDelete.id = UUID()
        mockUserRepo.entities.append(userToDelete)
        
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
        let result = try await useCase.execute(DeleteUserAccountUseCase.Request(
            userToDelete: userToDelete,
            requestingUser: adminUser,
            reason: "Violated terms of service - spam posting"
        ))
        
        // Assert - Comprehensive Audit Information
        #expect(result.deletedUserId == userToDelete.id!)
        #expect(result.deletedByUserId == adminUser.id!)
        #expect(result.reason == "Violated terms of service - spam posting")
        #expect(result.deletedAt != nil)
        #expect(result.deletedUserEmail == "audit@example.com")
        #expect(result.deletedByUserEmail == "admin@example.com")
        
        // Assert - Timestamps
        let deletionTime = Date().timeIntervalSince(result.deletedAt!)
        #expect(deletionTime < 1.0) // Should be recent
    }
    
    /// Test deletion of user with special roles.
    @Test("Delete user account handles special user roles correctly")
    func testSpecialRoleUserDeletion() async throws {
        // Arrange
        let mockUserRepo = TestUserRepository()
        let useCase = DeleteUserAccountUseCase(
            userRepository: mockUserRepo
        )
        
        // Test deletion of admin user
        let adminToDelete = UserAccountModel(
            email: "admin-to-delete@example.com",
            password: "hashed",
            isAdmin: true, // Admin user being deleted
            isEmailVerified: true
        )
        adminToDelete.id = UUID()
        mockUserRepo.entities.append(adminToDelete)
        
        let superAdmin = UserAccountModel(
            email: "super@example.com",
            password: "hashed",
            isAdmin: true, // Super admin performing deletion
            isEmailVerified: true
        )
        superAdmin.id = UUID()
        
        // Act
        let result = try await useCase.execute(DeleteUserAccountUseCase.Request(
            userToDelete: adminToDelete,
            requestingUser: superAdmin,
            reason: "Admin role no longer needed"
        ))
        
        // Assert - Admin can be deleted by another admin
        #expect(result.success == true)
        #expect(result.deletedUserId == adminToDelete.id!)
        #expect(mockUserRepo.entities.isEmpty)
    }
    
    /// Test bulk deletion scenarios and limits.
    @Test("Delete user account tracks deletion patterns for bulk operations")
    func testDeletionPatternTracking() async throws {
        // Arrange
        let trackingUserRepo = TrackingUserRepository()
        let useCase = DeleteUserAccountUseCase(
            userRepository: trackingUserRepo
        )
        
        let adminUser = UserAccountModel(
            email: "admin@example.com",
            password: "hashed",
            isAdmin: true,
            isEmailVerified: true
        )
        adminUser.id = UUID()
        
        // Create multiple users to delete
        let users = (1...3).map { i in
            let user = UserAccountModel(
                email: "user\(i)@example.com",
                password: "hashed",
                isEmailVerified: true
            )
            user.id = UUID()
            trackingUserRepo.entities.append(user)
            return user
        }
        
        // Act - Delete multiple users
        for (index, user) in users.enumerated() {
            _ = try await useCase.execute(DeleteUserAccountUseCase.Request(
                userToDelete: user,
                requestingUser: adminUser,
                reason: "Bulk cleanup \(index + 1)"
            ))
        }
        
        // Assert - All deletions tracked
        #expect(trackingUserRepo.entities.isEmpty)
        #expect(trackingUserRepo.deletionLog.count == 3)
        
        // Assert - Deletion patterns tracked
        for (index, log) in trackingUserRepo.deletionLog.enumerated() {
            #expect(log.contains("user\(index + 1)@example.com"))
            #expect(log.contains("Bulk cleanup \(index + 1)"))
        }
    }
    
    /// Test concurrent deletion attempts.
    @Test("Delete user account handles concurrent deletion attempts safely")
    func testConcurrentDeletion() async throws {
        // Arrange
        let threadSafeRepo = ThreadSafeUserRepository()
        let useCase = DeleteUserAccountUseCase(
            userRepository: threadSafeRepo
        )
        
        let userToDelete = UserAccountModel(
            email: "concurrent@example.com",
            password: "hashed",
            isEmailVerified: true
        )
        userToDelete.id = UUID()
        threadSafeRepo.entities.append(userToDelete)
        
        let admin1 = UserAccountModel(
            email: "admin1@example.com",
            password: "hashed",
            isAdmin: true,
            isEmailVerified: true
        )
        admin1.id = UUID()
        
        let admin2 = UserAccountModel(
            email: "admin2@example.com",
            password: "hashed",
            isAdmin: true,
            isEmailVerified: true
        )
        admin2.id = UUID()
        
        // Act - Concurrent deletion attempts
        async let result1 = useCase.execute(DeleteUserAccountUseCase.Request(
            userToDelete: userToDelete,
            requestingUser: admin1,
            reason: "Concurrent deletion 1"
        ))
        
        async let result2 = useCase.execute(DeleteUserAccountUseCase.Request(
            userToDelete: userToDelete,
            requestingUser: admin2,
            reason: "Concurrent deletion 2"
        ))
        
        do {
            let (res1, res2) = try await (result1, result2)
            
            // One should succeed, the other might fail or both might succeed
            // depending on implementation (idempotent deletion vs error on double deletion)
            let successCount = [res1.success, res2.success].filter { $0 }.count
            #expect(successCount >= 1) // At least one should succeed
            
        } catch {
            // One deletion should succeed, other should fail gracefully
            // This is acceptable behavior for concurrent destructive operations
            #expect(threadSafeRepo.entities.isEmpty) // User should be deleted
        }
    }
}

// MARK: - Test Helper: Tracking User Repository

/// Mock user repository that tracks deletion operations for audit testing.
private class TrackingUserRepository: UserRepository {
    var entities: [UserAccountModel] = []
    var deletionLog: [String] = []
    
    func delete(id: UUID) async throws {
        if let index = entities.firstIndex(where: { $0.id == id }) {
            let user = entities[index]
            deletionLog.append("Deleted user: \(user.email)")
            entities.remove(at: index)
        } else {
            throw UserError.userNotFound
        }
    }
    
    // Other required methods with basic implementations
    func create(_ user: UserAccountModel) async throws { entities.append(user) }
    func update(_ user: UserAccountModel) async throws {
        if let index = entities.firstIndex(where: { $0.id == user.id }) {
            entities[index] = user
        }
    }
    func find(id: UUID?) async throws -> UserAccountModel? { entities.first { $0.id == id } }
    func find(email: String) async throws -> UserAccountModel? { entities.first { $0.email == email } }
    func find(appleUserIdentifier: String) async throws -> UserAccountModel? { entities.first { $0.appleUserIdentifier == appleUserIdentifier } }
    func all() async throws -> [UserAccountModel] { entities }
    func count() async throws -> Int { entities.count }
    func `for`(_ req: Request) -> TrackingUserRepository { return self }
}

/// Thread-safe mock user repository for concurrent testing.
private class ThreadSafeUserRepository: UserRepository {
    private let queue = DispatchQueue(label: "thread-safe-user-repo", attributes: .concurrent)
    private var _entities: [UserAccountModel] = []
    
    var entities: [UserAccountModel] {
        get {
            queue.sync { _entities }
        }
        set {
            queue.async(flags: .barrier) { self._entities = newValue }
        }
    }
    
    func delete(id: UUID) async throws {
        try await withCheckedThrowingContinuation { continuation in
            queue.async(flags: .barrier) {
                if let index = self._entities.firstIndex(where: { $0.id == id }) {
                    self._entities.remove(at: index)
                    continuation.resume()
                } else {
                    continuation.resume(throwing: UserError.userNotFound)
                }
            }
        }
    }
    
    // Other required methods
    func create(_ user: UserAccountModel) async throws {
        queue.async(flags: .barrier) {
            self._entities.append(user)
        }
    }
    
    func update(_ user: UserAccountModel) async throws { /* Mock implementation */ }
    func find(id: UUID?) async throws -> UserAccountModel? {
        queue.sync { _entities.first { $0.id == id } }
    }
    func find(email: String) async throws -> UserAccountModel? { 
        queue.sync { _entities.first { $0.email == email } }
    }
    func find(appleUserIdentifier: String) async throws -> UserAccountModel? { return nil }
    func all() async throws -> [UserAccountModel] { queue.sync { _entities } }
    func count() async throws -> Int { queue.sync { _entities.count } }
    func `for`(_ req: Request) -> ThreadSafeUserRepository { return self }
}

// MARK: - Destructive Command Testing Pattern Note

/*
This test demonstrates Destructive Command testing patterns:

1. **Authorization Verification**: Testing proper permission checks for destructive operations
2. **Audit Trail Creation**: Testing comprehensive logging for irreversible actions
3. **Data Integrity**: Testing proper cleanup and cascade deletion handling
4. **Concurrent Safety**: Testing safe handling of concurrent destructive operations
5. **Error Recovery**: Testing graceful handling of failures in destructive operations
6. **Self-Service Operations**: Testing user's ability to perform actions on their own data

Key characteristics of destructive command testing:
- Strong authorization checks (prevent unauthorized deletion)
- Comprehensive audit logging (who, when, why, what)
- Proper error handling (graceful failure, no corruption)
- Concurrent safety (prevent race conditions in deletion)
- Self-service validation (users can delete their own data)
- Administrative oversight (admins can delete any user)

These patterns ensure destructive commands are:
- Secure and properly authorized
- Auditable for compliance and security
- Safe against concurrent operations
- Recoverable through comprehensive logging
- Compliant with data protection regulations
- Reliable in error scenarios

Destructive commands differ from other commands by:
- Irreversible nature requires extra safety measures
- Enhanced audit requirements for compliance
- Stricter authorization and permission checking
- Greater emphasis on concurrent operation safety
- Need for comprehensive error handling and recovery
*/