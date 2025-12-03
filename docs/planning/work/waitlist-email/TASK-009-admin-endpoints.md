## TASK-009: Implement Admin Endpoints (Stats & Notify)

---
**Status:** COMPLETE
**Branch:** feature/waitlist-email
**Type:** IMPLEMENTATION
**Phase:** 2
**Depends On:** TASK-008
---

### Overview

Implement admin-only endpoints for viewing waitlist statistics and sending bulk launch notifications. These endpoints require JWT authentication and admin privileges.

**Files:**
- `Sources/App/Modules/Waitlist/WaitlistRouter.swift` (modify)
- `Sources/App/Modules/Waitlist/WaitlistController.swift` (modify)

### Implementation Steps

**Commit 1: Add admin-protected routes and controller methods**
- [x] Add `stats()` method to WaitlistController - return total, notified, pending counts
- [x] Add `notify()` method to WaitlistController - send launch emails to all unnotified
- [x] Add admin-protected route group in WaitlistRouter using `EnsureAdminUserMiddleware()`
- [x] `GET /api/waitlist/stats` - Returns waitlist statistics
- [x] `POST /api/waitlist/notify` - Triggers bulk launch notification
- [x] Update notifiedAt timestamp after successful email send
- [x] Add OpenAPI documentation with auth requirements

### Code Example

```swift
// Add to WaitlistController.swift
// Sources/App/Modules/Waitlist/WaitlistController.swift

func stats(_ req: Request) async throws -> Waitlist.Stats.Response {
    let repository = req.application.serviceCache.waitlistRepository

    let total = try await repository.count()
    let notified = try await repository.countNotified()

    return Waitlist.Stats.Response(
        total: total,
        notified: notified,
        pending: total - notified
    )
}

func notify(_ req: Request) async throws -> Waitlist.Notify.Response {
    let repository = req.application.serviceCache.waitlistRepository
    let entries = try await repository.findUnnotified()

    var sent = 0
    var failed = 0

    for entry in entries {
        do {
            try await req.waitlistNotifier.sendLaunchNotification(to: entry)
            entry.notifiedAt = Date()
            try await repository.update(entry)
            sent += 1
        } catch {
            req.logger.error("Failed to notify \(entry.email): \(error)")
            failed += 1
        }
    }

    return Waitlist.Notify.Response(
        sent: sent,
        failed: failed,
        message: "Notification complete. Sent: \(sent), Failed: \(failed)"
    )
}
```

```swift
// Update WaitlistRouter.swift to add admin routes
// Sources/App/Modules/Waitlist/WaitlistRouter.swift

func boot(routes: RoutesBuilder) throws {
    let api = routes
        .grouped("api")
        .grouped("waitlist")
        .groupedOpenAPI(tags: .init(name: "Waitlist", description: "Email waitlist management"))

    // Public endpoints (existing)
    api.post(use: controller.subscribe)
        .openAPI(
            description: "Subscribe an email address to the waitlist.",
            body: .type(Waitlist.Subscribe.Request.self),
            response: .type(Waitlist.Subscribe.Response.self)
        )

    api.get("unsubscribe", ":token", use: controller.unsubscribe)
        .openAPI(
            description: "Unsubscribe from the waitlist using the token from the email.",
            response: .type(Waitlist.Unsubscribe.Response.self)
        )

    // Admin-only endpoints (pattern from UserRouter.swift:48-55)
    let adminAPI = api
        .grouped(UserAccountModel.guard())
        .grouped(EnsureAdminUserMiddleware())

    adminAPI.get("stats", use: controller.stats)
        .openAPI(
            description: "Get waitlist statistics. Admin only.",
            response: .type(Waitlist.Stats.Response.self),
            auth: .bearer(id: "bearerAuth")
        )

    adminAPI.post("notify", use: controller.notify)
        .openAPI(
            description: "Send launch notification to all unnotified subscribers. Admin only.",
            response: .type(Waitlist.Notify.Response.self),
            auth: .bearer(id: "bearerAuth")
        )
}
```

### Success Criteria

- [ ] Build succeeds
- [ ] GET /api/waitlist/stats returns correct counts
- [ ] POST /api/waitlist/notify sends emails to unnotified entries
- [ ] notifiedAt is updated after successful send
- [ ] 401 returned for unauthenticated requests
- [ ] 401 returned for non-admin users
- [ ] OpenAPI documentation includes auth requirement

### Verification

```bash
swift build
# Manual test (requires admin JWT):
curl -X GET http://localhost:8080/api/waitlist/stats \
  -H "Authorization: Bearer <admin-jwt-token>"
```

### Notes

- Uses same middleware pattern as UserRouter for admin protection
- `UserAccountModel.guard()` ensures user is authenticated
- `EnsureAdminUserMiddleware()` ensures user has admin privileges
- Notification is sequential to respect Brevo rate limits
- Failed notifications are logged but don't stop the process
- Consider adding batch delay for large lists (future enhancement)
