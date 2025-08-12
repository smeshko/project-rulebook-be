@testable import App
import XCTest
import XCTVapor
import Vapor

/// Performance tests for user profile endpoints to verify Clean Architecture refactoring performance.
///
/// These tests validate that the introduction of use cases and domain services
/// hasn't degraded the performance of user profile operations.
final class UserProfilePerformanceTests: XCTestCase {
    var app: Application!
    var testWorld: TestWorld!
    var performanceTestCase: PerformanceTestCase!
    var testUserToken: String = ""
    var testUserId: UUID = UUID()
    
    override func setUp() async throws {
        app = try await Application.make(.testing)
        testWorld = try TestWorld(app: app)
        performanceTestCase = try await PerformanceTestCase()
        
        // Run migrations
        try await app.autoMigrate()
        
        // Create a test user for profile operations
        let signUpRequest = Auth.SignUp.Request(
            email: "profile-test@example.com",
            password: "TestPass123!",
            firstName: "Profile",
            lastName: "Test"
        )
        
        try await app.test(.POST, "/api/auth/sign-up", beforeRequest: { req in
            try req.content.encode(signUpRequest)
        }, afterResponse: { res in
            let response = try res.content.decode(Auth.SignUp.Response.self)
            testUserToken = response.token.accessToken
            testUserId = response.user.id
        })
    }
    
    override func tearDown() async throws {
        try await app.autoRevert()
        app.shutdown()
    }
    
    // MARK: - Get Current User Performance
    
    func testGetCurrentUserPerformance() async throws {
        let metrics = try await performanceTestCase.measure(
            "Get Current User Performance",
            iterations: 200
        ) {
            try await app.test(.GET, "/api/user", beforeRequest: { req in
                req.headers.bearerAuthorization = BearerAuthorization(token: testUserToken)
            }, afterResponse: { res in
                XCTAssertEqual(res.status, .ok)
            })
        }
        
        print(metrics.summary)
        
        // Performance baselines
        XCTAssertLessThan(metrics.averageTime, 0.02, "Get current user average time should be under 20ms")
        XCTAssertLessThan(metrics.maximumTime, 0.04, "Get current user max time should be under 40ms")
        XCTAssertLessThan(metrics.standardDeviation, 0.01, "Get current user should have consistent performance")
    }
    
    func testUpdateUserProfilePerformance() async throws {
        let metrics = try await performanceTestCase.measure(
            "Update User Profile Performance",
            iterations: 100
        ) {
            let updateRequest = User.Patch.Request(
                firstName: "Updated",
                lastName: "Name\(Int.random(in: 0...1000))"
            )
            
            try await app.test(.PATCH, "/api/user", beforeRequest: { req in
                req.headers.bearerAuthorization = BearerAuthorization(token: testUserToken)
                try req.content.encode(updateRequest)
            }, afterResponse: { res in
                XCTAssertEqual(res.status, .ok)
            })
        }
        
        print(metrics.summary)
        
        // Performance baselines
        XCTAssertLessThan(metrics.averageTime, 0.03, "Update profile average time should be under 30ms")
        XCTAssertLessThan(metrics.maximumTime, 0.06, "Update profile max time should be under 60ms")
    }
    
    // MARK: - List Users Performance (Admin)
    
