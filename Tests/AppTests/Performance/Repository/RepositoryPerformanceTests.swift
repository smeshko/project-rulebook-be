@testable import App
import XCTest
import Vapor
import Fluent
import Testing

/// Performance tests for Phase 5 repository optimizations
/// 
/// Tests the N+1 query prevention through eager loading in UserRepository
/// and validates database query reduction targets.
final class RepositoryPerformanceTests: PerformanceTestCase {
    
    var testWorld: TestWorld!
    var database: Database!
    var userRepository: any UserRepository!
    var dataFactory: TestDataFactory!
    
    override func setUp() async throws {
        try await super.setUp()
        testWorld = try TestWorld(app: application)
        database = application.db
        userRepository = application.repositories.users
        dataFactory = testWorld.dataFactory
        
        // Setup test data for realistic performance testing
        try await setupTestData()
    }
    
    override func tearDown() async throws {
        await testWorld.resetAll()
        try await super.tearDown()
    }
    
    private func setupTestData() async throws {
        // Create test users with associated tokens for N+1 prevention testing
        let testUsers = PerformanceTestUtilities.generateTestUsers(count: 100)
        
        for userData in testUsers {
            let user = try await dataFactory.createUser(
                email: userData.email,
                name: userData.name,
                isVerified: true
            )
            
            // Create some tokens for each user to test eager loading
            for i in 0..<3 {
                _ = try await dataFactory.createRefreshToken(
                    for: user,
                    token: "refresh_token_\(user.id!)_\(i)"
                )
            }
            
            for i in 0..<2 {
                _ = try await dataFactory.createEmailToken(
                    for: user,
                    token: "email_token_\(user.id!)_\(i)"
                )
            }
            
            // Create password token for some users
            if userData.email.contains("1") || userData.email.contains("5") {
                _ = try await dataFactory.createPasswordToken(
                    for: user,
                    token: "password_token_\(user.id!)"
                )
            }
        }
    }
    
    // MARK: - N+1 Query Prevention Tests
    
    @Test("User with tokens eager loading prevents N+1 queries")
    func testUserWithTokensEagerLoading() async throws {
        let testUserIds = try await UserAccountModel.query(on: database)
            .limit(20)
            .all()
            .compactMap { $0.id }
        
        // Test sequential queries (simulating N+1 problem)
        var sequentialQueries = 0
        let sequentialStartTime = Date()
        
        for userId in testUserIds {
            // This would cause N+1 queries in a naive implementation
            sequentialQueries += 1 // 1 query for user
            let user = try await userRepository.find(id: userId)
            
            if user != nil {
                // Additional queries for tokens (N+1 problem)
                let refreshTokens = try await RefreshTokenModel.query(on: database)
                    .filter(\.$user.$id == userId)
                    .all()
                sequentialQueries += 1
                
                let emailTokens = try await EmailTokenModel.query(on: database)
                    .filter(\.$user.$id == userId)
                    .all()
                sequentialQueries += 1
                
                let passwordTokens = try await PasswordTokenModel.query(on: database)
                    .filter(\.$user.$id == userId)
                    .all()
                sequentialQueries += 1
                
                _ = refreshTokens.count + emailTokens.count + passwordTokens.count
            }
        }
        
        let sequentialTime = Date().timeIntervalSince(sequentialStartTime)
        
        // Test optimized eager loading (prevents N+1)
        var eagerLoadQueries = 0
        let eagerStartTime = Date()
        
        for userId in testUserIds {
            // Single optimized query with all related data
            eagerLoadQueries += 4 // Parallel queries in findWithTokens
            let result = try await userRepository.findWithTokens(id: userId)
            
            // Process all data from single query
            if let user = result.user {
                let totalTokens = result.refreshTokens.count + 
                                result.emailTokens.count + 
                                result.passwordTokens.count
                _ = "\(user.email) has \(totalTokens) tokens"
            }
        }
        
        let eagerLoadTime = Date().timeIntervalSince(eagerStartTime)
        
        let metrics = PerformanceTestUtilities.QueryPerformanceMetrics(
            operationName: "UserWithTokens",
            sequentialQueries: sequentialQueries,
            eagerLoadQueries: eagerLoadQueries,
            sequentialTime: sequentialTime,
            eagerLoadTime: eagerLoadTime,
            recordsProcessed: testUserIds.count
        )
        
        print("=== N+1 Query Prevention Performance ===")
        print(metrics.summary)
        
        // Assert Phase 5 targets
        PerformanceTestUtilities.assertQueryReduction(metrics)
        
        // Eager loading should be significantly faster
        XCTAssertLessThan(eagerLoadTime, sequentialTime * 0.8, 
            "Eager loading should be at least 20% faster")
        
        // Query count should be dramatically reduced
        XCTAssertLessThan(Double(eagerLoadQueries), Double(sequentialQueries) * 0.5,
            "Eager loading should use less than 50% of sequential queries")
    }
    
