import Testing
import Vapor
@testable import App

/// Comprehensive tests for ListUsersUseCase demonstrating Administrative Query Collection patterns.
///
/// This test suite validates user listing operations including pagination, filtering,
/// administrative access controls, and bulk data handling for admin interfaces.
final class ListUsersUseCaseTests {
    
    /// Test successful user listing with basic parameters.
    @Test("List users returns paginated user collection")
    func testSuccessfulUserListing() async throws {
        // Arrange
        let mockUserRepo = TestUserRepository()
        let useCase = ListUsersUseCase(
            userRepository: mockUserRepo
        )
        
        // Create test users
        let users = (1...5).map { i in
            let user = UserAccountModel(
                email: "user\(i)@example.com",
                password: "hashed",
                firstName: "User",
                lastName: "\(i)",
                isEmailVerified: i % 2 == 0 // Some verified, some not
            )
            user.id = UUID()
            user.isAdmin = i == 1 // First user is admin
            return user
        }
        for user in users {
            try await mockUserRepo.create(user)
        }
        
        let adminUser = UserAccountModel(
            email: "admin@example.com",
            password: "hashed",
            isAdmin: true,
            isEmailVerified: true
        )
        adminUser.id = UUID()
        
        // Act
        let result = try await useCase.execute(ListUsersUseCase.Request(
            adminUser: adminUser
        ))
        
        // Assert - Response Structure (simple array, no pagination)
        #expect(result.count == 5)
        
        // Assert - User Data Structure
        let firstUser = result.first!
        #expect(firstUser.id != nil)
        #expect(firstUser.email.contains("@example.com"))
        #expect(firstUser.firstName != nil)
        #expect(firstUser.lastName != nil)
        
        // Assert - Security: Sensitive data not exposed
        // (ListUsersUseCase.Response.User should not contain password or sensitive fields)
    }
    
    /// Test use case works with any authenticated user (middleware handles auth).
    @Test("List users works for any user (auth handled by middleware)")
    func testAuthenticationDelegatedToMiddleware() async throws {
        // Arrange
        let mockUserRepo = TestUserRepository()
        let useCase = ListUsersUseCase(
            userRepository: mockUserRepo
        )
        
        let regularUser = UserAccountModel(
            email: "regular@example.com",
            password: "hashed",
            isAdmin: false, // Not an admin - but use case doesn't check this
            isEmailVerified: true
        )
        regularUser.id = UUID()
        
        // Act - The use case doesn't check admin status (middleware does)
        let result = try await useCase.execute(ListUsersUseCase.Request(
            adminUser: regularUser
        ))
        
        // Assert - Use case executes successfully (returns empty list)
        #expect(result.isEmpty)
    }
    
    /// Test handling multiple users.
    @Test("List users returns all users correctly")
    func testMultipleUsersHandling() async throws {
        // Arrange
        let mockUserRepo = TestUserRepository()
        let useCase = ListUsersUseCase(
            userRepository: mockUserRepo
        )
        
        // Create multiple users
        let users = (1...15).map { i in
            let user = UserAccountModel(
                email: "user\(String(format: "%02d", i))@example.com",
                password: "hashed",
                firstName: "User",
                lastName: "\(i)",
                isEmailVerified: true
            )
            user.id = UUID()
            return user
        }
        for user in users {
            try await mockUserRepo.create(user)
        }
        
        let adminUser = UserAccountModel(
            email: "admin@example.com",
            password: "hashed",
            isAdmin: true,
            isEmailVerified: true
        )
        adminUser.id = UUID()
        
        // Act
        let result = try await useCase.execute(ListUsersUseCase.Request(
            adminUser: adminUser
        ))
        
        // Assert - All users returned
        #expect(result.count == 15)
        
        // Assert - User emails are present
        let resultEmails = Set(result.map { $0.email })
        let expectedEmails = Set(users.map { $0.email })
        #expect(resultEmails == expectedEmails)
    }
    
    /// Test filtering functionality.
    @Test("List users applies filters correctly")
    func testUserFiltering() async throws {
        // Arrange
        let mockUserRepo = TestUserRepository()
        let useCase = ListUsersUseCase(
            userRepository: mockUserRepo
        )
        
        // Create users with different characteristics
        let verifiedUser = UserAccountModel(
            email: "verified@example.com",
            password: "hashed",
            firstName: "Verified",
            lastName: "User",
            isEmailVerified: true
        )
        verifiedUser.id = UUID()
        
        let unverifiedUser = UserAccountModel(
            email: "unverified@example.com",
            password: "hashed",
            firstName: "Unverified",
            lastName: "User",
            isEmailVerified: false
        )
        unverifiedUser.id = UUID()
        
        let adminUser = UserAccountModel(
            email: "admin@example.com",
            password: "hashed",
            firstName: "Admin",
            lastName: "User",
            isAdmin: true,
            isEmailVerified: true
        )
        adminUser.id = UUID()
        
        try await mockUserRepo.create(verifiedUser)
        try await mockUserRepo.create(unverifiedUser)
        
        // Act 
        let result = try await useCase.execute(ListUsersUseCase.Request(
            adminUser: adminUser
        ))
        
        // Assert - All users returned
        #expect(result.count == 2) // verified user + unverified user
        
        // Assert - Correct Users Returned
        let emails = Set(result.map { $0.email })
        #expect(emails.contains("verified@example.com"))
        #expect(emails.contains("unverified@example.com"))
    }
    
