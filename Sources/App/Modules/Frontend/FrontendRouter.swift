import Vapor
import VaporToOpenAPI
import SwiftOpenAPI

struct FrontendRouter: RouteCollection {

    let controller = FrontendController()

    func boot(routes: RoutesBuilder) throws {
        // OpenAPI documentation endpoints
        setupOpenAPIEndpoints(routes: routes)

        // HTML frontend pages
        setupFrontendPages(routes: routes)
    }

    private func setupOpenAPIEndpoints(routes: RoutesBuilder) {
        // OpenAPI specification endpoint
        routes.get("openapi.json") { req -> Response in
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
                            description: "JWT access token obtained from /api/v1/auth/sign-in or /api/v1/auth/sign-up",
                            scheme: .bearer,
                            bearerFormat: "JWT"
                        ))
                    ]
                )
            )
            return try await openAPI.encodeResponse(for: req)
        }
        .excludeFromOpenAPI()

        // Serve Swagger UI at /docs
        routes.get("docs") { req -> Response in
            let html = try String(contentsOfFile: req.application.directory.workingDirectory + "Sources/App/Common/OpenAPI/swagger-ui.html", encoding: .utf8)
            return Response(
                status: .ok,
                headers: ["Content-Type": "text/html"],
                body: .init(string: html)
            )
        }
        .excludeFromOpenAPI()

        // Redirect /swagger to /docs for discoverability
        routes.get("swagger") { req -> Response in
            return req.redirect(to: "/docs", redirectType: .permanent)
        }
        .excludeFromOpenAPI()
    }

    private func setupFrontendPages(routes: RoutesBuilder) {
        let frontend = routes
            .groupedOpenAPI(tags: .init(name: "Frontend", description: "HTML web pages for email verification and password reset"))

        frontend
            .get("verify-email", use: controller.verifyEmail)
            .openAPI(
                description: "Email verification page. User clicks link from verification email with token query parameter. Returns HTML success/error page.",
                query: ["token": .string]
            )
            .response(statusCode: .ok, description: "HTML page")

        frontend
            .get("reset-password", use: controller.resetPassword)
            .openAPI(
                description: "Password reset form page. User clicks link from password reset email with token query parameter. Returns HTML form to enter new password.",
                query: ["token": .string]
            )
            .response(statusCode: .ok, description: "HTML form")

        frontend
            .post("reset-password", use: controller.resetPasswordAction)
            .openAPI(description: "Process password reset form submission. Validates token and updates password. Returns HTML success/error page.")
            .response(statusCode: .ok, description: "HTML success/error page")
    }
}
