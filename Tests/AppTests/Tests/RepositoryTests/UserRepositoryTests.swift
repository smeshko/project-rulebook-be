@testable import App
import Fluent
import VaporTesting
import Testing

@Suite(.serialized)
struct UserRepositoryTests {
    let app: Application
    let testWorld: IsolatedTestWorld
    let repository: DatabaseUserRepository
    
    init() async throws {
        testWorld = try await IsolatedTestWorld()
        self.app = testWorld.app
        self.repository = DatabaseUserRepository(database: app.db)
        try await app.autoMigrate()
        
        // Database is automatically clean with IsolatedTestWorld (in-memory SQLite)
        // No need to clear data as each suite gets its own isolated database
    }
    
    
    @Test("DatabaseUserRepository can be instantiated with database", .tags(.p2Extended, .database, .unit))
    func defaultProvider() async throws {
        // Test that DatabaseUserRepository can be instantiated with database
        let defaultProvider = DatabaseUserRepository(database: app.db)
        #expect(type(of: defaultProvider) == DatabaseUserRepository.self)
    }
    
    @Test("User can be created and retrieved", .tags(.p0Critical, .database, .unit))
    func creatingUser() async throws {
        let user = UserAccountModel(email: "test-\(UUID().uuidString.lowercased())@test.com", password: "123")
        try await repository.create(user)
        
        #expect(user.id != nil)
        
        let userRetrieved = try await UserAccountModel.find(user.id, on: app.db)
        #expect(userRetrieved != nil)
        
        // Cleanup
    }
    
    @Test("User can be deleted", .tags(.p0Critical, .database, .unit))
    func deletingUser() async throws {
        let user = UserAccountModel(email: "test-\(UUID().uuidString.lowercased())@test.com", password: "123")
        try await user.create(on: app.db)
        let count = try await UserAccountModel.query(on: app.db).count()
        #expect(count == 1)
        
        try await repository.delete(id: user.requireID())
        let countAfterDelete = try await UserAccountModel.query(on: app.db).count()
        #expect(countAfterDelete == 0)
    }
    
    @Test("Repository can retrieve all users", .tags(.p1Core, .database, .unit))
    func getAllUsers() async throws {
        // Clean database before this test to ensure clean state
        
        let user1Email = "test-\(UUID().uuidString.lowercased())@test.com"
        let user2Email = "test2-\(UUID().uuidString.lowercased())@test.com"
        
        let user1 = UserAccountModel(email: user1Email, password: "123")
        let user2 = UserAccountModel(email: user2Email, password: "123")
        
        try await user1.create(on: app.db)
        try await user2.create(on: app.db)
        
        let users = try await repository.all()
        #expect(users.count == 2)
        
        // Verify that our specific users are included
        let foundEmails = Set(users.map { $0.email })
        #expect(foundEmails.contains(user1Email))
        #expect(foundEmails.contains(user2Email))
    }
    
    @Test("User can be found by ID", .tags(.p0Critical, .database, .unit))
    func findUserById() async throws {
        let user = UserAccountModel(email: "test-\(UUID().uuidString.lowercased())@test.com", password: "123")
        try await user.create(on: app.db)
        
        let userFound = try await repository.find(id: user.requireID())
        #expect(userFound != nil)
    }
    
    @Test("User can be found by Apple ID", .tags(.p1Core, .database, .unit))
    func findByAppleID() async throws {
        let user = UserAccountModel(email: "test@test.com", password: "123", appleUserIdentifier: "1")
        try await user.create(on: app.db)
        
        let foundUser = try await repository.find(appleUserIdentifier: "1")
        #expect(foundUser != nil)
    }

    @Test("User can be found by email", .tags(.p0Critical, .database, .unit))
    func findByEmail() async throws {
        let email = "test-find-\(UUID().uuidString.lowercased())@test.com"
        let user = UserAccountModel(email: email, password: "123", appleUserIdentifier: "1")
        try await user.create(on: app.db)
        
        let foundUser = try await repository.find(email: email)
        #expect(foundUser != nil)
    }

    @Test("User field values can be updated", .tags(.p0Critical, .database, .unit))
    func setFieldValue() async throws {
        let email = "test-update-\(UUID().uuidString.lowercased())@test.com"
        let user = UserAccountModel(email: email, password: "123", isEmailVerified: false)
        try await user.create(on: app.db)
        user.isEmailVerified = true
        try await repository.update(user)
        
        let updatedUser = try await UserAccountModel.find(user.id!, on: app.db)
        #expect(updatedUser!.isEmailVerified == true)
    }
    
    @Test("Email lookup works correctly with multiple users", .tags(.p1Core, .database, .unit))
    func userEmailLookup() async throws {
        let user1 = UserAccountModel(email: "user1@test.com", password: "123")
        let user2 = UserAccountModel(email: "user2@test.com", password: "123")
        
        try await user1.create(on: app.db)
        try await user2.create(on: app.db)
        
        let foundUser1 = try await repository.find(email: "user1@test.com")
        let foundUser2 = try await repository.find(email: "user2@test.com")
        let notFound = try await repository.find(email: "nonexistent@test.com")
        
        #expect(foundUser1 != nil)
        #expect(foundUser2 != nil)
        #expect(notFound == nil)
        
        #expect(foundUser1?.email == "user1@test.com")
        #expect(foundUser2?.email == "user2@test.com")
    }
    
    @Test("User information can be updated", .tags(.p1Core, .database, .unit))
    func userUpdate() async throws {
        let user = UserAccountModel(
            email: "original@test.com", 
            password: "123",
            firstName: "Original",
            lastName: "Name"
        )
        try await user.create(on: app.db)
        
        // Update user fields
        user.firstName = "Updated"
        user.lastName = "UpdatedName"
        user.email = "updated@test.com"
        
        try await repository.update(user)
        
        let updatedUser = try await UserAccountModel.find(user.id!, on: app.db)
        #expect(updatedUser?.firstName == "Updated")
        #expect(updatedUser?.lastName == "UpdatedName")
        #expect(updatedUser?.email == "updated@test.com")
    }
}