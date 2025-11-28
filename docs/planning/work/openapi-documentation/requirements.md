---
type: feature
status: draft
priority: P2
created: 2025-11-28
slug: openapi-documentation
feature_branch: feature/openapi-documentation
---

# Add OpenAPI/Swagger Documentation with Interactive Testing

## Overview

**Context**: The API currently has 21 endpoints across 5 modules (Auth, User, RulesGeneration, CacheAdmin, Frontend) with no automated documentation or interactive testing capability. Manual API testing requires crafting curl commands or using external tools without type-safe schemas.

**Objective**: Integrate VaporToOpenAPI (version 4.8.1+) to automatically generate OpenAPI 3.0.1 specifications from existing Vapor routes and add concise, focused documentation to all endpoints. Enable interactive API testing through Swagger UI.

**Impact**: Solo developer can test APIs interactively, understand endpoint behavior at a glance, and maintain accurate documentation as routes evolve.

## User Stories

### Primary Stories (P1)

**US-1**: As a developer, I want to access an OpenAPI spec endpoint so that I can view my complete API documentation in standard format

**Acceptance Scenario**:
- **Given** the application is running
- **When** I navigate to `/openapi.json`
- **Then** I receive a valid OpenAPI 3.0.1 JSON specification containing all 21 API routes with their schemas

**US-2**: As a developer, I want interactive API testing so that I can quickly verify endpoint behavior without writing curl commands

**Acceptance Scenario**:
- **Given** I access Swagger UI
- **When** I select an endpoint and provide test parameters
- **Then** I can execute the request and see the response inline

**US-3**: As a developer, I want concise endpoint documentation so that I understand why an endpoint exists and when to use it

**Acceptance Scenario**:
- **Given** I view any endpoint in the OpenAPI spec
- **When** I read its description
- **Then** I understand the endpoint's purpose, use case, and expected response without reading code

### Secondary Stories (P2)

**US-4**: As a developer, I want authentication requirements documented so that I know which endpoints need tokens

**Acceptance Scenario**:
- **Given** I view a protected endpoint
- **When** I check its security requirements
- **Then** I see whether it requires user authentication or admin privileges

## Requirements

1. **REQ-001**: Add VaporToOpenAPI package dependency at version 4.8.1 or later
   - Rationale: Enables automatic OpenAPI spec generation from existing Vapor routes without code rewrite

2. **REQ-002**: Configure OpenAPI metadata with API title, version, and description
   - Rationale: Provides context about the API as a whole in generated documentation

3. **REQ-003**: Expose OpenAPI specification at `/openapi.json` endpoint
   - Rationale: Standard endpoint for tools and developers to access machine-readable API spec

4. **REQ-004**: Add concise descriptions to all 21 API endpoints explaining purpose and use case
   - Rationale: Developers need to understand why an endpoint exists and when to use it, not just what HTTP method it uses

5. **REQ-005**: Document request schemas for all endpoints accepting body content
   - Rationale: Developers need to know what data structure to send

6. **REQ-006**: Document response schemas for all endpoints
   - Rationale: Developers need to know what data structure to expect back

7. **REQ-007**: Document authentication requirements for protected endpoints
   - Rationale: Developers need to know which endpoints require tokens or admin privileges

8. **REQ-008**: Serve Swagger UI from an endpoint for interactive testing
   - Rationale: Enables testing APIs directly in the browser without external tools or manual curl commands

9. **REQ-009**: Group endpoints by module (Auth, User, RulesGeneration, CacheAdmin, Frontend)
   - Rationale: Logical organization makes documentation navigable for 21+ endpoints

10. **REQ-010**: Documentation must focus on "why" and "when", not "what"
    - Rationale: Technical details (HTTP method, path) are auto-generated; human documentation should explain intent

## Acceptance Criteria

### Functional Acceptance
- [ ] **Given** the app is running, **When** I request `/openapi.json`, **Then** I receive valid OpenAPI 3.0.1 JSON with all 21 routes
- [ ] **Given** the app is running, **When** I navigate to the Swagger UI endpoint, **Then** I see an interactive documentation interface
- [ ] **Given** I view any endpoint in Swagger UI, **When** I read its description, **Then** I understand its purpose without reading code
- [ ] **Given** I select a POST endpoint in Swagger UI, **When** I view the request schema, **Then** I see all required fields with types
- [ ] **Given** I select any endpoint in Swagger UI, **When** I view the response schema, **Then** I see the expected response structure
- [ ] **Given** I select a protected endpoint, **When** I view its security requirements, **Then** I see authentication is required
- [ ] **Given** I access Swagger UI, **When** I execute a test request with valid data, **Then** I receive the expected response inline
- [ ] **Given** I view the OpenAPI spec, **When** I check endpoint organization, **Then** endpoints are grouped by module (Auth, User, etc.)

### Documentation Quality
- [ ] Every endpoint has a concise description (1-2 sentences) explaining its purpose
- [ ] Descriptions focus on "why" (use case) rather than "what" (technical details)
- [ ] Protected endpoints clearly indicate authentication requirements
- [ ] No placeholder or auto-generated generic descriptions remain

### Edge Cases
- [ ] Handles streaming endpoints (game-box-analysis) correctly in documentation
- [ ] Handles endpoints with path parameters correctly
- [ ] Handles endpoints with query parameters correctly

## Affected Areas

**Components**:
- **Package Dependencies** - VaporToOpenAPI package addition
- **Application Configuration** - OpenAPI setup and route registration
- **Auth Module** - 6 endpoints requiring documentation
- **User Module** - 4 endpoints requiring documentation
- **RulesGeneration Module** - 2 endpoints requiring documentation
- **CacheAdmin Module** - 6 endpoints requiring documentation
- **Frontend Module** - 3 endpoints requiring documentation

**Files**:
- `Package.swift` - Add VaporToOpenAPI dependency
- `Sources/App/Entrypoint/configure.swift` - Configure OpenAPI, add spec endpoint, and serve Swagger UI
- `Sources/App/Modules/Auth/AuthRouter.swift` - Add endpoint documentation metadata
- `Sources/App/Modules/User/UserRouter.swift` - Add endpoint documentation metadata
- `Sources/App/Modules/RulesGeneration/RulesGenerationRouter.swift` - Add endpoint documentation metadata
- `Sources/App/Modules/CacheAdmin/CacheAdminRouter.swift` - Add endpoint documentation metadata
- `Sources/App/Modules/Frontend/FrontendRouter.swift` - Add endpoint documentation metadata

**Related Systems**:
- **Authentication Middleware** - Security schemes must be documented in OpenAPI spec
- **Content Types** - Request/response DTOs automatically generate schemas via VaporToOpenAPI

## Assumptions

- VaporToOpenAPI 4.8.1+ is compatible with current Vapor 4.110.1+ version
- Existing Content-conforming types provide sufficient schema information without manual annotation
- Swagger UI will be embedded in the application and accessible via HTTP endpoint
- Documentation will be in English
- OpenAPI spec follows version 3.0.1 standard (no version tagging in endpoint path)
- All 21 routes will be documented (no exclusions)
- Current inline code documentation may be outdated and should not be blindly trusted for endpoint descriptions

---

**Next Steps**: Proceed to implementation planning with `/plan`.
