import Vapor

extension User.Detail.Response: Content {
    init(from model: UserAccountModel) throws {
        try self.init(
            id: model.requireID(),
            email: model.email,
            firstName: model.firstName,
            lastName: model.lastName,
            avatar: model.avatar,
            isAdmin: model.isAdmin,
            isEmailVerified: model.isEmailVerified
        )
    }
}

extension User.List.Response: Content {
    init(from model: UserAccountModel) throws {
        self.init(
            id: try model.requireID(),
            firstName: model.firstName,
            lastName: model.lastName,
            avatar: model.avatar,
            email: model.email
        )
    }
}

extension User.Update.Response: Content {
    init(from model: UserAccountModel) throws {
        try self.init(
            id: model.requireID(),
            email: model.email,
            firstName: model.firstName,
            lastName: model.lastName,
            isAdmin: model.isAdmin,
            isEmailVerified: model.isEmailVerified
        )
    }
}
