import Vapor
import VaporToOpenAPI
import SwiftOpenAPI

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

    // OpenAPI endpoint with comprehensive metadata
    app.get("openapi.json") { req -> Response in
        let openAPI = req.application.routes.openAPI(
            info: .init(
                title: "Project Rulebook API",
                description: """
                Board game rulebook API providing authentication, user management, \
                AI-powered game rule generation, and cache administration.

                Features:
                - User authentication with JWT tokens and Apple Sign In
                - AI-powered game box image recognition
                - Automated rules summary generation
                - Administrative cache management
                """,
                version: "1.0.0"
            ),
            servers: [
                .init(url: "http://localhost:8080", description: "Development"),
            ],
            components: .init(
                securitySchemes: [
                    "bearerAuth": .value(SecuritySchemeObject(
                        type: .http,
                        description: "JWT access token obtained from /api/auth/sign-in or /api/auth/sign-up",
                        scheme: .bearer,
                        bearerFormat: "JWT"
                    ))
                ]
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
