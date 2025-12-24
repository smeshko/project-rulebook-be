## TASK-006: Create WaitlistNotifier Helper

---
**Status:** OPEN
**Branch:** feature/waitlist-email
**Type:** IMPLEMENTATION
**Phase:** 1
**Depends On:** TASK-005
---

### Overview

Create a helper struct for sending waitlist-related emails (confirmation and launch notification). Follows the same pattern as EmailVerifier.

**Files:**
- `Sources/App/Services/Email/Helpers/WaitlistNotifier.swift` (create)

### Implementation Steps

**Commit 1: Create WaitlistNotifier**
- [ ] Create `WaitlistNotifier.swift` in Email/Helpers directory
- [ ] Add `sendConfirmation(to:)` method for waitlist signup confirmation
- [ ] Add `sendLaunchNotification(to:)` method for launch announcement
- [ ] Add Application and Request extensions for easy access
- [ ] Use existing EmailService for sending

### Code Example

```swift
// Pattern from EmailVerifier.swift
// Sources/App/Services/Email/Helpers/EmailVerifier.swift:1-55

import Vapor

struct WaitlistNotifier {
    let application: Application

    func sendConfirmation(to entry: WaitlistEntryModel) async throws {
        let baseURL = try application.configuration.security.baseURL

        let content = BrevoMail(
            sender: .init(
                name: "Project Rulebook",
                email: "noreply@projectrulebook.com"
            ),
            to: [.init(
                name: entry.email,
                email: entry.email
            )],
            subject: "You're on the waitlist!",
            htmlContent: Templates.waitlistConfirmation(
                unsubscribeToken: entry.unsubscribeToken,
                baseURL: baseURL
            )
        )

        try await application.serviceCache.emailService.send(content)
    }

    func sendLaunchNotification(to entry: WaitlistEntryModel) async throws {
        let baseURL = try application.configuration.security.baseURL

        let content = BrevoMail(
            sender: .init(
                name: "Project Rulebook",
                email: "noreply@projectrulebook.com"
            ),
            to: [.init(
                name: entry.email,
                email: entry.email
            )],
            subject: "We're live! The app is ready",
            htmlContent: Templates.waitlistLaunchNotification(
                unsubscribeToken: entry.unsubscribeToken,
                baseURL: baseURL
            )
        )

        try await application.serviceCache.emailService.send(content)
    }
}

extension Application {
    var waitlistNotifier: WaitlistNotifier {
        .init(application: self)
    }
}

extension Request {
    var waitlistNotifier: WaitlistNotifier {
        .init(application: application)
    }
}
```

### Success Criteria

- [ ] Build succeeds
- [ ] Both email methods compile
- [ ] Extensions provide easy access from Application and Request
- [ ] Uses existing EmailService infrastructure

### Verification

```bash
swift build
```

### Notes

- Sender email should be configured - using placeholder for now
- Uses `application.serviceCache.emailService` for sending (same as EmailVerifier)
- baseURL comes from security configuration
- Entry contains unsubscribeToken for template
