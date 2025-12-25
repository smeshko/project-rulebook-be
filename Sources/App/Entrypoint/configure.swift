import Vapor
import VaporToOpenAPI
import SwiftOpenAPI

extension Environment {
    static var staging: Environment {
        .custom(name: "staging")
    }
}

public func configure(_ app: Application) async throws {
    // Initialize configuration first
    try app.setupConfiguration()

    try app.setupDB()
    try await app.setupJWT()
    try app.setupRedis()     // Setup Redis before services that depend on it
    try app.setupServices()  // Services must be set up before aspects
    try app.setupMiddleware() // Now middleware can access services
    try app.setupModules()

    // Health check endpoint for Railway
    app.get("health") { req -> [String: String] in
        return [
            "status": "healthy"
        ]
    }
    .openAPI(description: "Health check endpoint for monitoring and deployment systems. Returns simple status indicator.")
    .response(statusCode: .ok, body: .type([String: String].self))

    try await app.autoMigrate()
}