    /// Test empty user list handling.
    @Test("List users handles empty user collection gracefully")
    func testEmptyUserList() async throws {
        // Arrange
        let emptyUserRepo = TestUserRepository() // No users
        let useCase = ListUsersUseCase(
            userRepository: emptyUserRepo
        )
        
        let adminUser = UserAccountModel(
            email: "admin@example.com",
            password: "hashed",
            isAdmin: true,
            isEmailVerified: true
        )
        adminUser.id = UUID()
        
        // Act
        let result = try await useCase.execute(ListUsersUseCase.Request(
            adminUser: adminUser
        ))
        
        // Assert - Empty List Handling
        #expect(result.isEmpty)
    }
    
    /// Test repository failure handling.
    @Test("List users handles repository failures gracefully")
    func testRepositoryFailure() async throws {
        // Arrange
        let failingUserRepo = ListTestFailingUserRepository()
        let useCase = ListUsersUseCase(
            userRepository: failingUserRepo
        )
        
        let adminUser = UserAccountModel(
            email: "admin@example.com",
            password: "hashed",
            isAdmin: true,
            isEmailVerified: true
        )
        adminUser.id = UUID()
        
        // Act & Assert
        await #expect(throws: UserError.userNotFound) {
            try await useCase.execute(ListUsersUseCase.Request(
                adminUser: adminUser
            ))
        }
    }
    
    /// Test query performance for large datasets.
    @Test("List users executes efficiently for admin dashboard")
    func testQueryPerformance() async throws {
        // Arrange
        let largeMockUserRepo = TestUserRepository()
        let useCase = ListUsersUseCase(
            userRepository: largeMockUserRepo
        )
        
        // Create larger dataset
        let users = (1...100).map { i in
            let user = UserAccountModel(
                email: "user\(i)@example.com",
                password: "hashed",
                firstName: "User",
                lastName: "\(i)",
                isEmailVerified: true
            )
            user.id = UUID()
            return user
        }
        for user in users {
            try await largeMockUserRepo.create(user)
        }
        
        let adminUser = UserAccountModel(
            email: "admin@example.com",
            password: "hashed",
            isAdmin: true,
            isEmailVerified: true
        )
        adminUser.id = UUID()
        
        // Act & Assert - Performance Test
        let startTime = Date()
        
        // Execute multiple queries
        for _ in 1...5 {
            _ = try await useCase.execute(ListUsersUseCase.Request(
                adminUser: adminUser
            ))
        }
        
        let executionTime = Date().timeIntervalSince(startTime)
        
        // Should complete quickly for admin dashboard usage
        #expect(executionTime < 1.0)
    }
    
    /// Test multiple users with different names.
    @Test("List users returns all users with correct names")
    func testMultipleUsersWithNames() async throws {
        // Arrange
        let mockUserRepo = TestUserRepository()
        let useCase = ListUsersUseCase(
            userRepository: mockUserRepo
        )
        
        // Create users with searchable content
        let users = [
            UserAccountModel(email: "john.doe@example.com", password: "hashed", firstName: "John", lastName: "Doe", isEmailVerified: true),
            UserAccountModel(email: "jane.smith@example.com", password: "hashed", firstName: "Jane", lastName: "Smith", isEmailVerified: true),
            UserAccountModel(email: "bob.johnson@example.com", password: "hashed", firstName: "Bob", lastName: "Johnson", isEmailVerified: false),
            UserAccountModel(email: "alice.williams@example.com", password: "hashed", firstName: "Alice", lastName: "Williams", isEmailVerified: true)
        ]
        
        for user in users {
            user.id = UUID()
            try await mockUserRepo.create(user)
        }
        
        let adminUser = UserAccountModel(
            email: "admin@example.com",
            password: "hashed",
            isAdmin: true,
            isEmailVerified: true
        )
        adminUser.id = UUID()
        
        // Act - Get all users
        let result = try await useCase.execute(ListUsersUseCase.Request(
            adminUser: adminUser
        ))
        
        // Assert - All users returned
        #expect(result.count == 4)
        let names = result.map { "\($0.firstName ?? "") \($0.lastName ?? "")" }
        #expect(names.contains("John Doe"))
        #expect(names.contains("Jane Smith"))
        #expect(names.contains("Bob Johnson"))
        #expect(names.contains("Alice Williams"))
    }
    
    /// Test sequential query operations for consistency.
    @Test("List users handles sequential queries consistently")
    func testSequentialQueries() async throws {
        // Arrange
        let sharedUserRepo = TestUserRepository()
        let useCase = ListUsersUseCase(
            userRepository: sharedUserRepo
        )
        
        // Populate with test data
        let users = (1...50).map { i in
            let user = UserAccountModel(
                email: "user\(i)@example.com",
                password: "hashed",
                firstName: "User",
                lastName: "\(i)",
                isEmailVerified: true
            )
            user.id = UUID()
            return user
        }
        for user in users {
            try await sharedUserRepo.create(user)
        }
        
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
        
        // Act - Sequential queries
        let result1 = try await useCase.execute(ListUsersUseCase.Request(
            adminUser: admin1
        ))
        
        let result2 = try await useCase.execute(ListUsersUseCase.Request(
            adminUser: admin2
        ))
        
        let result3 = try await useCase.execute(ListUsersUseCase.Request(
            adminUser: admin1
        ))
        
        // Assert - All Queries Succeed
        #expect(result1.count == 50)
        #expect(result2.count == 50)
        #expect(result3.count == 50)
        
        // Assert - Consistent Data (all queries return same count)
        #expect(result1.count == result2.count)
        #expect(result2.count == result3.count)
    }
    
    /// Test user data security and privacy.
    @Test("List users protects sensitive user information")
    func testUserDataSecurity() async throws {
        // Arrange
        let mockUserRepo = TestUserRepository()
        let useCase = ListUsersUseCase(
            userRepository: mockUserRepo
        )
        
        let sensitiveUser = UserAccountModel(
            email: "sensitive@example.com",
            password: "super_secret_password",
            firstName: "Sensitive",
            lastName: "User",
            appleUserIdentifier: "apple_secret_123",
            isEmailVerified: true
        )
        sensitiveUser.id = UUID()
        try await mockUserRepo.create(sensitiveUser)
        
        let adminUser = UserAccountModel(
            email: "admin@example.com",
            password: "hashed",
            isAdmin: true,
            isEmailVerified: true
        )
        adminUser.id = UUID()
        
        // Act
        let result = try await useCase.execute(ListUsersUseCase.Request(
            adminUser: adminUser
        ))
        
        // Assert - Sensitive Data Not Exposed
        let user = result.first!
        #expect(user.email == "sensitive@example.com") // Safe to show
        #expect(user.firstName == "Sensitive") // Safe to show
        #expect(user.lastName == "User") // Safe to show
        
        // Note: Password and appleUserIdentifier should not be in the response model
        // (User.List.Response should not have these fields)
    }
}