    func testListUsersPerformance() async throws {
        // Create admin user
        let adminEmail = "admin-perf@example.com"
        let adminPassword = "AdminPass123!"
        var adminToken = ""
        
        // Create admin user (would need to set isAdmin flag in real scenario)
        let adminSignUp = Auth.SignUp.Request(
            email: adminEmail,
            password: adminPassword,
            firstName: "Admin",
            lastName: "User"
        )
        
        try await app.test(.POST, "/api/auth/sign-up", beforeRequest: { req in
            try req.content.encode(adminSignUp)
        }, afterResponse: { res in
            let response = try res.content.decode(Auth.SignUp.Response.self)
            adminToken = response.token.accessToken
        })
        
        // Update user to admin (bypassing normal flow for testing)
        let user = try await UserAccountModel.query(on: app.db)
            .filter(\.$email == adminEmail)
            .first()
        user?.isAdmin = true
        try await user?.save(on: app.db)
        
        // Create additional test users
        for i in 0..<50 {
            let email = "list-test\(i)@example.com"
            let request = Auth.SignUp.Request(
                email: email,
                password: "TestPass123!",
                firstName: "User",
                lastName: "\(i)"
            )
            
            try await app.test(.POST, "/api/auth/sign-up", beforeRequest: { req in
                try req.content.encode(request)
            })
        }
        
        // Measure list users performance
        let metrics = try await performanceTestCase.measure(
            "List Users Performance",
            iterations: 50
        ) {
            try await app.test(.GET, "/api/users", beforeRequest: { req in
                req.headers.bearerAuthorization = BearerAuthorization(token: adminToken)
            }, afterResponse: { res in
                XCTAssertEqual(res.status, .ok)
            })
        }
        
        print(metrics.summary)
        
        // Performance baselines for listing ~50 users
        XCTAssertLessThan(metrics.averageTime, 0.05, "List users average time should be under 50ms")
        XCTAssertLessThan(metrics.maximumTime, 0.1, "List users max time should be under 100ms")
    }
    
    // MARK: - Delete User Performance
    
    func testDeleteUserAccountPerformance() async throws {
        // Create multiple test users for deletion
        var userTokens: [String] = []
        
        for i in 0..<50 {
            let email = "delete-test\(i)@example.com"
            let request = Auth.SignUp.Request(
                email: email,
                password: "TestPass123!",
                firstName: "Delete",
                lastName: "Test\(i)"
            )
            
            try await app.test(.POST, "/api/auth/sign-up", beforeRequest: { req in
                try req.content.encode(request)
            }, afterResponse: { res in
                let response = try res.content.decode(Auth.SignUp.Response.self)
                userTokens.append(response.token.accessToken)
            })
        }
        
        // Measure delete performance
        var tokenIndex = 0
        let metrics = try await performanceTestCase.measure(
            "Delete User Account Performance",
            iterations: 50
        ) {
            let token = userTokens[tokenIndex]
            tokenIndex += 1
            
            try await app.test(.DELETE, "/api/user", beforeRequest: { req in
                req.headers.bearerAuthorization = BearerAuthorization(token: token)
            }, afterResponse: { res in
                XCTAssertEqual(res.status, .noContent)
            })
        }
        
        print(metrics.summary)
        
        // Performance baselines
        XCTAssertLessThan(metrics.averageTime, 0.04, "Delete account average time should be under 40ms")
        XCTAssertLessThan(metrics.maximumTime, 0.08, "Delete account max time should be under 80ms")
    }
    
    // MARK: - Concurrent User Operations
    
    func testConcurrentUserProfileReads() async throws {
        // Create multiple users with tokens
        var userTokens: [String] = []
        
        for i in 0..<10 {
            let email = "concurrent-read\(i)@example.com"
            let request = Auth.SignUp.Request(
                email: email,
                password: "TestPass123!",
                firstName: "Concurrent",
                lastName: "Read\(i)"
            )
            
            try await app.test(.POST, "/api/auth/sign-up", beforeRequest: { req in
                try req.content.encode(request)
            }, afterResponse: { res in
                let response = try res.content.decode(Auth.SignUp.Response.self)
                userTokens.append(response.token.accessToken)
            })
        }
        
        // Test concurrent profile reads
        let concurrentRequests = 100
        let startTime = Date()
        
        try await withThrowingTaskGroup(of: Void.self) { group in
            for i in 0..<concurrentRequests {
                let token = userTokens[i % userTokens.count]
                
                group.addTask {
                    try await self.app.test(.GET, "/api/user", beforeRequest: { req in
                        req.headers.bearerAuthorization = BearerAuthorization(token: token)
                    }, afterResponse: { res in
                        XCTAssertEqual(res.status, .ok)
                    })
                }
            }
            
            try await group.waitForAll()
        }
        
        let totalTime = Date().timeIntervalSince(startTime)
        let requestsPerSecond = Double(concurrentRequests) / totalTime
        
        print("""
        Concurrent Profile Read Performance:
        Total Requests: \(concurrentRequests)
        Total Time: \(String(format: "%.4f", totalTime))s
        Requests per Second: \(String(format: "%.2f", requestsPerSecond))
        """)
        
        XCTAssertLessThan(totalTime, 3.0, "100 concurrent profile reads should complete within 3 seconds")
        XCTAssertGreaterThan(requestsPerSecond, 30, "Should handle at least 30 requests per second")
    }
    
