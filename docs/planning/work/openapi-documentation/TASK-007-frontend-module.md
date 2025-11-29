## TASK-007: Document Frontend Module Endpoints

---
**Status:** COMPLETE
**Branch:** feature/openapi-documentation
**Type:** IMPLEMENTATION
**Phase:** 1
**Depends On:** TASK-002

---

### Overview

Add OpenAPI documentation metadata to all 3 Frontend module endpoints. These are web-facing HTML endpoints (not JSON API endpoints) with no `/api` prefix. They handle email verification and password reset flows.

### Files Modified

- `Sources/App/Modules/Frontend/FrontendRouter.swift`

### Implementation Steps

- [x] Add "Frontend" tag to the frontend route group
- [x] Document verify email endpoint (GET /verify-email) with query parameter documentation
- [x] Document password reset form endpoint (GET /reset-password) with query parameter documentation
- [x] Document password reset action endpoint (POST /reset-password) with form submission description
- [x] Note HTML response type (not JSON) in descriptions
- [x] Verify all 3 endpoints appear under "Frontend" tag in `/openapi.json`

### Code Example

**File: `Sources/App/Modules/Frontend/FrontendRouter.swift`**

```swift
import Vapor
import VaporToOpenAPI

struct FrontendRouter: RouteCollection {
    let controller = FrontendController()

    func boot(routes: RoutesBuilder) throws {
        routes
            .groupedOpenAPI(tag: "Frontend")  // Tag all frontend HTML routes
            .group { frontend in
                frontend
                    .get("verify-email", use: controller.verifyEmail)
                    .description("Email verification page. User clicks link from verification email with token query parameter. Returns HTML success/error page.")

                frontend
                    .get("reset-password", use: controller.resetPassword)
                    .description("Password reset form page. User clicks link from password reset email with token query parameter. Returns HTML form to enter new password.")

                frontend
                    .post("reset-password", use: controller.resetPasswordAction)
                    .description("Process password reset form submission. Validates token and updates password. Returns HTML success/error page.")
            }
    }
}
```

**Reference: Existing FrontendRouter pattern (from research.md)**
```swift
struct FrontendRouter: RouteCollection {
    let controller = FrontendController()

    func boot(routes: RoutesBuilder) throws {
        routes.get("verify-email", use: controller.verifyEmail)
        routes.get("reset-password", use: controller.resetPassword)
        routes.post("reset-password", use: controller.resetPasswordAction)
    }
}
```

**Reference: Query Parameters**
These endpoints expect query parameters:
- `verify-email?token=<verification_token>`
- `reset-password?token=<reset_token>`

The token is validated against database records.

### Success Criteria

- [ ] Build succeeds without errors
- [ ] All 3 frontend endpoints appear in `/openapi.json` under "Frontend" tag
- [ ] Descriptions explain HTML page purpose (not JSON API)
- [ ] Descriptions mention query parameters (token)
- [ ] No security requirements (public endpoints, token in URL)
- [ ] GET and POST /reset-password both documented (different operations)
- [ ] Response schemas indicate HTML content type if possible

### Verification Commands

```bash
# Build project
swift build

# Run and verify Frontend endpoints
swift run &
sleep 5

# List all Frontend endpoints
curl -s http://localhost:8080/openapi.json | jq '.paths | to_entries | map(select(.key | contains("verify-email") or .key | contains("reset-password"))) | from_entries'

# Check that both GET and POST reset-password exist
curl -s http://localhost:8080/openapi.json | jq '.paths["/reset-password"]'

# Verify no security requirements (public HTML pages)
curl -s http://localhost:8080/openapi.json | jq '[.paths["/verify-email"].get.security, .paths["/reset-password"].get.security, .paths["/reset-password"].post.security]'

pkill -f "swift run"
```

### Notes

- These endpoints return HTML (via SwiftHtml), not JSON - unusual for OpenAPI documentation but still valuable
- No `/api` prefix since these are web pages, not API endpoints
- Public endpoints but token validation happens in controller logic
- Query parameters should be documented in OpenAPI spec (token is required)
- Same path `/reset-password` with different HTTP methods (GET shows form, POST processes form)