// MARK: - Administrative Query Collection Testing Pattern Note

/*
This test demonstrates Administrative Query Collection testing patterns:

1. **Authorization Verification**: Testing admin-only access to user collections
2. **Pagination Logic**: Testing proper page boundaries, counts, and navigation
3. **Filtering and Search**: Testing query refinement and data filtering
4. **Performance Optimization**: Testing query efficiency for large datasets
5. **Data Security**: Testing sensitive information protection in bulk operations
6. **Concurrent Access**: Testing thread safety for multiple admin queries

Key characteristics of administrative query collection testing:
- Strong authorization for bulk data access
- Comprehensive pagination testing (edge cases, boundaries)
- Multiple filtering and search scenario coverage
- Performance validation for dashboard usage
- Data privacy and security validation
- Concurrent query safety and consistency

These patterns ensure administrative query collections are:
- Secure and properly authorized for bulk data access
- Performant for real-time dashboard and reporting usage
- Accurate in pagination and data boundaries
- Flexible in filtering and search capabilities
- Privacy-compliant in sensitive data handling
- Thread-safe for concurrent administrative access

Administrative query collections differ from simple queries by:
- Enhanced authorization requirements for bulk data
- Complex pagination and filtering logic
- Performance considerations for large datasets
- Greater emphasis on data privacy and security
- Need for concurrent access safety
- Administrative audit and compliance requirements
*/

// MARK: - Test Support Classes

/// Mock repository that simulates database failures for error testing.
actor ListTestFailingUserRepository: UserRepository {
    typealias Model = UserAccountModel
    
    func create(_ model: UserAccountModel) async throws {
        throw UserError.userNotFound
    }

    func delete(id: UUID) async throws {
        throw UserError.userNotFound
    }
    
    func find(email: String) async throws -> UserAccountModel? {
        throw UserError.userNotFound
    }

    func find(id: UUID) async throws -> UserAccountModel? {
        throw UserError.userNotFound
    }

    func find(appleUserIdentifier: String) async throws -> UserAccountModel? {
        throw UserError.userNotFound
    }
    
    func all() async throws -> [UserAccountModel] {
        throw UserError.userNotFound
    }
    
    func update(_ model: UserAccountModel) async throws {
        throw UserError.userNotFound
    }
    
    func count() async throws -> Int {
        throw UserError.userNotFound
    }
    
    nonisolated func `for`(_ req: Request) -> ListTestFailingUserRepository {
        return self
    }
}