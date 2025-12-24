## TASK-003: Create WaitlistModule and Register

---
**Status:** OPEN
**Branch:** feature/waitlist-email
**Type:** IMPLEMENTATION
**Phase:** 1
**Depends On:** TASK-001, TASK-002
---

### Overview

Create the WaitlistModule conforming to ModuleInterface and register it in the application setup. This wires up migrations and prepares for route registration.

**Files:**
- `Sources/App/Modules/Waitlist/WaitlistModule.swift` (create)
- `Sources/App/Entrypoint/Application-Setup.swift` (modify)

### Implementation Steps

**Commit 1: Create WaitlistModule and register in Application-Setup**
- [ ] Create `WaitlistModule.swift` conforming to `ModuleInterface`
- [ ] Add migration registration in `boot()` method
- [ ] Create placeholder `WaitlistRouter` (empty for now, to be implemented in TASK-006)
- [ ] Add `WaitlistModule()` to modules array in `Application-Setup.swift:83-89`

### Code Example

```swift
// Pattern from UserModule.swift
// Sources/App/Modules/User/UserModule.swift:1-16

import Vapor

struct WaitlistModule: ModuleInterface {
    let router = WaitlistRouter()

    func boot(_ app: Application) throws {
        app.migrations.add(WaitlistMigrations.v1())
        try router.boot(routes: app.routes)
    }
}
```

```swift
// Placeholder router (to be completed in TASK-006)
import Vapor

struct WaitlistRouter: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        // Routes will be added in TASK-006
    }
}
```

```swift
// Modify Application-Setup.swift:82-89
func setupModules() throws {
    let modules: [ModuleInterface] = [
        UserModule(),
        AuthModule(),
        FrontendModule(),
        RulesGenerationModule(),
        CacheAdminModule(),
        WaitlistModule(),  // Add this line
    ]
    // ...
}
```

### Success Criteria

- [ ] Build succeeds
- [ ] Module conforms to ModuleInterface
- [ ] Module is registered in setupModules()
- [ ] Migration runs on app startup

### Verification

```bash
swift build
swift run App migrate --env development
```

### Notes

- Router is a placeholder for now - actual routes added in Phase 2
- Migration will auto-run due to `autoMigrate()` in configure.swift
- Keep module structure consistent with User, Auth modules
