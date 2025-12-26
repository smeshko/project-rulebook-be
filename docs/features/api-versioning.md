# API Versioning Strategy

**Date:** 2025-12-26
**Related Files:** AuthRouter.swift, RulesGenerationRouter.swift, UserRouter.swift, WaitlistRouter.swift

## Overview

Implemented URL prefix versioning (`/api/v1/`) for all public API endpoints to enable mobile apps to pin to specific API versions for stability. This is a breaking change that moved all existing endpoints under the `/v1/` namespace and establishes the pattern for all future API endpoints.

## What Was Built

- URL prefix versioning strategy with `/api/v1/` prefix for all public endpoints
- Updated all existing module routers (Auth, RulesGeneration, User, Waitlist)
- Comprehensive test coverage for versioned routes
- Route versioning tests to verify old routes return 404

## Technical Implementation

### Key Files

- `Sources/App/Modules/Auth/AuthRouter.swift`: Auth endpoints under `/api/v1/auth/`
- `Sources/App/Modules/RulesGeneration/RulesGenerationRouter.swift`: AI endpoints under `/api/v1/rules-generation/`
- `Sources/App/Modules/User/UserRouter.swift`: User management under `/api/v1/user/`
- `Sources/App/Modules/Waitlist/WaitlistRouter.swift`: Waitlist endpoints under `/api/v1/waitlist/`
- `Tests/AppTests/Tests/ControllerTests/RulesGenerationTests/RulesGenerationRouteVersioningTests.swift`: Versioning verification tests

### Key Patterns

**Router Update Pattern:**

All module routers now include the `.grouped("v1")` call after the `/api/` prefix:

```swift
// Standard versioned router pattern
func boot(routes: RoutesBuilder) throws {
    let api = routes
        .grouped("api")
        .grouped("v1")           // ← Version prefix added here
        .grouped("{module-name}")
        .groupedOpenAPI(tags: .init(name: "{Module}", description: "..."))

    // Define routes under the api group
    api.post("{endpoint}", use: controller.method)
}
```

**URL Format:**
- Old format: `/api/{module}/{endpoint}`
- New format: `/api/v1/{module}/{endpoint}`

**Examples:**
- Auth sign-in: `/api/v1/auth/sign-in`
- Rules generation: `/api/v1/rules-generation/game-box-analysis`
- User profile: `/api/v1/user/profile`
- Waitlist: `/api/v1/waitlist/subscribe`

**Testing Pattern:**

All integration tests updated to use versioned paths:

```swift
@Test("Endpoint accessible with v1 prefix")
func testVersionedEndpoint() async throws {
    try await app.test(.POST, "api/v1/auth/sign-in") { req in
        // Test implementation
    } afterResponse: { response in
        #expect(response.status == .ok)
    }
}

@Test("Old unversioned route returns 404")
func oldRouteReturns404() async throws {
    try await app.test(.POST, "api/auth/sign-in") { req in
        // Test implementation
    } afterResponse: { response in
        #expect(response.status == .notFound)
    }
}
```

## How to Use

### For Adding New API Endpoints

When creating or updating a module router:

1. **Import Required Modules:**
   ```swift
   import Vapor
   import VaporToOpenAPI
   ```

2. **Structure Your Router:**
   ```swift
   struct YourModuleRouter: RouteCollection {
       let controller = YourModuleController()

       func boot(routes: RoutesBuilder) throws {
           let api = routes
               .grouped("api")
               .grouped("v1")              // REQUIRED: Version prefix
               .grouped("your-module")
               .groupedOpenAPI(tags: .init(name: "Your Module",
                                          description: "Module description"))

           // Define your endpoints
           api.post("your-endpoint", use: controller.yourMethod)
       }
   }
   ```

3. **Register in Application:**
   Ensure your router is registered in `configure.swift` or `Application-Setup.swift`

4. **Update Tests:**
   All test paths must include the `/v1/` prefix:
   ```swift
   try await app.test(.POST, "api/v1/your-module/your-endpoint")
   ```

### For Mobile App Integration

**Critical:** This is a **breaking change** for existing mobile clients.

**Migration Steps:**

1. Update all API endpoint URLs to include `/v1/`:
   - Old: `https://api.example.com/api/auth/sign-in`
   - New: `https://api.example.com/api/v1/auth/sign-in`

2. Test all endpoints in staging before production deployment

3. Update API client configuration:
   ```swift
   // iOS Example
   let baseURL = "https://api.example.com/api/v1"
   ```

4. Coordinate deployment:
   - Deploy backend with versioned routes
   - Update mobile apps to use new URLs
   - Old routes will return 404 after deployment

## Configuration

No environment variables or configuration files required. Versioning is implemented through route definitions in router files.

**OpenAPI Integration:**
- OpenAPI spec automatically reflects versioned paths
- No additional OpenAPI configuration needed
- VaporToOpenAPI handles route documentation

## Notes

### Why URL Prefix Versioning?

URL prefix versioning was chosen over alternatives (header-based, query parameters) because:

1. **Explicit and Debuggable**: Version visible in logs, network inspectors, and documentation
2. **Mobile App Friendly**: Apps can pin to specific version URLs
3. **No Ambiguity**: Clear separation between API versions
4. **Industry Standard**: Common pattern used by major APIs (Stripe, GitHub, etc.)

### Breaking Change Impact

⚠️ **Critical:** All existing mobile app clients will break after this deployment.

**Affected Endpoints:**
- All auth endpoints (`/api/auth/*` → `/api/v1/auth/*`)
- All rules generation endpoints (`/api/rules-generation/*` → `/api/v1/rules-generation/*`)
- All user endpoints (`/api/user/*` → `/api/v1/user/*`)
- All waitlist endpoints (`/api/waitlist/*` → `/api/v1/waitlist/*`)

**Not Affected:**
- Admin endpoints (CacheAdmin - internal routes)
- Frontend HTML routes (not part of API contract)

### Future Versioning

When introducing breaking changes in the future:

1. Create new router with `/v2/` prefix
2. Maintain `/v1/` routes for backward compatibility
3. Deprecate `/v1/` routes with sunset timeline
4. Document migration path for clients

### Architectural Context

This implementation fulfills the architectural decision documented in:
- `docs/architecture/future-architecture-decisions.md` (Line 110-126)
- `docs/architecture/technical-architecture.md` (Line 524)

**Decision Rationale:** URL prefix strategy provides mobile apps the ability to pin to specific versions for stability while maintaining explicit and debuggable API contracts.

### Testing Requirements

When adding new endpoints, always:
- ✅ Test the versioned route works (`/api/v1/...`)
- ✅ Test old unversioned route returns 404 (`/api/...`)
- ✅ Update all integration tests to use versioned paths
- ✅ Verify OpenAPI spec reflects versioned endpoints

### Common Issues

**Problem:** Tests failing with 404 errors
**Solution:** Ensure test paths include `/v1/` prefix

**Problem:** Mobile app can't reach endpoints
**Solution:** Verify mobile app URLs updated to include `/v1/`

**Problem:** OpenAPI spec shows wrong paths
**Solution:** Version prefix is in router chain before `.groupedOpenAPI()` call