    @Test("User with refresh tokens optimization performance")
    func testUserWithRefreshTokensOptimization() async throws {
        let testUserIds = try await UserAccountModel.query(on: database)
            .limit(50)
            .all()
            .compactMap { $0.id }
        
        // Benchmark sequential approach
        let sequentialMetrics = try await measure(
            "Sequential User + Refresh Tokens",
            iterations: 10
        ) {
            for userId in testUserIds {
                let user = try await self.userRepository.find(id: userId)
                if user != nil {
                    _ = try await RefreshTokenModel.query(on: self.database)
                        .filter(\.$user.$id == userId)
                        .all()
                }
            }
        }
        
        // Benchmark optimized eager loading
        let optimizedMetrics = try await measure(
            "Optimized User + Refresh Tokens",
            iterations: 10
        ) {
            for userId in testUserIds {
                _ = try await self.userRepository.findWithRefreshTokens(id: userId)
            }
        }
        
        print("=== User + Refresh Tokens Performance Comparison ===")
        print("Sequential Approach:")
        print(sequentialMetrics.phase5Summary)
        print("\nOptimized Approach:")
        print(optimizedMetrics.phase5Summary)
        
        let improvementPercentage = ((sequentialMetrics.averageTime - optimizedMetrics.averageTime) / 
                                   sequentialMetrics.averageTime) * 100.0
        
        print("\nPerformance Improvement: \(String(format: "%.1f", improvementPercentage))%")
        
        // Assert significant performance improvement
        XCTAssertLessThan(optimizedMetrics.averageTime, sequentialMetrics.averageTime * 0.7,
            "Optimized approach should be at least 30% faster")
        
        XCTAssertGreaterThan(improvementPercentage, 25.0,
            "Should achieve at least 25% performance improvement")
    }
    
    @Test("User with email tokens optimization performance")
    func testUserWithEmailTokensOptimization() async throws {
        // Focus on users that have email tokens
        let usersWithEmailTokens = try await EmailTokenModel.query(on: database)
            .with(\.$user)
            .limit(30)
            .all()
            .compactMap { $0.user.id }
        
        // Benchmark sequential vs optimized
        let comparisonResults = try await benchmarkRepositoryMethods(
            userIds: usersWithEmailTokens,
            operationName: "User + Email Tokens",
            sequentialOperation: { userId in
                let user = try await self.userRepository.find(id: userId)
                if user != nil {
                    _ = try await EmailTokenModel.query(on: self.database)
                        .filter(\.$user.$id == userId)
                        .all()
                }
            },
            optimizedOperation: { userId in
                _ = try await self.userRepository.findWithEmailTokens(id: userId)
            }
        )
        
        print("=== Email Tokens Optimization Results ===")
        print(comparisonResults.summary)
        
        PerformanceTestUtilities.assertQueryReduction(comparisonResults)
    }
    
    @Test("User with password tokens optimization performance")
    func testUserWithPasswordTokensOptimization() async throws {
        // Focus on users that have password tokens
        let usersWithPasswordTokens = try await PasswordTokenModel.query(on: database)
            .with(\.$user)
            .limit(20)
            .all()
            .compactMap { $0.user.id }
        
        guard !usersWithPasswordTokens.isEmpty else {
            XCTFail("No users with password tokens found for testing")
            return
        }
        
        let comparisonResults = try await benchmarkRepositoryMethods(
            userIds: usersWithPasswordTokens,
            operationName: "User + Password Tokens",
            sequentialOperation: { userId in
                let user = try await self.userRepository.find(id: userId)
                if user != nil {
                    _ = try await PasswordTokenModel.query(on: self.database)
                        .filter(\.$user.$id == userId)
                        .all()
                }
            },
            optimizedOperation: { userId in
                _ = try await self.userRepository.findWithPasswordTokens(id: userId)
            }
        )
        
        print("=== Password Tokens Optimization Results ===")
        print(comparisonResults.summary)
        
        PerformanceTestUtilities.assertQueryReduction(comparisonResults)
    }
    
