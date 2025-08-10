import Vapor

extension Environment {
    static var staging: Environment {
        .custom(name: "staging")
    }
}

public func configure(_ app: Application) throws {
    // Initialize configuration first
    try app.setupConfiguration()
    
    try app.setupMiddleware()
    try app.setupDB()
    try app.setupJWT()
    try app.setupModules()
    try app.setupServices()

    try app.autoMigrate().wait()
}
