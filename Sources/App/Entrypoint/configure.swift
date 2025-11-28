import Vapor
import VaporToOpenAPI

extension Environment {
    static var staging: Environment {
        .custom(name: "staging")
    }
}

public func configure(_ app: Application) throws {
    // Initialize configuration first
    try app.setupConfiguration()
    
    try app.setupDB()
    try app.setupJWT()
    try app.setupRedis()     // Setup Redis before services that depend on it
    try app.setupServices()  // Services must be set up before aspects
    try app.setupMiddleware() // Now middleware can access services
    try app.setupModules()

    // OpenAPI endpoint
    app.get("openapi.json") { req -> Response in
        let openAPI = req.application.routes.openAPI(
            info: .init(
                title: "Project Rulebook API",
                version: "1.0.0"
            )
        )
        return try await openAPI.encodeResponse(for: req)
    }

    // Health check endpoint for Railway
    app.get("health") { req -> [String: String] in
        return [
            "status": "healthy"
        ]
    }

    try app.autoMigrate().wait()
}