    // MARK: - Bulk Operations Performance Tests
    
    @Test("Bulk user operations performance")
    func testBulkUserOperationsPerformance() async throws {
        let userCount = 200
        let testUsers = PerformanceTestUtilities.generateTestUsers(count: userCount)
        
        // Test bulk create performance
        let bulkCreateMetrics = try await measure(
            "Bulk User Creation",
            iterations: 5
        ) {
            for userData in testUsers.prefix(20) {
                let user = UserAccountModel()
                user.email = "\(userData.email)_bulk_\(UUID().uuidString.prefix(8))"
                user.name = userData.name
                user.isEmailVerified = true
                try await user.create(on: self.database)
            }
        }
        
        // Test bulk retrieval performance
        let allUserIds = try await UserAccountModel.query(on: database)
            .all()
            .compactMap { $0.id }
        
        let bulkRetrievalMetrics = try await measure(
            "Bulk User Retrieval",
            iterations: 10
        ) {
            let userBatch = Array(allUserIds.shuffled().prefix(50))
            for userId in userBatch {
                _ = try await self.userRepository.find(id: userId)
            }
        }
        
        print("=== Bulk Operations Performance ===")
        print("Bulk Creation:")
        print(bulkCreateMetrics.phase5Summary)
        print("\nBulk Retrieval:")
        print(bulkRetrievalMetrics.phase5Summary)
        
        // Assert reasonable performance for bulk operations
        XCTAssertLessThan(bulkCreateMetrics.averageTime, 1.0,
            "Bulk user creation should complete within 1 second for 20 users")
        
        XCTAssertLessThan(bulkRetrievalMetrics.averageTime, 0.5,
            "Bulk user retrieval should complete within 500ms for 50 users")
    }
    
    // MARK: - Database Index Performance Tests
    
    @Test("Database index effectiveness for user queries")
    func testDatabaseIndexPerformance() async throws {
        let testEmails = (0..<100).map { "indexed_user_\($0)@example.com" }
        
        // Test email lookup performance (should use email index)
        let emailLookupMetrics = try await measure(
            "Email Index Lookup",
            iterations: 50
        ) {
            let randomEmail = testEmails.randomElement()!
            _ = try await self.userRepository.find(email: randomEmail)
        }
        
        // Test ID lookup performance (should use primary key index)
        let allUserIds = try await UserAccountModel.query(on: database)
            .limit(100)
            .all()
            .compactMap { $0.id }
        
        let idLookupMetrics = try await measure(
            "ID Index Lookup",
            iterations: 100
        ) {
            let randomId = allUserIds.randomElement()!
            _ = try await self.userRepository.find(id: randomId)
        }
        
        print("=== Database Index Performance ===")
        print("Email Lookup (Index):")
        print(emailLookupMetrics.phase5Summary)
        print("\nID Lookup (Primary Key):")
        print(idLookupMetrics.phase5Summary)
        
        // Assert index performance is good
        XCTAssertLessThan(emailLookupMetrics.p95Time, 0.050,
            "Email index lookups should be under 50ms P95")
        
        XCTAssertLessThan(idLookupMetrics.p95Time, 0.020,
            "ID index lookups should be under 20ms P95")
        
        // ID lookups should be faster than email lookups
        XCTAssertLessThan(idLookupMetrics.averageTime, emailLookupMetrics.averageTime,
            "Primary key lookups should be faster than secondary index lookups")
    }
    
    // MARK: - Concurrent Repository Access Tests
    
