## TASK-004: Document User Module Endpoints

---
**Status:** COMPLETE
**Branch:** feature/openapi-documentation
**Type:** IMPLEMENTATION
**Phase:** 1
**Depends On:** TASK-002

---

### Overview

Add OpenAPI documentation metadata to all 4 User module endpoints. All user endpoints require JWT authentication, and one endpoint (list users) requires admin role.

### Files Modified

- `Sources/App/Modules/User/UserRouter.swift`

### Implementation Steps

- [ ] Add "User" tag to the user route group
- [ ] Document get current user endpoint (GET /api/user/me) with profile retrieval description
- [ ] Document update user endpoint (PATCH /api/user/update) with profile modification description
- [ ] Document delete user endpoint (DELETE /api/user/delete) with account deletion description
- [ ] Document list users endpoint (GET /api/user/list) with admin-only user listing description
- [ ] Add `bearerAuth` security requirement to all 4 endpoints
- [ ] Verify all endpoints appear under "User" tag in `/openapi.json`

### Implementation Steps

- [x] Add "User" tag using `.groupedOpenAPI(tags: .init(name: "User", description: "..."))`
- [x] Document GET /api/user/me endpoint
- [x] Document PATCH /api/user/update endpoint
- [x] Document DELETE /api/user/delete endpoint
- [x] Document GET /api/user/list endpoint with admin note
- [x] Add security requirements to all routes
- [x] Verify 4 endpoints in OpenAPI spec

### Code Example

**File: `Sources/App/Modules/User/UserRouter.swift`**

```swift
import Vapor
import VaporToOpenAPI

struct UserRouter: RouteCollection {
    let userController = UserController()

    func boot(routes: RoutesBuilder) throws {
        user(routes: routes)
    }
}

private extension UserRouter {
    func user(routes: RoutesBuilder) {
        let api = routes
            .grouped("api")
            .grouped("user")
            .groupedOpenAPI(tag: "User")  // Tag all user routes

        let protectedAPI = api
            .grouped(UserAccountModel.guard())  // All user routes require JWT

        protectedAPI
            .delete("delete", use: userController.delete)
            .description("Permanently delete current user account and all associated data. Requires authentication.")
            .security([.init(requirement: "bearerAuth")])

        protectedAPI
            .get("me", use: userController.getCurrentUser)
            .description("Retrieve current authenticated user's profile information including email, name, and account status.")
            .security([.init(requirement: "bearerAuth")])

        protectedAPI
            .patch("update", use: userController.patch)
            .description("Update current user's profile information (email, first name, last name). Only modifies provided fields.")
            .security([.init(requirement: "bearerAuth")])

        protectedAPI
            .grouped(EnsureAdminUserMiddleware())  // Admin-only
            .get("list", use: userController.list)
            .description("List all user accounts in the system. Requires admin privileges for security and privacy.")
            .security([.init(requirement: "bearerAuth")])
    }
}
```

**Reference: Existing UserRouter pattern (from research.md)**
```swift
private extension UserRouter {
    func user(routes: RoutesBuilder) {
        let api = routes
            .grouped("api")
            .grouped("user")

        let protectedAPI = api
            .grouped(UserAccountModel.guard())  // Protected with JWT

        protectedAPI.delete("delete", use: userController.delete)
        protectedAPI.get("me", use: userController.getCurrentUser)
        protectedAPI.patch("update", use: userController.patch)

        protectedAPI
            .grouped(EnsureAdminUserMiddleware())  // Additional admin check
            .get("list", use: userController.list)
    }
}
```

**Reference: User DTOs**
Schemas auto-generated from:
- `User.Detail.Response` (for /me endpoint)
- `User.Update.Request` / `User.Update.Response` (for /update endpoint)
- `User.List.Response` (for /list endpoint)

### Success Criteria

- [ ] Build succeeds without errors
- [ ] All 4 user endpoints appear in `/openapi.json` under "User" tag
- [ ] Each endpoint has concise description explaining its purpose
- [ ] All endpoints show `bearerAuth` security requirement
- [ ] List endpoint description mentions admin requirement
- [ ] Request/response schemas match DTO structures
- [ ] No placeholder descriptions remain

### Verification Commands

```bash
# Build project
swift build

# Run and verify User endpoints
swift run &
sleep 5

# List all User endpoints
curl -s http://localhost:8080/openapi.json | jq '.paths | to_entries | map(select(.key | contains("/user/"))) | from_entries'

# Verify all have security requirements
curl -s http://localhost:8080/openapi.json | jq '[.paths["/api/user/me"].get.security, .paths["/api/user/update"].patch.security, .paths["/api/user/delete"].delete.security, .paths["/api/user/list"].get.security]'

pkill -f "swift run"
```

### Notes

- All user endpoints require JWT authentication (unlike Auth module which has public endpoints)
- The admin middleware (EnsureAdminUserMiddleware) is applied at the route level, but we document it in the description since OpenAPI doesn't have a separate "admin role" security scheme
- PATCH method is used for partial updates (RESTful convention)
