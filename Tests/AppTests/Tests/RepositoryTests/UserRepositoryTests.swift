@testable import App
import Fluent
import VaporTesting
import Testing

@Suite(.serialized)
struct UserRepositoryTests {
    let app: Application
    let testWorld: TestWorld
    let repository: DatabaseUserRepository
    
    init() async throws {
        testWorld = try await TestWorld()
        self.app = testWorld.app
        self.repository = DatabaseUserRepository(database: app.db)
        try await app.autoMigrate()
    }
    
    @Test("DatabaseUserRepository can be instantiated with database")
    func defaultProvider() async throws {
        // Test that DatabaseUserRepository can be instantiated with database
        let defaultProvider = DatabaseUserRepository(database: app.db)
        #expect(type(of: defaultProvider) == DatabaseUserRepository.self)
    }
    
    @Test("User can be created and retrieved")
    func creatingUser() async throws {
        let user = UserAccountModel(email: "test-\(UUID().uuidString.lowercased())@test.com", password: "123")
        try await repository.create(user)
        
        #expect(user.id != nil)
        
        let userRetrieved = try await UserAccountModel.find(user.id, on: app.db)
        #expect(userRetrieved != nil)
    }
    
    @Test("User can be deleted")
    func deletingUser() async throws {
        let user = UserAccountModel(email: "test-\(UUID().uuidString.lowercased())@test.com", password: "123")
        try await user.create(on: app.db)
        let count = try await UserAccountModel.query(on: app.db).count()
        #expect(count == 1)
        
        try await repository.delete(id: user.requireID())
        let countAfterDelete = try await UserAccountModel.query(on: app.db).count()
        #expect(countAfterDelete == 0)
    }
    
    @Test("Repository can retrieve all users")
    func getAllUsers() async throws {
        let user = UserAccountModel(email: "test-\(UUID().uuidString.lowercased())@test.com", password: "123")
        let user2 = UserAccountModel(email: "test2@test.com", password: "123")
        
        try await user.create(on: app.db)
        try await user2.create(on: app.db)
        
        let users = try await repository.all()
        #expect(users.count == 2)
    }
    
    @Test("User can be found by ID")
    func findUserById() async throws {
        let user = UserAccountModel(email: "test-\(UUID().uuidString.lowercased())@test.com", password: "123")
        try await user.create(on: app.db)
        
        let userFound = try await repository.find(id: user.requireID())
        #expect(userFound != nil)
    }
    
    @Test("User can be found by Apple ID")
    func findByAppleID() async throws {
        let user = UserAccountModel(email: "test@test.com", password: "123", appleUserIdentifier: "1")
        try await user.create(on: app.db)
        
        let foundUser = try await repository.find(appleUserIdentifier: "1")
        #expect(foundUser != nil)
    }

    @Test("User can be found by email")
    func findByEmail() async throws {
        let user = UserAccountModel(email: "test@test.com", password: "123", appleUserIdentifier: "1")
        try await user.create(on: app.db)
        
        let foundUser = try await repository.find(email: "test@test.com")
        #expect(foundUser != nil)
    }

    @Test("User field values can be updated")
    func setFieldValue() async throws {
        let user = UserAccountModel(email: "test@test.com", password: "123", isEmailVerified: false)
        try await user.create(on: app.db)
        user.isEmailVerified = true
        try await repository.update(user)
        
        let updatedUser = try await UserAccountModel.find(user.id!, on: app.db)
        #expect(updatedUser!.isEmailVerified == true)
    }
    
    @Test("Email lookup works correctly with multiple users")
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
    
    @Test("User information can be updated")
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