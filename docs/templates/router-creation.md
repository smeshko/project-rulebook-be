---
title: "Router Creation Template"
description: "Guide for creating routers in project-rulebook-be"
author: Claude
date: 2026-01-23
---

# Router Creation Template

## When to Use

- Defining URL routes for a module
- Applying middleware (authentication, rate limiting)
- Adding OpenAPI documentation to endpoints

## Quick Reference

| Component | Description |
|-----------|-------------|
| Location | `Sources/App/Modules/{Module}/{Module}Router.swift` |
| Protocol | `RouteCollection` |
| Controller | Instantiated as property |
| URL Pattern | `/api/v1/{module-slug}/...` |
| Documentation | VaporToOpenAPI annotations |

## Code Template

```swift
import Vapor
import VaporToOpenAPI

struct {Module}Router: RouteCollection {
    let controller = {Module}Controller()

    func boot(routes: RoutesBuilder) throws {
        // MARK: - Base Route Group

        let api = routes
            .grouped("api")
            .grouped("v1")
            .grouped("{module-slug}")
            .groupedOpenAPI(tags: .init(
                name: "{Module}",
                description: "Description of this module's endpoints"
            ))

        // MARK: - Public Endpoints

        api
            .post("action", use: controller.publicAction)
            .openAPI(
                summary: "Short title for endpoint",
                description: "Detailed description of what this endpoint does.",
                body: .type({Module}.Action.Request.self),
                response: .type({Module}.Action.Response.self)
            )

        // MARK: - Protected Endpoints

        api
            .grouped(UserAccountModel.guard())
            .get("protected", use: controller.protectedAction)
            .openAPI(
                summary: "Protected endpoint",
                description: "Requires authentication. Returns user-specific data.",
                auth: .bearer(id: "bearerAuth"),
                response: .type({Module}.Protected.Response.self)
            )
    }
}
```

## Common Patterns

### Authentication Middleware

```swift
// JWT token required (extracts TokenPayload)
api
    .grouped(UserPayloadAuthenticator())
    .grouped(TokenPayload.guardMiddleware())
    .get("me", use: controller.getProfile)

// Full user model required
api
    .grouped(UserAccountModel.guard())
    .get("profile", use: controller.getFullProfile)

// Credentials authenticator (for login)
api
    .grouped(UserCredentialsAuthenticator())
    .post("sign-in", use: controller.signIn)
```

### Multiple Middleware

```swift
api
    .grouped(RateLimitMiddleware(limit: 10, window: .hour))
    .grouped(UserAccountModel.guard())
    .post("expensive-action", use: controller.expensiveAction)
```

### Path Parameters

```swift
api
    .get(":id", use: controller.getById)
    .openAPI(
        summary: "Get item by ID",
        description: "Retrieves a single item by its UUID.",
        response: .type(Item.Response.self)
    )

// Multiple parameters
api
    .get("users", ":userId", "items", ":itemId", use: controller.getUserItem)
```

### Query Parameters

```swift
api
    .get("search", use: controller.search)
    .openAPI(
        summary: "Search items",
        description: "Search with optional filters.",
        query: ["q": .string, "limit": .int, "offset": .int],
        response: .type([Item.Response].self)
    )
```

### Streaming Body

```swift
// For file uploads or large payloads
api
    .on(.POST, "upload", body: .stream, use: controller.handleUpload)
    .openAPI(
        summary: "Upload file",
        description: "Send binary data in request body."
    )
```

### Custom Response Codes

```swift
api
    .post("action", use: controller.action)
    .openAPI(
        summary: "Perform action",
        description: "Creates a resource."
    )
    .response(statusCode: .created, description: "Resource created successfully")
    .response(statusCode: .conflict, description: "Resource already exists")
    .response(statusCode: .badRequest, description: "Invalid input")
```

## OpenAPI Documentation

### Basic Documentation

```swift
.openAPI(
    summary: "Short title",           // Shows in endpoint list
    description: "Detailed desc.",    // Shows in expanded view
    body: .type(RequestDTO.self),     // Request body schema
    response: .type(ResponseDTO.self) // Response schema
)
```

### With Authentication

```swift
.openAPI(
    summary: "Protected endpoint",
    description: "Requires valid JWT token.",
    auth: .bearer(id: "bearerAuth"),
    body: .type(RequestDTO.self),
    response: .type(ResponseDTO.self)
)
```

### Array Response

```swift
.openAPI(
    summary: "List items",
    description: "Returns all items.",
    response: .type([ItemDTO].self)  // Array of items
)
```

### No Response Body

```swift
.openAPI(
    summary: "Delete item",
    description: "Removes the item."
)
.response(statusCode: .noContent, description: "Item deleted")
```

## Route Structure Convention

```text
/api/v1/{module-slug}
├── GET    /              → list all
├── POST   /              → create
├── GET    /:id           → get one
├── PATCH  /:id           → update
├── DELETE /:id           → delete
└── POST   /:id/action    → custom action
```

## Implementation Checklist

- [ ] Struct implements `RouteCollection`
- [ ] Controller instantiated as `let controller`
- [ ] Routes grouped with `/api/v1/{module-slug}` prefix
- [ ] OpenAPI tags configured with name and description
- [ ] Authentication middleware on protected routes
- [ ] OpenAPI documentation on all endpoints
- [ ] Request/response types documented
- [ ] Path parameters use `:paramName` syntax
- [ ] HTTP methods match REST conventions
- [ ] URL paths use kebab-case

## Codebase Examples

- `Sources/App/Modules/Auth/AuthRouter.swift` - Full auth routes with multiple middleware
- `Sources/App/Modules/RulesGeneration/RulesGenerationRouter.swift` - Streaming endpoints
- `Sources/App/Modules/Waitlist/WaitlistRouter.swift` - Simple CRUD routes
- `Sources/App/Modules/CacheAdmin/CacheAdminRouter.swift` - Admin routes

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Missing `grouped()` | Build URL hierarchy with chained grouping |
| Auth on public routes | Only protect what needs protection |
| Missing OpenAPI docs | Document all endpoints for API consumers |
| Inconsistent paths | Use kebab-case for URLs consistently |
| Wrong HTTP methods | GET for reads, POST for creates, PATCH for updates, DELETE for deletes |
| Forgetting route registration | Add router boot in Module's `boot()` method |
