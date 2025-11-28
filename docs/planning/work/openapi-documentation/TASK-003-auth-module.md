## TASK-003: Document Auth Module Endpoints

---
**Status:** COMPLETE
**Branch:** feature/openapi-documentation
**Type:** IMPLEMENTATION
**Phase:** 1
**Depends On:** TASK-002

---

### Overview

Add OpenAPI documentation metadata to all 6 Auth module endpoints, including descriptions, tags, request/response schemas, and security requirements. This serves as the proof-of-concept for the documentation pattern applied to other modules.

### Files Modified

- `Sources/App/Modules/Auth/AuthRouter.swift`

### Implementation Steps

- [x] Add "Auth" tag to the auth route group
- [x] Document sign-in endpoint (POST /api/auth/sign-in) with credentials description
- [x] Document sign-up endpoint (POST /api/auth/sign-up) with account creation description
- [x] Document Apple auth endpoint (POST /api/auth/apple-auth) with third-party auth description
- [x] Document refresh token endpoint (POST /api/auth/refresh) with token renewal description
- [x] Document password reset endpoint (POST /api/auth/reset-password) with recovery description
- [x] Document logout endpoint (POST /api/auth/logout) with JWT requirement and session termination description
- [x] Verify all 6 endpoints appear under "Auth" tag in `/openapi.json`

### Code Example

**File: `Sources/App/Modules/Auth/AuthRouter.swift`**

```swift
import Vapor
import VaporToOpenAPI

struct AuthRouter: RouteCollection {
    let controller = AuthController()

    func boot(routes: RoutesBuilder) throws {
        let api = routes
            .grouped("api")
            .grouped("auth")
            .groupedOpenAPI(tag: "Auth")  // Tag all auth routes

        api
            .grouped(UserCredentialsAuthenticator())
            .post("sign-in", use: controller.signIn)
            .description("Authenticate user with email and password. Returns JWT access token and refresh token for subsequent API requests.")

        api
            .post("sign-up", use: controller.signUp)
            .description("Create new user account with email and password. Sends email verification link and returns JWT tokens.")

        api
            .post("apple-auth", use: controller.authWithApple)
            .description("Authenticate or create account using Apple Sign In. Returns JWT tokens for the associated user account.")

        api
            .post("refresh", use: controller.refreshAccessToken)
            .description("Exchange refresh token for new access token. Use when access token expires to maintain authenticated session.")

        api
            .post("reset-password", use: controller.resetPassword)
            .description("Request password reset email. Sends recovery link to user's email address if account exists.")

        api
            .grouped(UserAccountModel.guard())
            .post("logout", use: controller.logout)
            .description("Invalidate current refresh token and end authenticated session. Requires valid JWT access token.")
            .security([.init(requirement: "bearerAuth")])  // JWT required
    }
}
```

**Reference: Existing AuthRouter pattern (AuthRouter.swift:3-25)**
```swift
struct AuthRouter: RouteCollection {
    let controller = AuthController()

    func boot(routes: RoutesBuilder) throws {
        let api = routes
            .grouped("api")
            .grouped("auth")

        // Credentials-based authentication
        api
            .grouped(UserCredentialsAuthenticator())
            .post("sign-in", use: controller.signIn)

        // Public endpoints
        api.post("sign-up", use: controller.signUp)
        api.post("apple-auth", use: controller.authWithApple)
        api.post("refresh", use: controller.refreshAccessToken)
        api.post("reset-password", use: controller.resetPassword)

        // JWT-protected endpoint
        api
            .grouped(UserAccountModel.guard())
            .post("logout", use: controller.logout)
    }
}
```

**Reference: Auth DTOs (from research.md)**
Request/response schemas are automatically generated from these types:
- `Auth.Login.Request` / `Auth.Login.Response`
- `Auth.SignUp.Request` / `Auth.SignUp.Response`
- `Auth.Apple.Request` / `Auth.Apple.Response`
- `Auth.TokenRefresh.Request` / `Auth.TokenRefresh.Response`
- `Auth.PasswordReset.Request`

### Success Criteria

- [x] Build succeeds without errors
- [x] All 6 auth endpoints appear in `/openapi.json` under "Auth" tag
- [x] Each endpoint has concise description (1-2 sentences)
- [x] Descriptions explain purpose ("why") not just HTTP method ("what")
- [x] Logout endpoint shows `bearerAuth` security requirement
- [x] Request/response schemas auto-generated from DTO types
- [x] No placeholder descriptions remain

### Verification Commands

```bash
# Build project
swift build

# Run and verify Auth endpoints
swift run &
sleep 5

# List all Auth endpoints
curl -s http://localhost:8080/openapi.json | jq '.paths | to_entries | map(select(.key | contains("/auth/"))) | from_entries'

# Check Auth tag
curl -s http://localhost:8080/openapi.json | jq '.tags'

# Verify logout security requirement
curl -s http://localhost:8080/openapi.json | jq '.paths["/api/auth/logout"].post.security'

pkill -f "swift run"
```

### Notes

- VaporToOpenAPI automatically generates request/response schemas from `Content`-conforming types
- The `.description()` modifier adds human-readable documentation
- The `.security()` modifier specifies which security schemes apply to the endpoint
- Focus descriptions on use case and when to call the endpoint, not technical details
