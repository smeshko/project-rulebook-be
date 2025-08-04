import Fluent
import Vapor

struct UserController {
    func getCurrentUser(_ req: Request) async throws -> User.Detail.Response {
        let user = try req.auth.require(UserAccountModel.self)
        return try .init(from: user)
    }
    
    func delete(_ req: Request) async throws -> HTTPStatus {
        let user = try req.auth.require(UserAccountModel.self)
        try await req.repositories.users.delete(id: user.requireID())
        return .ok
    }
    
    func list(_ req: Request) async throws -> [User.List.Response] {
        try await req.repositories.users.all().asyncMap { model in
            try User.List.Response(from: model)
        }
    }
    
    func patch(_ req: Request) async throws -> User.Update.Response {
        let request = try req.content.decode(User.Update.Request.self)
        let user = try req.auth.require(UserAccountModel.self)
        
        if let email = request.email {
            user.email = email
        }
        
        if let firstName = request.firstName {
            user.firstName = firstName
        }
        
        if let lastName = request.lastName {
            user.lastName = lastName
        }
        
        try await req.repositories.users.update(user)
        return try .init(from: user)
    }
}