    func testConcurrentUserProfileUpdates() async throws {
        // Create multiple users with tokens
        var userTokens: [String] = []
        
        for i in 0..<10 {
            let email = "concurrent-update\(i)@example.com"
            let request = Auth.SignUp.Request(
                email: email,
                password: "TestPass123!",
                firstName: "Concurrent",
                lastName: "Update\(i)"
            )
            
            try await app.test(.POST, "/api/auth/sign-up", beforeRequest: { req in
                try req.content.encode(request)
            }, afterResponse: { res in
                let response = try res.content.decode(Auth.SignUp.Response.self)
                userTokens.append(response.token.accessToken)
            })
        }
        
        // Test concurrent profile updates
        let concurrentRequests = 50
        let startTime = Date()
        
        try await withThrowingTaskGroup(of: Void.self) { group in
            for i in 0..<concurrentRequests {
                let token = userTokens[i % userTokens.count]
                
                group.addTask {
                    let updateRequest = User.Patch.Request(
                        firstName: "Updated\(i)",
                        lastName: "Concurrent\(i)"
                    )
                    
                    try await self.app.test(.PATCH, "/api/user", beforeRequest: { req in
                        req.headers.bearerAuthorization = BearerAuthorization(token: token)
                        try req.content.encode(updateRequest)
                    }, afterResponse: { res in
                        XCTAssertEqual(res.status, .ok)
                    })
                }
            }
            
            try await group.waitForAll()
        }
        
        let totalTime = Date().timeIntervalSince(startTime)
        
        print("""
        Concurrent Profile Update Performance:
        Total Requests: \(concurrentRequests)
        Total Time: \(String(format: "%.4f", totalTime))s
        Average Time per Request: \(String(format: "%.4f", totalTime / Double(concurrentRequests)))s
        """)
        
        XCTAssertLessThan(totalTime, 4.0, "50 concurrent profile updates should complete within 4 seconds")
    }
    
    // MARK: - JWT Token Validation Performance
    
    func testJWTValidationPerformance() async throws {
        // This tests the performance of JWT validation which happens on every authenticated request
        let metrics = try await performanceTestCase.measure(
            "JWT Token Validation Performance",
            iterations: 500
        ) {
            try await app.test(.GET, "/api/user", beforeRequest: { req in
                req.headers.bearerAuthorization = BearerAuthorization(token: testUserToken)
            }, afterResponse: { res in
                XCTAssertEqual(res.status, .ok)
            })
        }
        
        print(metrics.summary)
        
        // JWT validation should be very fast
        XCTAssertLessThan(metrics.averageTime, 0.015, "JWT validation average time should be under 15ms")
        XCTAssertLessThan(metrics.maximumTime, 0.03, "JWT validation max time should be under 30ms")
    }
    
    // MARK: - Database Connection Pool Performance
    
    func testDatabaseConnectionPoolPerformance() async throws {
        // Test how well the connection pool handles many rapid requests
        let concurrentRequests = 200
        let startTime = Date()
        
        try await withThrowingTaskGroup(of: Void.self) { group in
            for _ in 0..<concurrentRequests {
                group.addTask {
                    try await self.app.test(.GET, "/api/user", beforeRequest: { req in
                        req.headers.bearerAuthorization = BearerAuthorization(token: self.testUserToken)
                    }, afterResponse: { res in
                        XCTAssertEqual(res.status, .ok)
                    })
                }
            }
            
            try await group.waitForAll()
        }
        
        let totalTime = Date().timeIntervalSince(startTime)
        let requestsPerSecond = Double(concurrentRequests) / totalTime
        
        print("""
        Database Connection Pool Performance:
        Total Requests: \(concurrentRequests)
        Total Time: \(String(format: "%.4f", totalTime))s
        Requests per Second: \(String(format: "%.2f", requestsPerSecond))
        """)
        
        // Should handle high concurrent load efficiently
        XCTAssertGreaterThan(requestsPerSecond, 50, "Should handle at least 50 requests per second with connection pooling")
    }
}