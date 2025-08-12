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
            requestingUser: adminUser,
            page: 1,
            limit: 10
        ))
        
        // Assert - Response Structure
        #expect(result.users.count == 5)
        #expect(result.totalCount == 5)
        #expect(result.currentPage == 1)
        #expect(result.totalPages == 1)
        #expect(result.hasNextPage == false)
        #expect(result.hasPreviousPage == false)
        
        // Assert - User Data Structure
        let firstUser = result.users.first!
        #expect(firstUser.id != nil)
        #expect(firstUser.email.contains("@example.com"))
        #expect(firstUser.firstName != nil)
        #expect(firstUser.lastName != nil)
        
        // Assert - Security: Sensitive data not exposed
        // (ListUsersUseCase.Response.User should not contain password or sensitive fields)
    }
    
    /// Test authorization check for non-admin users.
    @Test("List users rejects non-admin users")
    func testNonAdminUserRejection() async throws {
        // Arrange
        let useCase = ListUsersUseCase(
            userRepository: TestUserRepository()
        )
        
        let regularUser = UserAccountModel(
            email: "regular@example.com",
            password: "hashed",
            isAdmin: false, // Not an admin
            isEmailVerified: true
        )
        regularUser.id = UUID()
        
        // Act & Assert
        await #expect(throws: AdminError.insufficientPrivileges) {
            try await useCase.execute(ListUsersUseCase.Request(
                requestingUser: regularUser,
                page: 1,
                limit: 10
            ))
        }
    }
    
    /// Test pagination functionality.
    @Test("List users handles pagination correctly")
    func testPaginationHandling() async throws {
        // Arrange
        let mockUserRepo = TestUserRepository()
        let useCase = ListUsersUseCase(
            userRepository: mockUserRepo
        )
        
        // Create more users than page size
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
        
        // Act - Test first page
        let page1Result = try await useCase.execute(ListUsersUseCase.Request(
            requestingUser: adminUser,
            page: 1,
            limit: 10
        ))
        
        // Assert - First Page
        #expect(page1Result.users.count == 10)
        #expect(page1Result.totalCount == 15)
        #expect(page1Result.currentPage == 1)
        #expect(page1Result.totalPages == 2)
        #expect(page1Result.hasNextPage == true)
        #expect(page1Result.hasPreviousPage == false)
        
        // Act - Test second page
        let page2Result = try await useCase.execute(ListUsersUseCase.Request(
            requestingUser: adminUser,
            page: 2,
            limit: 10
        ))
        
        // Assert - Second Page
        #expect(page2Result.users.count == 5) // Remaining users
        #expect(page2Result.totalCount == 15)
        #expect(page2Result.currentPage == 2)
        #expect(page2Result.totalPages == 2)
        #expect(page2Result.hasNextPage == false)
        #expect(page2Result.hasPreviousPage == true)
        
        // Assert - No Overlap
        let page1Emails = Set(page1Result.users.map { $0.email })
        let page2Emails = Set(page2Result.users.map { $0.email })
        #expect(page1Emails.intersection(page2Emails).isEmpty)
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
        
        mockUserRepo.entities.append(contentsOf: [verifiedUser, unverifiedUser, adminUser])
        
        // Act - Filter by email verification status
        let result = try await useCase.execute(ListUsersUseCase.Request(
            requestingUser: adminUser,
            page: 1,
            limit: 10,
            emailVerified: true // Filter for verified users only
        ))
        
        // Assert - Filtering Applied
        #expect(result.users.count == 2) // verified user + admin
        #expect(result.users.allSatisfy { $0.isEmailVerified == true })
        
        // Assert - Correct Users Returned
        let emails = Set(result.users.map { $0.email })
        #expect(emails.contains("verified@example.com"))
        #expect(emails.contains("admin@example.com"))
        #expect(!emails.contains("unverified@example.com"))
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
            requestingUser: adminUser,
            page: 1,
            limit: 10
        ))
        
        // Assert - Empty List Handling
        #expect(result.users.isEmpty)
        #expect(result.totalCount == 0)
        #expect(result.currentPage == 1)
        #expect(result.totalPages == 0)
        #expect(result.hasNextPage == false)
        #expect(result.hasPreviousPage == false)
    }
    
    /// Test repository failure handling.
    @Test("List users handles repository failures gracefully")
    func testRepositoryFailure() async throws {
        // Arrange
        let failingUserRepo = FailingUserRepository()
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
                requestingUser: adminUser,
                page: 1,
                limit: 10
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
        largeMockUserRepo.entities.append(contentsOf: users)
        
        let adminUser = UserAccountModel(
            email: "admin@example.com",
            password: "hashed",
            isAdmin: true,
            isEmailVerified: true
        )
        adminUser.id = UUID()
        
        // Act & Assert - Performance Test
        let startTime = Date()
        
        // Execute multiple pagination queries
        for page in 1...5 {
            _ = try await useCase.execute(ListUsersUseCase.Request(
                requestingUser: adminUser,
                page: page,
                limit: 20
            ))
        }
        
        let executionTime = Date().timeIntervalSince(startTime)
        
        // Should complete quickly for admin dashboard usage
        #expect(executionTime < 1.0)
    }
    
    /// Test search functionality.
    @Test("List users supports search and filtering")
    func testSearchFunctionality() async throws {
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
        
        // Act - Search by name
        let result = try await useCase.execute(ListUsersUseCase.Request(
            requestingUser: adminUser,
            page: 1,
            limit: 10,
            searchTerm: "john" // Should match John Doe and Bob Johnson
        ))
        
        // Assert - Search Results
        #expect(result.users.count == 2)
        let names = result.users.map { "\($0.firstName ?? "") \($0.lastName ?? "")" }
        #expect(names.contains("John Doe"))
        #expect(names.contains("Bob Johnson"))
    }
    
    /// Test concurrent query operations.
    @Test("List users handles concurrent queries efficiently")
    func testConcurrentQueries() async throws {
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
        sharedUserRepo.entities.append(contentsOf: users)
        
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
        
        // Act - Concurrent queries
        async let result1 = useCase.execute(ListUsersUseCase.Request(
            requestingUser: admin1,
            page: 1,
            limit: 20
        ))
        
        async let result2 = useCase.execute(ListUsersUseCase.Request(
            requestingUser: admin2,
            page: 2,
            limit: 20
        ))
        
        async let result3 = useCase.execute(ListUsersUseCase.Request(
            requestingUser: admin1,
            page: 1,
            limit: 10
        ))
        
        let (res1, res2, res3) = try await (result1, result2, result3)
        
        // Assert - All Queries Succeed
        #expect(res1.users.count == 20)
        #expect(res2.users.count == 20)
        #expect(res3.users.count == 10)
        
        // Assert - Consistent Data
        #expect(res1.totalCount == res2.totalCount)
        #expect(res2.totalCount == res3.totalCount)
        #expect(res1.totalCount == 50) // Same data source
        
        // Assert - Proper Pagination
        #expect(res1.currentPage == 1)
        #expect(res2.currentPage == 2)
        #expect(res3.currentPage == 1)
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
            requestingUser: adminUser,
            page: 1,
            limit: 10
        ))
        
        // Assert - Sensitive Data Not Exposed
        let user = result.users.first!
        #expect(user.email == "sensitive@example.com") // Safe to show
        #expect(user.firstName == "Sensitive") // Safe to show
        #expect(user.lastName == "User") // Safe to show
        
        // Note: Password and appleUserIdentifier should not be in the response model
        // (ListUsersUseCase.Response.User should not have these fields)
        
        // Assert - Security Metadata Available
        #expect(user.isEmailVerified == true)
        #expect(user.isAdmin == false)
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
actor FailingUserRepository: UserRepository {
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
}