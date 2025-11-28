# Implementation Plan: OpenAPI/Swagger Documentation

---
**Date:** 2025-11-28
**Requirements:** `docs/planning/work/openapi-documentation/requirements.md`
**Research:** `docs/planning/work/openapi-documentation/research.md`
**Linear Issue:** N/A
**Feature Branch:** `feature/openapi-documentation`
**Status:** draft

---

## Summary

**What:** Integrate VaporToOpenAPI to automatically generate OpenAPI 3.0.1 specifications from existing Vapor routes and serve interactive Swagger UI for testing all 21 API endpoints.

**Why:** Enable interactive API testing and maintain accurate documentation as routes evolve, eliminating manual curl commands and external tools.

**Who:** Solo developer working on Project Rulebook API

## Technical Context

### Platform & Technology
- **Stack:** Swift 6.0 + Vapor 4.110.1 (server-side Swift web framework)
- **Version Requirements:** macOS 15+
- **Build System:** Swift Package Manager (SPM)

### Key Dependencies
**Required:**
- VaporToOpenAPI 4.8.1+: OpenAPI 3.0.1 spec generation from Vapor routes
- Vapor 4.110.1+ (existing): Web framework providing route registration and middleware

**Optional:**
- Swagger UI static bundle: Interactive documentation UI (will embed in application)

### Architectural Patterns
**Primary Pattern:** Modular Route Registration via `RouteCollection` + `ModuleInterface`
**Rationale:** Existing codebase uses 5 modules (Auth, User, RulesGeneration, CacheAdmin, Frontend) where each module implements `RouteCollection` with a `boot(routes:)` method. VaporToOpenAPI integrates seamlessly with this pattern by allowing metadata to be added during route registration.

**Key Principles:**
- **Metadata co-location**: Documentation lives in router files alongside route definitions
- **Automatic schema generation**: DTOs conforming to `Codable`/`Content` generate schemas without manual annotation
- **Tag-based organization**: OpenAPI tags map to existing module structure for logical grouping

### Files to Modify/Create
| File | Action | Purpose |
|------|--------|---------|
| `Package.swift` | Modify | Add VaporToOpenAPI dependency |
| `Sources/App/Entrypoint/configure.swift` | Modify | Configure OpenAPI metadata, register spec endpoint, serve Swagger UI |
| `Sources/App/Modules/Auth/AuthRouter.swift` | Modify | Add descriptions and metadata for 6 auth endpoints |
| `Sources/App/Modules/User/UserRouter.swift` | Modify | Add descriptions and metadata for 4 user endpoints |
| `Sources/App/Modules/RulesGeneration/RulesGenerationRouter.swift` | Modify | Add descriptions and metadata for 2 AI endpoints |
| `Sources/App/Modules/CacheAdmin/CacheAdminRouter.swift` | Modify | Add descriptions and metadata for 6 admin cache endpoints |
| `Sources/App/Modules/Frontend/FrontendRouter.swift` | Modify | Add descriptions and metadata for 3 frontend HTML endpoints |
| `Sources/App/Common/OpenAPI/` (new directory) | Create | Swagger UI static files and configuration |

## Technical Decisions

### Decision Summary
Key architectural and technical choices made during research:

1. **OpenAPI Spec Endpoint: `/openapi.json`**
   - Rationale: Industry standard path recognized by tooling (Swagger UI, Postman, generators)
   - Impact: Automatic tool discovery without configuration

2. **Swagger UI Endpoint: `/docs` with redirect from `/swagger`**
   - Rationale: Short, memorable URL; redirect provides discoverability for developers expecting `/swagger`
   - Impact: Quick access to interactive docs at easy-to-remember path

3. **Grouping Strategy: OpenAPI tags matching module structure**
   - Rationale: Codebase already organized into 5 logical modules
   - Impact: Swagger UI shows 5 collapsible sections (Auth, User, Rules Generation, Cache Admin, Frontend)

4. **Authentication Schemes: Bearer JWT + Credentials (body-based)**
   - Rationale: Matches existing middleware (`UserPayloadAuthenticator` for JWT, `UserCredentialsAuthenticator` for sign-in)
   - Impact: Swagger UI "Authorize" button for JWT; sign-in shows body parameters

5. **Description Strategy: Route-level `.description()` modifiers**
   - Rationale: VaporToOpenAPI reads route metadata; keeps docs with route definitions
   - Impact: Each router's `boot()` method contains inline documentation

## Phase Breakdown

> High-level implementation phases. Detailed tasks will be generated separately.

