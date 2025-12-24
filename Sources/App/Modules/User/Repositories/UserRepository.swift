import Fluent
import Vapor

protocol UserRepository: Repository {
    func find(id: UUID) async throws -> UserAccountModel?
    func find(email: String) async throws -> UserAccountModel?
    func find(appleUserIdentifier: String) async throws -> UserAccountModel?
    func create(_ model: UserAccountModel) async throws
    func all() async throws -> [UserAccountModel]
    func update(_ model: UserAccountModel) async throws
    
    // Optimized methods with eager loading to prevent N+1 queries
    func findWithTokens(id: UUID) async throws -> (user: UserAccountModel?, refreshTokens: [RefreshTokenModel], emailTokens: [EmailTokenModel], passwordTokens: [PasswordTokenModel])
    func findWithRefreshTokens(id: UUID) async throws -> (user: UserAccountModel?, refreshTokens: [RefreshTokenModel])
    func findWithEmailTokens(id: UUID) async throws -> (user: UserAccountModel?, emailTokens: [EmailTokenModel])
    func findWithPasswordTokens(id: UUID) async throws -> (user: UserAccountModel?, passwordTokens: [PasswordTokenModel])
}

struct DatabaseUserRepository: UserRepository, DatabaseRepository {
    typealias Model = UserAccountModel
    
    let database: Database

    func find(appleUserIdentifier: String) async throws -> UserAccountModel? {
        try await UserAccountModel.query(on: database)
            .filter(\.$appleUserIdentifier == appleUserIdentifier)
            .first()
    }

    func find(email: String) async throws -> UserAccountModel? {
        try await UserAccountModel.query(on: database)
            .filter(\.$email == email)
            .first()
    }
    
    func find(id: UUID) async throws -> UserAccountModel? {
        try await UserAccountModel.query(on: database)
            .filter(\.$id == id)
            .first()
    }
    
    func all() async throws -> [UserAccountModel] {
        try await UserAccountModel.query(on: database)
            .all()
    }
    
    func create(_ model: UserAccountModel) async throws {
        try await model.create(on: database)
    }
    
    func update(_ model: UserAccountModel) async throws {
        try await model.update(on: database)
    }
    
    // MARK: - Optimized methods with eager loading to prevent N+1 queries
    
    func findWithTokens(id: UUID) async throws -> (user: UserAccountModel?, refreshTokens: [RefreshTokenModel], emailTokens: [EmailTokenModel], passwordTokens: [PasswordTokenModel]) {
        // Fetch user and all related tokens in parallel to minimize database round trips
        async let userTask = UserAccountModel.query(on: database)
            .filter(\.$id == id)
            .first()
        
        async let refreshTokensTask = RefreshTokenModel.query(on: database)
            .filter(\.$user.$id == id)
            .with(\.$user)
            .all()
        
        async let emailTokensTask = EmailTokenModel.query(on: database)
            .filter(\.$user.$id == id)
            .with(\.$user)
            .all()
        
        async let passwordTokensTask = PasswordTokenModel.query(on: database)
            .filter(\.$user.$id == id)
            .with(\.$user)
            .all()
        
        let (user, refreshTokens, emailTokens, passwordTokens) = try await (userTask, refreshTokensTask, emailTokensTask, passwordTokensTask)
        
        return (user: user, refreshTokens: refreshTokens, emailTokens: emailTokens, passwordTokens: passwordTokens)
    }
    
    func findWithRefreshTokens(id: UUID) async throws -> (user: UserAccountModel?, refreshTokens: [RefreshTokenModel]) {
        async let userTask = UserAccountModel.query(on: database)
            .filter(\.$id == id)
            .first()
        
        async let refreshTokensTask = RefreshTokenModel.query(on: database)
            .filter(\.$user.$id == id)
            .with(\.$user)
            .all()
        
        let (user, refreshTokens) = try await (userTask, refreshTokensTask)
        return (user: user, refreshTokens: refreshTokens)
    }
    
    func findWithEmailTokens(id: UUID) async throws -> (user: UserAccountModel?, emailTokens: [EmailTokenModel]) {
        async let userTask = UserAccountModel.query(on: database)
            .filter(\.$id == id)
            .first()
        
        async let emailTokensTask = EmailTokenModel.query(on: database)
            .filter(\.$user.$id == id)
            .with(\.$user)
            .all()
        
        let (user, emailTokens) = try await (userTask, emailTokensTask)
        return (user: user, emailTokens: emailTokens)
    }
    
    func findWithPasswordTokens(id: UUID) async throws -> (user: UserAccountModel?, passwordTokens: [PasswordTokenModel]) {
        async let userTask = UserAccountModel.query(on: database)
            .filter(\.$id == id)
            .first()
        
        async let passwordTokensTask = PasswordTokenModel.query(on: database)
            .filter(\.$user.$id == id)
            .with(\.$user)
            .all()
        
        let (user, passwordTokens) = try await (userTask, passwordTokensTask)
        return (user: user, passwordTokens: passwordTokens)
    }
}

extension Application.Repositories {
    var users: any UserRepository {
        application.userRepository
    }
}

extension Request.Services {
    var users: any UserRepository {
        // Use pre-resolved service from ServiceCache for immediate synchronous access
        request.application.userRepository
    }
}
