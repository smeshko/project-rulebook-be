## TASK-008: Implement Public Endpoints (Subscribe & Unsubscribe)

---
**Status:** COMPLETE
**Branch:** feature/waitlist-email
**Type:** IMPLEMENTATION
**Phase:** 2
**Depends On:** TASK-003, TASK-004, TASK-005, TASK-006, TASK-007
---

### Overview

Implement the public-facing API endpoints for subscribing to the waitlist and unsubscribing. These endpoints are publicly accessible (no auth required) but rate-limited.

**Files:**
- `Sources/App/Modules/Waitlist/WaitlistRouter.swift` (modify - replace placeholder)
- `Sources/App/Modules/Waitlist/WaitlistController.swift` (create)

### Implementation Steps

**Commit 1: Create WaitlistController and public routes**
- [x] Create `WaitlistController.swift` with `subscribe()` and `unsubscribe()` methods
- [x] Update `WaitlistRouter.swift` with route definitions
- [x] `POST /api/waitlist` - Validate email, check duplicate, create entry, send confirmation
- [x] `GET /api/waitlist/unsubscribe/:token` - Find by token, delete entry
- [x] Add OpenAPI documentation for both endpoints
- [x] Handle duplicate emails gracefully (return success without creating duplicate)

### Code Example

```swift
// Sources/App/Modules/Waitlist/WaitlistController.swift
import Vapor

struct WaitlistController {

    func subscribe(_ req: Request) async throws -> Waitlist.Subscribe.Response {
        // Validate request
        try Waitlist.Subscribe.Request.validate(content: req)
        let subscribeRequest = try req.content.decode(Waitlist.Subscribe.Request.self)

        let repository = req.application.serviceCache.waitlistRepository

        // Check for existing entry (idempotent)
        if let existing = try await repository.find(email: subscribeRequest.email) {
            return Waitlist.Subscribe.Response(
                message: "You're already on the waitlist!",
                email: existing.email
            )
        }

        // Create new entry
        let entry = WaitlistEntryModel(email: subscribeRequest.email)
        try await repository.create(entry)

        // Send confirmation email (fire and forget - don't fail on email error)
        Task {
            do {
                try await req.waitlistNotifier.sendConfirmation(to: entry)
            } catch {
                req.logger.error("Failed to send waitlist confirmation email: \(error)")
            }
        }

        return Waitlist.Subscribe.Response(
            message: "Thanks for joining the waitlist!",
            email: entry.email
        )
    }

    func unsubscribe(_ req: Request) async throws -> Waitlist.Unsubscribe.Response {
        guard let token = req.parameters.get("token") else {
            throw Abort(.badRequest, reason: "Missing unsubscribe token")
        }

        let repository = req.application.serviceCache.waitlistRepository

        guard let entry = try await repository.find(token: token) else {
            throw Abort(.notFound, reason: "Invalid or expired unsubscribe link")
        }

        try await repository.delete(entry)

        return Waitlist.Unsubscribe.Response(
            message: "You've been removed from the waitlist."
        )
    }
}
```

```swift
// Sources/App/Modules/Waitlist/WaitlistRouter.swift
import Vapor
import VaporToOpenAPI

struct WaitlistRouter: RouteCollection {
    let controller = WaitlistController()

    func boot(routes: RoutesBuilder) throws {
        let api = routes
            .grouped("api")
            .grouped("waitlist")
            .groupedOpenAPI(tags: .init(name: "Waitlist", description: "Email waitlist management"))

        // Public endpoints (rate limited via middleware)
        api.post(use: controller.subscribe)
            .openAPI(
                description: "Subscribe an email address to the waitlist. Sends a confirmation email on success.",
                body: .type(Waitlist.Subscribe.Request.self),
                response: .type(Waitlist.Subscribe.Response.self)
            )

        api.get("unsubscribe", ":token", use: controller.unsubscribe)
            .openAPI(
                description: "Unsubscribe from the waitlist using the token from the email.",
                response: .type(Waitlist.Unsubscribe.Response.self)
            )
            .response(statusCode: .notFound, description: "Invalid or expired token")
    }
}
```

### Success Criteria

- [ ] Build succeeds
- [ ] POST /api/waitlist creates entry and sends email
- [ ] Duplicate email returns 200 (idempotent)
- [ ] Invalid email returns 400 validation error
- [ ] GET /api/waitlist/unsubscribe/:token deletes entry
- [ ] Invalid token returns 404
- [ ] OpenAPI documentation included

### Verification

```bash
swift build
# Manual test:
curl -X POST http://localhost:8080/api/waitlist \
  -H "Content-Type: application/json" \
  -d '{"email": "test@example.com"}'
```

### Notes

- Email sending is fire-and-forget to not block the response
- Repository access via `req.application.serviceCache.waitlistRepository` (need to add this extension)
- Duplicate handling returns success - user doesn't need to know they're already subscribed
- Token parameter uses Vapor's parameter extraction: `req.parameters.get("token")`
