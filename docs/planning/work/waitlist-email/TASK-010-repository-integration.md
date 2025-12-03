## TASK-010: Integrate WaitlistRepository with ServiceCache

---
**Status:** OPEN
**Branch:** feature/waitlist-email
**Type:** INTEGRATION
**Phase:** 1
**Depends On:** TASK-002
---

### Overview

Wire up the WaitlistRepository to the ServiceCache so it can be accessed via `application.serviceCache.waitlistRepository` and `request.services.waitlist`. This follows the existing pattern used by UserRepository.

**Files:**
- `Sources/App/Common/ServiceRegistry/ServiceCache.swift` (modify - if exists)
- `Sources/App/Modules/Waitlist/Repositories/WaitlistRepository.swift` (modify - add extensions)

### Implementation Steps

**Commit 1: Add repository integration to ServiceCache**
- [ ] Add `waitlistRepository` property to ServiceCache (or appropriate service container)
- [ ] Add `Application.Repositories.waitlist` extension
- [ ] Add `Request.Services.waitlist` extension
- [ ] Ensure repository is initialized with database connection

### Code Example

```swift
// Add to WaitlistRepository.swift at the bottom
// Pattern from UserRepository.swift:126-137

extension Application.Repositories {
    var waitlist: any WaitlistRepository {
        guard let repository = application.serviceCache.waitlistRepository as? WaitlistRepository else {
            return DatabaseWaitlistRepository(database: application.db)
        }
        return repository
    }
}

extension Request.Services {
    var waitlist: any WaitlistRepository {
        DatabaseWaitlistRepository(database: request.db)
    }
}
```

```swift
// If ServiceCache pattern is used, add property:
// Sources/App/Common/ServiceRegistry/ServiceCache.swift

var waitlistRepository: any WaitlistRepository {
    DatabaseWaitlistRepository(database: application.db)
}
```

### Success Criteria

- [ ] Build succeeds
- [ ] `application.serviceCache.waitlistRepository` accessible
- [ ] `request.services.waitlist` accessible
- [ ] Repository uses correct database connection

### Verification

```bash
swift build
```

### Notes

- Check existing ServiceCache implementation for exact pattern
- May need to use `application.db` or `request.db` depending on pattern
- This integration allows controller to access repository easily
- Follow exact pattern from UserRepository for consistency
