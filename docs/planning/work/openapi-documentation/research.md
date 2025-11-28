# Research: OpenAPI/Swagger Documentation

---
**Date:** 2025-11-28
**Requirements:** `docs/planning/work/openapi-documentation/requirements.md`
**Linear Issue:** N/A
**Status:** complete

---

## Platform Detection

**Primary Technology Stack:**
- Language/Framework: Swift/Vapor 4.110.1+
- Swift Version: Swift 6.0 (swift-tools-version:6.0)
- Runtime/Platform: macOS 15+
- OpenAPI Spec Version: 3.0.1

**Build System:**
- Swift Package Manager (SPM)
- Package.swift manifest at root

## Dependencies Analysis

### Required Dependencies
| Dependency | Version | Purpose | Source |
|------------|---------|---------|--------|
| VaporToOpenAPI | 4.8.1+ | Generate OpenAPI 3.0.1 specs from Vapor routes | New |
| Vapor | 4.110.1+ (existing) | Web framework | Existing |

### Optional Dependencies
| Dependency | Version | Purpose | Trade-off |
|------------|---------|---------|-----------|
| Swagger UI static files | Latest | Serve interactive documentation UI | Could use external hosting instead, but embedding provides better developer experience |

### Integration Notes

VaporToOpenAPI is compatible with Vapor 4.110.1 based on [GitHub repository](https://github.com/dankinsoid/VaporToOpenAPI) and [Swift Package Index](https://swiftpackageindex.com/dankinsoid/VaporToOpenAPI). The library generates OpenAPI 3.0.1 compliant specifications and provides:
- Route introspection via `app.routes.openAPI`
- Grouping via `groupedOpenAPI` methods
- Exclusion via `excludeFromOpenAPI`
- Automatic schema generation from `Content`-conforming types

## Codebase Patterns

### Architectural Patterns Found
- **Pattern:** Modular Route Registration via `RouteCollection` + `ModuleInterface`
  - **Location:** `Sources/App/Modules/*/AuthRouter.swift:3` (and 4 other modules)
  - **Usage:** Each module implements `RouteCollection` with `boot(routes:)` method that registers routes using `.grouped()` chaining
  - **Relevance:** VaporToOpenAPI annotations must be added to each router's `boot()` method

**Example from AuthRouter:**
```swift
struct AuthRouter: RouteCollection {
    let controller = AuthController()

    func boot(routes: RoutesBuilder) throws {
        let api = routes
            .grouped("api")
            .grouped("auth")

        api
            .grouped(UserCredentialsAuthenticator())
            .post("sign-in", use: controller.signIn)

        api.post("sign-up", use: controller.signUp)
        // ... 4 more routes
    }
}
```

### Code Conventions
- **State Management:** Repository pattern with use case layer
  - Example: `Sources/App/Modules/Auth/AuthController.swift` (controllers call use cases)
- **Error Handling:** Custom error types conforming to `AbortError` protocol
  - Example: `Sources/App/Errors/AuthenticationError.swift` (converts to HTTP status codes)
  - Errors thrown from controllers automatically convert to HTTP responses
- **Async Patterns:** Swift async/await throughout
  - Example: All controller methods use `async throws -> Response`

### Naming Conventions
- Files: PascalCase for types (e.g., `AuthRouter.swift`, `UserController.swift`)
- Types: PascalCase structs/enums (e.g., `struct AuthRouter`, `enum Auth`)
- Functions: camelCase (e.g., `func boot(routes:)`, `func signIn(_ req:)`)
- Routes: kebab-case for URL paths (e.g., `/api/auth/sign-in`, `/game-box-analysis`)

### DTO Pattern
**Nested Enum Structure:**
```swift
public enum Auth {}

public extension Auth {
    enum Login {
        public struct Request: Codable { ... }
        public struct Response: Codable { ... }
    }
    enum SignUp {
        public struct Request: Codable { ... }
        public struct Response: Codable { ... }
    }
}
```

All request/response types conform to `Codable` or Vapor's `Content` protocol for automatic schema generation.

## Integration Points

### Components to Modify
| Component | Location | Change Type | Impact |
|-----------|----------|-------------|--------|
| Package.swift | `Package.swift:14-22` | Add dependency | New VaporToOpenAPI package |
| configure.swift | `Sources/App/Entrypoint/configure.swift:9-28` | Add OpenAPI setup | Register `/openapi.json` endpoint and Swagger UI |
| AuthRouter | `Sources/App/Modules/Auth/AuthRouter.swift:6-24` | Add metadata | 6 endpoint descriptions + auth schemes |
| UserRouter | `Sources/App/Modules/User/UserRouter.swift` | Add metadata | 4 endpoint descriptions + auth schemes |
| RulesGenerationRouter | `Sources/App/Modules/RulesGeneration/RulesGenerationRouter.swift` | Add metadata | 2 endpoint descriptions |
| CacheAdminRouter | `Sources/App/Modules/CacheAdmin/CacheAdminRouter.swift` | Add metadata | 6 endpoint descriptions + admin auth |
| FrontendRouter | `Sources/App/Modules/Frontend/FrontendRouter.swift` | Add metadata | 3 endpoint descriptions |

### Dependencies Between Components
```
Package.swift
     ↓ (provides VaporToOpenAPI)
configure.swift → app.routes.openAPI → Reads all registered routes
     ↓                                          ↓
setupModules()                            Router metadata
     ↓                                          ↓
[Auth|User|Rules|Cache|Frontend]Module.boot() → Registers routes with metadata
```

**Description:** VaporToOpenAPI uses reflection to inspect all registered Vapor routes. Metadata is attached to routes via `.grouped()` methods that accept OpenAPI configuration closures. The `app.routes.openAPI` method generates the complete spec by traversing all registered routes.

### External Integrations
- **API/Service:** None (self-contained)
- **Swagger UI:** Static files served from application
  - Endpoint: TBD (common patterns: `/docs`, `/api-docs`, `/swagger`)
  - Authentication: None (public access to documentation)
  - Data Format: HTML + JavaScript (Swagger UI client-side app)

## Clarifications Resolved

> No explicit `[NEEDS CLARIFICATION]` items in requirements.md, but several implicit decisions made:

### Clarification 1: Swagger UI Hosting Strategy
**Question:** Should Swagger UI be embedded in the application or externally hosted?
**Finding:** VaporToOpenAPI documentation and common patterns suggest embedding static files
**Decision:** Serve Swagger UI from the Vapor application at a dedicated endpoint
**Source:** [VaporToOpenAPI GitHub examples](https://github.com/dankinsoid/VaporToOpenAPI) and Vapor ecosystem conventions

**Rationale:** Embedding provides:
- Single deployment artifact
- No CORS issues
- Works in offline/internal environments
- Simpler developer workflow (one server to run)

### Clarification 2: Documentation Annotation Approach
**Question:** Should we use VaporToOpenAPI's route-level metadata or controller-level attributes?
**Finding:** VaporToOpenAPI uses route builder chaining (`.grouped()`) for metadata
**Decision:** Add metadata in router `boot()` methods using `.groupedOpenAPI()` and route-level descriptions
**Source:** VaporToOpenAPI documentation and existing codebase router pattern at `AuthRouter.swift:6-24`

**Rationale:** Keeps documentation close to route definitions and follows existing architectural pattern.

### Clarification 3: Streaming Endpoint Documentation
**Question:** How to document the streaming image analysis endpoint?
**Finding:** Route at `RulesGenerationRouter.swift:10-14` uses `.on(.POST, "game-box-analysis", body: .stream)`
**Decision:** Document as standard POST with `multipart/form-data` or `image/*` content type
**Source:** Vapor streaming body handling and OpenAPI 3.0.1 request body schema

**Rationale:** OpenAPI 3.0.1 doesn't have special streaming semantics; the content type and schema are sufficient.

## Technical Decisions

### Decision 1: OpenAPI Specification Endpoint Path
**Choice:** `/openapi.json`
**Rationale:** Industry standard path used by tools like Swagger UI, Postman, and OpenAPI generators
**Alternatives Considered:**
- `/api/openapi.json`: Rejected because spec describes API, isn't part of API itself
- `/swagger.json`: Rejected because OpenAPI is the modern standard name (Swagger is legacy)

**Impact:** Tooling will automatically discover spec at expected location

### Decision 2: Swagger UI Endpoint Path
**Choice:** `/docs` (with redirect from `/swagger` for discoverability)
**Rationale:** Short, memorable, clearly indicates purpose
**Alternatives Considered:**
- `/api-docs`: Rejected as too long
- `/swagger`: Rejected as legacy naming (but will add redirect)
- `/swagger-ui`: Rejected as too verbose

**Impact:** Developers can quickly access docs at memorable URL

### Decision 3: Endpoint Grouping Strategy
**Choice:** Group by module using OpenAPI tags matching existing module structure
**Rationale:** Codebase already organized into 5 modules (Auth, User, RulesGeneration, CacheAdmin, Frontend)
**Alternatives Considered:**
- Flat list: Rejected because 21 endpoints need organization
- By resource type: Rejected because modules already provide logical grouping

**Impact:** Swagger UI will show 5 collapsible sections matching codebase structure

**Tags:**
- `Auth` - Authentication and authorization operations
- `User` - User account management
- `Rules Generation` - AI-powered game rule analysis
- `Cache Admin` - Administrative cache operations
- `Frontend` - Web-facing HTML endpoints

### Decision 4: Authentication Security Schemes
**Choice:** Define two security schemes in OpenAPI spec
1. `bearerAuth` (JWT token in `Authorization: Bearer <token>` header)
2. `basicAuth` (email/password in request body for sign-in only)

**Rationale:**
- Matches existing authentication middleware at `UserPayloadAuthenticator.swift:1-20` (JWT) and `UserCredentialsAuthenticator.swift:1-29` (credentials)
- Different endpoints use different auth methods

**Alternatives Considered:**
- Single scheme: Rejected because sign-in uses different auth than other endpoints
- HTTP Basic Auth: Rejected because credentials authenticator uses JSON body, not Basic header

**Impact:** Swagger UI "Authorize" button will prompt for JWT token; sign-in endpoint will show body parameters

### Decision 5: Description Placement Strategy
**Choice:** Use VaporToOpenAPI's route-level `.description()` modifier
**Rationale:** Keeps documentation in router files where routes are defined
**Alternatives Considered:**
- Separate YAML file: Rejected because it separates docs from code
- Controller method attributes: Rejected because VaporToOpenAPI reads route metadata, not controller metadata

**Impact:** Each endpoint gets concise description in router's `boot()` method

## Performance Considerations

**Constraints Identified:**
- OpenAPI spec generation: Should be minimal overhead (VaporToOpenAPI uses reflection once at startup)
- Swagger UI: Static file serving has negligible impact
- No runtime performance impact on API endpoints themselves

**Optimization Opportunities:**
- Cache generated OpenAPI JSON spec in production (regenerate only on app restart)
- Serve Swagger UI static files with HTTP caching headers

## Risks & Unknowns

### Known Risks
1. **Risk:** VaporToOpenAPI may not support all 21 endpoint types (especially streaming)
   - **Mitigation:** Test with streaming endpoint first; fall back to manual schema if needed
   - **Impact if unaddressed:** Incomplete documentation for image analysis endpoint

2. **Risk:** Existing DTOs may not generate accurate schemas without additional annotations
   - **Mitigation:** Review generated schemas; add `@Field` or `@Schema` attributes if needed
   - **Impact if unaddressed:** Confusing or incorrect request/response examples in Swagger UI

3. **Risk:** Authentication testing in Swagger UI may not work with current JWT implementation
   - **Mitigation:** Test authentication flow early; may need to configure CORS or token storage
   - **Impact if unaddressed:** Developers can view docs but not test authenticated endpoints

### Remaining Unknowns
- [ ] Does VaporToOpenAPI support nested path parameters? (e.g., `/api/admin/cache/redis/health`)
- [ ] How are Vapor validation errors represented in OpenAPI schemas? (Auth.Login.Request.validate)

**Note:** These can be discovered during implementation; not blockers.

## Research Summary

**Key Findings:**
1. **Codebase is well-structured for OpenAPI integration**: Modular router architecture with consistent DTO patterns makes metadata addition straightforward
2. **VaporToOpenAPI is mature and compatible**: Version 4.8.1+ supports Vapor 4.110.1 with OpenAPI 3.0.1 output
3. **21 endpoints across 5 modules**: Clear grouping strategy emerges from existing architecture
4. **Two authentication schemes**: JWT bearer tokens (most endpoints) and credentials-based (sign-in only)
5. **All DTOs use Codable/Content**: Automatic schema generation will work without manual intervention for most types

**Confidence Level:** High
- All requirements clarifications resolved
- Clear path forward with existing patterns
- VaporToOpenAPI is proven library with active maintenance
- No major technical blockers identified

**Recommended Next Steps:**
1. Add VaporToOpenAPI dependency to Package.swift
2. Configure OpenAPI metadata in configure.swift (API info, servers, security schemes)
3. Add endpoint descriptions to routers (starting with Auth module as proof-of-concept)
4. Set up Swagger UI endpoint
5. Test generated spec with all 21 endpoints
6. Iterate on descriptions based on generated output

---

**Ready for Planning:** Yes