### Phase 0: Setup & Infrastructure
**Goal:** Add VaporToOpenAPI dependency and configure basic OpenAPI metadata

**Deliverables:**
- [ ] VaporToOpenAPI 4.8.1+ added to Package.swift and resolved
- [ ] OpenAPI configuration in configure.swift (API info, version, servers, security schemes)
- [ ] `/openapi.json` endpoint registered and returning basic spec
- [ ] Project builds successfully with new dependency

**Dependencies:** None (can start immediately)

**Estimated Effort:** 1-2 hours

**Success Criteria:**
- `swift build` completes without errors
- `GET /openapi.json` returns valid OpenAPI 3.0.1 JSON
- Generated spec includes API title, version, and empty paths object

**Technical Approach:**
Add VaporToOpenAPI to Package.swift dependencies, configure `app.routes.openAPI` in configure.swift with API metadata (title: "Project Rulebook API", version from app config), define two security schemes (bearerAuth for JWT, basicAuth for credentials), and register `/openapi.json` route that returns the generated spec.

---

### Phase 1: Auth Module Documentation
**Goal:** Add complete OpenAPI metadata to all 6 Auth endpoints as proof-of-concept

**Deliverables:**
- [ ] Auth endpoints grouped under "Auth" tag
- [ ] Descriptions added for all 6 endpoints (sign-in, sign-up, apple-auth, refresh, reset-password, logout)
- [ ] Request/response schemas generated for Auth.Login, Auth.SignUp, Auth.Apple, Auth.TokenRefresh, Auth.PasswordReset
- [ ] Security requirements documented (sign-in uses credentials, logout uses JWT)
- [ ] Generated spec validates against OpenAPI 3.0.1 schema

**Dependencies:**
- Requires: Phase 0 (OpenAPI infrastructure)
- Blocks: Phase 2 (pattern established for other modules)

**Estimated Effort:** 2-3 hours

**Success Criteria:**
- All 6 Auth endpoints appear in `/openapi.json` under "Auth" tag
- Each endpoint has 1-2 sentence description explaining purpose
- Request/response schemas match actual DTO structures
- Swagger UI validation shows no errors for Auth endpoints

**Technical Approach:**
In AuthRouter.swift, wrap the existing `routes.grouped("api").grouped("auth")` with `.groupedOpenAPI(tag: "Auth")`. For each route registration (e.g., `.post("sign-in", use: controller.signIn)`), add `.description("Authenticate user with email and password, returns JWT tokens")` and security requirements. Verify that VaporToOpenAPI automatically generates schemas from `Auth.Login.Request/Response` types.

---

### Phase 2: User, RulesGeneration, CacheAdmin, Frontend Module Documentation
**Goal:** Apply established pattern to remaining 15 endpoints across 4 modules

**Deliverables:**
- [ ] User module (4 endpoints) documented with "User" tag
- [ ] RulesGeneration module (2 endpoints) documented with "Rules Generation" tag
- [ ] CacheAdmin module (6 endpoints) documented with "Cache Admin" tag
- [ ] Frontend module (3 endpoints) documented with "Frontend" tag
- [ ] All 21 endpoints have concise, purposeful descriptions
- [ ] Streaming endpoint (game-box-analysis) correctly documented

**Dependencies:**
- Requires: Phase 1 (Auth pattern established)
- Blocks: Phase 3 (all endpoints must be documented first)

**Estimated Effort:** 3-4 hours

**Success Criteria:**
- `/openapi.json` contains all 21 endpoints organized into 5 tags
- No endpoints have placeholder or auto-generated generic descriptions
- All protected endpoints show appropriate security requirements (JWT for user endpoints, JWT + admin role for cache admin)
- Streaming endpoint schema matches actual binary image upload format

**Technical Approach:**
Apply the same pattern as Phase 1 to UserRouter, RulesGenerationRouter, CacheAdminRouter, and FrontendRouter. For each module, add `.groupedOpenAPI(tag: "<Module>")` and route-level descriptions. Pay special attention to the streaming endpoint in RulesGenerationRouter (`.on(.POST, "game-box-analysis", body: .stream)`) to ensure content type is documented as `image/*` or `multipart/form-data`. Test nested paths like `/api/admin/cache/redis/health` to ensure correct path parameter handling.

---

### Phase 3: Swagger UI Integration
**Goal:** Serve interactive Swagger UI for browser-based API testing

**Deliverables:**
- [ ] Swagger UI static files embedded in application
- [ ] `/docs` endpoint serves Swagger UI pointing to `/openapi.json`
- [ ] `/swagger` redirects to `/docs` for discoverability
- [ ] Swagger UI "Authorize" button configured for JWT bearer tokens
- [ ] All 21 endpoints testable from Swagger UI interface