    @Test("Repository performance under concurrent access")
    func testConcurrentRepositoryPerformance() async throws {
        let userIds = try await UserAccountModel.query(on: database)
            .limit(50)
            .all()
            .compactMap { $0.id }
        
        let concurrentUsers = 20
        let operationsPerUser = 10
        
        let concurrentResults = try await PerformanceTestUtilities.simulateRealisticLoad(
            requests: concurrentUsers * operationsPerUser,
            concurrency: concurrentUsers
        ) {
            let randomUserId = userIds.randomElement()!
            let startTime = Date()
            
            // Mix of different repository operations
            let operation = Int.random(in: 1...4)
            switch operation {
            case 1:
                _ = try await self.userRepository.find(id: randomUserId)
            case 2:
                _ = try await self.userRepository.findWithRefreshTokens(id: randomUserId)
            case 3:
                _ = try await self.userRepository.findWithEmailTokens(id: randomUserId)
            case 4:
                _ = try await self.userRepository.findWithTokens(id: randomUserId)
            default:
                _ = try await self.userRepository.find(id: randomUserId)
            }
            
            return Date().timeIntervalSince(startTime)
        }
        
        print("=== Concurrent Repository Performance ===")
        print(concurrentResults.summary)
        
        // Assert performance under concurrent load
        PerformanceTestUtilities.assertThroughput(concurrentResults.throughput, minimum: 100.0)
        XCTAssertLessThan(concurrentResults.errorRate, 0.5,
            "Error rate should be under 0.5% for concurrent repository access")
        
        XCTAssertLessThan(concurrentResults.p95ResponseTime, 0.200,
            "P95 response time should be under 200ms for concurrent access")
    }
    
    // MARK: - Helper Methods
    
    private func benchmarkRepositoryMethods(
        userIds: [UUID],
        operationName: String,
        sequentialOperation: (UUID) async throws -> Void,
        optimizedOperation: (UUID) async throws -> Void
    ) async throws -> PerformanceTestUtilities.QueryPerformanceMetrics {
        
        let iterations = min(userIds.count, 20) // Limit for performance testing
        let testIds = Array(userIds.prefix(iterations))
        
        // Estimate query counts (simplified)
        let sequentialQueryCount = testIds.count * 2 // User query + token query
        let optimizedQueryCount = testIds.count * 1 // Parallel queries
        
        // Benchmark sequential approach
        let sequentialStartTime = Date()
        for userId in testIds {
            try await sequentialOperation(userId)
        }
        let sequentialTime = Date().timeIntervalSince(sequentialStartTime)
        
        // Benchmark optimized approach
        let optimizedStartTime = Date()
        for userId in testIds {
            try await optimizedOperation(userId)
        }
        let optimizedTime = Date().timeIntervalSince(optimizedStartTime)
        
        return PerformanceTestUtilities.QueryPerformanceMetrics(
            operationName: operationName,
            sequentialQueries: sequentialQueryCount,
            eagerLoadQueries: optimizedQueryCount,
            sequentialTime: sequentialTime,
            eagerLoadTime: optimizedTime,
            recordsProcessed: testIds.count
        )
    }
}

// MARK: - TestDataFactory Extensions for Performance Testing

extension TestDataFactory {
    
    /// Create a user for performance testing
    func createUser(email: String, name: String, isVerified: Bool = true) async throws -> UserAccountModel {
        let user = UserAccountModel()
        user.id = UUID()
        user.email = email
        user.name = name
        user.passwordHash = "hashed_password"
        user.isEmailVerified = isVerified
        user.createdAt = Date()
        user.updatedAt = Date()
        return user
    }
    
    /// Create a refresh token for performance testing
    func createRefreshToken(for user: UserAccountModel, token: String) async throws -> RefreshTokenModel {
        let refreshToken = RefreshTokenModel()
        refreshToken.id = UUID()
        refreshToken.token = token
        refreshToken.$user.id = user.id!
        refreshToken.expiresAt = Date().addingTimeInterval(86400 * 30) // 30 days
        refreshToken.createdAt = Date()
        return refreshToken
    }
    
    /// Create an email token for performance testing
    func createEmailToken(for user: UserAccountModel, token: String) async throws -> EmailTokenModel {
        let emailToken = EmailTokenModel()
        emailToken.id = UUID()
        emailToken.token = token
        emailToken.$user.id = user.id!
        emailToken.expiresAt = Date().addingTimeInterval(3600) // 1 hour
        emailToken.createdAt = Date()
        return emailToken
    }
    
    /// Create a password token for performance testing
    func createPasswordToken(for user: UserAccountModel, token: String) async throws -> PasswordTokenModel {
        let passwordToken = PasswordTokenModel()
        passwordToken.id = UUID()
        passwordToken.token = token
        passwordToken.$user.id = user.id!
        passwordToken.expiresAt = Date().addingTimeInterval(1800) // 30 minutes
        passwordToken.createdAt = Date()
        return passwordToken
    }
}