## TASK-004: Create Request/Response DTOs

---
**Status:** OPEN
**Branch:** feature/waitlist-email
**Type:** IMPLEMENTATION
**Phase:** 1
**Depends On:** TASK-001
---

### Overview

Create the Data Transfer Objects (DTOs) for waitlist API requests and responses. These define the API contract for subscribe, unsubscribe, stats, and notify endpoints.

**Files:**
- `Sources/App/Modules/Waitlist/Models/Waitlist+Model.swift` (create)

### Implementation Steps

**Commit 1: Create Waitlist DTOs**
- [ ] Create directory: `Sources/App/Modules/Waitlist/Models/`
- [ ] Define `Waitlist` namespace enum
- [ ] Create `Subscribe.Request` with email field and validation
- [ ] Create `Subscribe.Response` with success message
- [ ] Create `Unsubscribe.Response` with confirmation
- [ ] Create `Stats.Response` with total, notified, pending counts
- [ ] Create `Notify.Response` with notification results

### Code Example

```swift
// Pattern from User+Model.swift style DTOs
import Vapor

enum Waitlist {
    enum Subscribe {
        struct Request: Content, Validatable {
            let email: String

            static func validations(_ validations: inout Validations) {
                validations.add("email", as: String.self, is: .email)
            }
        }

        struct Response: Content {
            let message: String
            let email: String
        }
    }

    enum Unsubscribe {
        struct Response: Content {
            let message: String
        }
    }

    enum Stats {
        struct Response: Content {
            let total: Int
            let notified: Int
            let pending: Int
        }
    }

    enum Notify {
        struct Response: Content {
            let sent: Int
            let failed: Int
            let message: String
        }
    }
}
```

### Success Criteria

- [ ] Build succeeds
- [ ] All DTOs conform to Content
- [ ] Subscribe.Request has email validation
- [ ] Response types cover all endpoints

### Verification

```bash
swift build
```

### Notes

- Use Vapor's built-in `Validatable` protocol for email validation
- Keep responses simple - can be extended later if needed
- Stats response provides all counts admin dashboard might need