**Dependencies:**
- Requires: Phase 2 (all endpoints documented)

**Estimated Effort:** 2-3 hours

**Success Criteria:**
- Navigate to `/docs` in browser shows Swagger UI interface
- Swagger UI loads OpenAPI spec from `/openapi.json` without errors
- All 5 module groups expand to show endpoints
- Clicking "Authorize" allows entering JWT token
- "Try it out" on any endpoint shows request parameters and executes request

**Technical Approach:**
Create `Sources/App/Common/OpenAPI/` directory and add Swagger UI static files (HTML, CSS, JS) from official distribution. In configure.swift, register a new route group under `/docs` that serves static files with index.html configured to fetch `/openapi.json`. Add a simple redirect route from `/swagger` to `/docs`. Configure Swagger UI's `requestInterceptor` to inject JWT from localStorage if present. Test authentication flow by signing in via `/api/auth/sign-in`, copying JWT from response, clicking "Authorize" in Swagger UI, and testing protected endpoints.

---

### Phase 4: Documentation Quality Review & Edge Cases
**Goal:** Ensure all descriptions are high-quality, test edge cases, and add response examples

**Deliverables:**
- [ ] All endpoint descriptions reviewed for clarity and focus on "why" not "what"
- [ ] Error responses documented (401, 403, 429, 500)
- [ ] Rate limiting headers documented in responses (X-RateLimit-* headers)
- [ ] Edge cases tested (path parameters, query parameters, streaming, nested paths)
- [ ] Example request/response bodies added to key endpoints
- [ ] README or docs/ updated with usage instructions

**Dependencies:**
- Requires: Phase 3 (Swagger UI functional)

**Estimated Effort:** 2-3 hours

**Success Criteria:**
- No descriptions are generic or auto-generated boilerplate
- All descriptions explain purpose and use case, not HTTP method/path
- Protected endpoints show 401/403 error responses
- Rate-limited endpoints show 429 error response with Retry-After header
- At least 5 endpoints have example request/response bodies

