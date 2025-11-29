## TASK-002: Configure OpenAPI Metadata and Security Schemes

---
**Status:** COMPLETE
**Branch:** feature/openapi-documentation
**Type:** IMPLEMENTATION
**Phase:** 1
**Depends On:** TASK-001

---

### Overview

Configure comprehensive OpenAPI metadata including API description, server URLs, and security scheme definitions. This provides context for the entire API specification and enables Swagger UI authentication testing.

### Files Modified

- `Sources/App/Entrypoint/configure.swift`

### Implementation Steps

- [x] Expand OpenAPI configuration with detailed API description
- [x] Add server URL configuration (localhost for development, production URL if available)
- [x] Define `bearerAuth` security scheme for JWT authentication
- [x] Define request body schema for credential-based authentication
- [x] Add API contact information and license (if applicable)
- [x] Verify enhanced metadata appears in `/openapi.json` response

### Code Example

**File: `Sources/App/Entrypoint/configure.swift`**

```swift
import Vapor
import VaporToOpenAPI
import OpenAPIKit

public func configure(_ app: Application) throws {
    // ... existing configuration ...
    try app.setupModules()

    // Register OpenAPI endpoint with full metadata
    app.get("openapi.json") { req -> Response in
        let openAPI = try req.application.routes.openAPI(
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
                .init(url: URL(string: "http://localhost:8080")!, description: "Development"),
            ],
            components: .init(
                securitySchemes: [
                    "bearerAuth": .init(
                        type: .http,
                        scheme: "bearer",
                        bearerFormat: "JWT",
                        description: "JWT access token obtained from /api/auth/sign-in or /api/auth/sign-up"
                    )
                ]
            )
        )
        return try await openAPI.encodeResponse(for: req)
    }

    // ... rest of configure.swift ...
}
```

**Reference: Security schemes used in middleware**

From `UserPayloadAuthenticator.swift:1-20` (JWT authentication):
```swift
struct UserPayloadAuthenticator: AsyncJWTAuthenticator {
    typealias Payload = TokenPayload

    func authenticate(jwt: Payload, for request: Request) async throws {
        let payload = try request.jwt.verify(as: Payload.self)
        guard let user = try await request.repositories.users.find(id: payload.userID) else {
            throw AuthenticationError.userNotAuthorized
        }
        request.auth.login(user)
    }
}
```

From `AuthRouter.swift:11-13` (routes using JWT):
```swift
api
    .grouped(UserAccountModel.guard())  // Requires JWT
    .post("logout", use: controller.logout)
```

### Success Criteria

- [x] Build succeeds without errors
- [x] `/openapi.json` contains full API description
- [x] `servers` array includes development server URL
- [x] `components.securitySchemes.bearerAuth` is defined
- [x] Security scheme has correct type (http) and scheme (bearer)
- [x] No compiler warnings introduced

### Verification Commands

```bash
# Build project
swift build

# Run and verify OpenAPI metadata
swift run &
sleep 5

# Check info section
curl -s http://localhost:8080/openapi.json | jq '.info'

# Check servers
curl -s http://localhost:8080/openapi.json | jq '.servers'

# Check security schemes
curl -s http://localhost:8080/openapi.json | jq '.components.securitySchemes'

pkill -f "swift run"
```

### Notes

- The `bearerAuth` security scheme will be referenced in subsequent tasks when documenting protected endpoints
- Production server URL can be added later when deployment URL is known
- Security schemes are defined globally but applied per-endpoint in router files