**Technical Approach:**
Review each endpoint description against REQ-010 ("focus on why and when, not what"). Add `.response()` modifiers to document common error responses (use Vapor's `HTTPStatus` enum). Add custom response headers to cache admin endpoints showing rate limit info. Test all edge cases: path parameters (verify-email with token query param), query parameters, streaming uploads, nested admin paths. Add example values to key DTOs using VaporToOpenAPI's example annotation syntax. Document Swagger UI usage in README or create `docs/api-documentation.md` with screenshots.

---

## Implementation Strategy

### State Management
No application state changes required. OpenAPI generation is read-only reflection over existing route definitions at application startup.

### Data Flow
```
Application Startup
     ↓
configure.swift: setupModules()
     ↓
Each Module's boot(routes:) registers routes with metadata
     ↓
VaporToOpenAPI inspects registered routes
     ↓
/openapi.json request → app.routes.openAPI → Returns generated spec
     ↓
Swagger UI fetches /openapi.json → Renders interactive docs
```

**Description:** VaporToOpenAPI uses reflection to traverse Vapor's internal route storage. Metadata attached during route registration (tags, descriptions, security requirements) is included in the generated spec. No runtime overhead beyond initial reflection at startup.

### Error Handling
**Strategy:** Use existing Vapor error handling; document common errors in OpenAPI spec

**Error Types to Handle:**
- Authentication errors (401): Documented via security requirements and error response schemas
- Authorization errors (403): Admin-only endpoints show 403 response for non-admin users
- Rate limiting (429): All endpoints can return 429 with X-RateLimit-* headers
- Validation errors (400): Automatic from Vapor's Content validation
- Server errors (500): Generic internal server error response

### Performance Considerations
**Optimization Points:**
- **OpenAPI spec caching**: Generated spec is static per app version; can cache in memory
- **Swagger UI static serving**: Use Vapor's FileMiddleware with cache headers for production

**Constraints:**
- OpenAPI generation overhead: Minimal (one-time reflection at startup)
- No impact on API endpoint performance (documentation is separate concern)

## Dependencies & Risks

### Internal Dependencies
- Phase 1 depends on Phase 0 (infrastructure must exist before documenting endpoints)
- Phase 2 depends on Phase 1 (pattern must be proven before scaling to all modules)
- Phase 3 depends on Phase 2 (Swagger UI needs complete spec to be useful)
- Phase 4 depends on Phase 3 (can't review quality until UI is functional)

### External Dependencies
- VaporToOpenAPI package: Must be compatible with Vapor 4.110.1 (verified in research)
- Swagger UI distribution: Will embed latest stable version from official CDN or GitHub release

### Known Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| VaporToOpenAPI doesn't support streaming endpoints | Medium | Low | Manually define schema for game-box-analysis if needed |
| Existing DTOs generate incorrect schemas | Low | Medium | Add @Schema/@Field annotations as needed; test early |
| JWT authentication doesn't work in Swagger UI | Medium | Medium | Test auth flow in Phase 3; may need CORS or token storage config |
| Generated descriptions are too technical | Low | Low | Review all descriptions in Phase 4 against requirements |

### Assumptions
> Critical assumptions that, if invalid, would require plan revision

- VaporToOpenAPI 4.8.1+ supports nested path parameters (e.g., `/api/admin/cache/redis/health`)
- All `Codable`/`Content` DTOs will generate schemas without manual annotation
- Swagger UI can be embedded without licensing issues (it's Apache 2.0 licensed)
- No API versioning is needed in OpenAPI spec (single version, no `/v1` prefix)

## Acceptance Criteria Mapping

> Maps requirements.md acceptance criteria to implementation phases

| Acceptance Criterion | Phase | Verification Method |
|---------------------|-------|---------------------|
| `/openapi.json` returns valid OpenAPI 3.0.1 JSON with all 21 routes | Phase 0-2 | Validate JSON against OpenAPI 3.0.1 schema; count paths in spec |
| Swagger UI endpoint shows interactive documentation interface | Phase 3 | Navigate to `/docs` in browser; verify UI loads |
| Every endpoint has concise description explaining purpose | Phase 2, 4 | Review descriptions in Swagger UI; verify focus on "why" |
| POST endpoints show request schema with required fields and types | Phase 1-2 | Inspect request body schema in Swagger UI for Auth.Login, etc. |
| All endpoints show expected response structure | Phase 1-2 | Inspect response schema in Swagger UI |
| Protected endpoints show authentication requirements | Phase 1-2 | Verify lock icon in Swagger UI for JWT-protected routes |
| Execute test request with valid data and receive response inline | Phase 3 | Use "Try it out" in Swagger UI on /health or public endpoint |
| Endpoints grouped by module (Auth, User, etc.) | Phase 1-2 | Verify 5 tag sections in Swagger UI |
| Every endpoint has 1-2 sentence description | Phase 2, 4 | Manual review in Phase 4 |
| Descriptions focus on "why" rather than "what" | Phase 4 | Quality review against REQ-010 |
| Protected endpoints indicate authentication requirements | Phase 1-2 | Check security requirements in spec |
| No placeholder or auto-generated descriptions | Phase 4 | Manual review and replacement |
| Streaming endpoint (game-box-analysis) documented correctly | Phase 2 | Test request body schema shows binary/multipart |
| Endpoints with path parameters documented correctly | Phase 2 | Test verify-email endpoint shows token parameter |
| Endpoints with query parameters documented correctly | Phase 2 | Verify query params appear in OpenAPI spec |

## Documentation Plan

**Code Documentation:**
- [ ] Inline comments in configure.swift explaining OpenAPI setup
- [ ] Each router file has comments explaining tag organization
- [ ] No DTO changes needed (schemas auto-generated)

**User Documentation:**
- [ ] README.md updated with link to `/docs` endpoint
- [ ] README.md includes example of accessing Swagger UI
- [ ] README.md documents how to use "Authorize" button for JWT

**Developer Documentation:**
- [ ] Create `docs/development/openapi-integration.md` explaining:
  - How to add new endpoints with documentation
  - How descriptions should be written (focus on why/when)
  - How to test changes in Swagger UI
  - How to regenerate OpenAPI spec (automatic on restart)

## Next Steps

1. **Review this plan** - Ensure all requirements mapped to phases
2. **Clarify any remaining questions** - No blocking unknowns identified
3. **Begin Phase 0** - Add VaporToOpenAPI dependency
4. **Commit at phase boundaries** - Each phase is a logical checkpoint

## Remaining Unknowns

> Issues that need resolution before or during implementation

- [ ] Does VaporToOpenAPI auto-detect nested path parameters? (Test in Phase 2)
- [ ] How are Vapor validation errors represented in schemas? (Discover in Phase 1)

**Impact:** Minor - can be resolved during implementation; no blockers identified

---

**Plan Status:** draft
**Approval Required From:** N/A (solo developer)
**Target Start Date:** 2025-11-28
