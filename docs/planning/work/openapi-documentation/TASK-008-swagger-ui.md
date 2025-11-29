## TASK-008: Integrate Swagger UI

---
**Status:** COMPLETE
**Branch:** feature/openapi-documentation
**Type:** INTEGRATION
**Phase:** 1
**Depends On:** TASK-003, TASK-004, TASK-005, TASK-006, TASK-007

---

### Overview

Integrate Swagger UI to serve interactive API documentation at `/docs` endpoint. Configure Swagger UI to load the `/openapi.json` spec and enable JWT authentication testing via the "Authorize" button.

### Files Modified

- `Sources/App/Entrypoint/configure.swift`
- `Sources/App/Common/OpenAPI/` (new directory for Swagger UI files)

### Implementation Steps

- [x] Create `Sources/App/Common/OpenAPI/` directory
- [x] Download Swagger UI distribution (standalone HTML bundle)
- [x] Create `swagger-ui.html` file configured to load `/openapi.json`
- [x] Configure Swagger UI with JWT bearer token support
- [x] Register `/docs` route in configure.swift that serves swagger-ui.html
- [x] Register `/swagger` redirect route pointing to `/docs`
- [x] Test Swagger UI loads and displays all 21 endpoints
- [x] Test "Authorize" button accepts JWT token
- [x] Test "Try it out" executes requests successfully

### Code Example

**File: `Sources/App/Common/OpenAPI/swagger-ui.html`**

```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Project Rulebook API Documentation</title>
    <link rel="stylesheet" type="text/css" href="https://unpkg.com/swagger-ui-dist@5.10.0/swagger-ui.css">
    <style>
        html { box-sizing: border-box; overflow: -moz-scrollbars-vertical; overflow-y: scroll; }
        *, *:before, *:after { box-sizing: inherit; }
        body { margin:0; padding:0; }
    </style>
</head>
<body>
    <div id="swagger-ui"></div>
    <script src="https://unpkg.com/swagger-ui-dist@5.10.0/swagger-ui-bundle.js"></script>
    <script src="https://unpkg.com/swagger-ui-dist@5.10.0/swagger-ui-standalone-preset.js"></script>
    <script>
        window.onload = function() {
            const ui = SwaggerUIBundle({
                url: "/openapi.json",
                dom_id: '#swagger-ui',
                deepLinking: true,
                presets: [
                    SwaggerUIBundle.presets.apis,
                    SwaggerUIStandalonePreset
                ],
                plugins: [
                    SwaggerUIBundle.plugins.DownloadUrl
                ],
                layout: "StandaloneLayout",
                persistAuthorization: true  // Remember JWT token across page reloads
            });
            window.ui = ui;
        };
    </script>
</body>
</html>
```

**File: `Sources/App/Entrypoint/configure.swift`**

```swift
import Vapor
import VaporToOpenAPI
import OpenAPIKit

public func configure(_ app: Application) throws {
    // ... existing configuration ...
    try app.setupModules()

    // Register OpenAPI spec endpoint
    app.get("openapi.json") { req -> Response in
        let openAPI = try req.application.routes.openAPI(
            info: .init(
                title: "Project Rulebook API",
                description: "...",
                version: "1.0.0"
            ),
            servers: [
                .init(url: URL(string: "http://localhost:8080")!, description: "Development"),
            ],
            components: .init(
                securitySchemes: [
                    "bearerAuth": .init(
                        type: .http,
                        scheme: "bearer",
                        bearerFormat: "JWT",
                        description: "JWT access token obtained from /api/auth/sign-in or /api/auth/sign-up"
                    )
                ]
            )
        )
        return try await openAPI.encodeResponse(for: req)
    }

    // Serve Swagger UI at /docs
    app.get("docs") { req -> Response in
        let html = try String(contentsOfFile: app.directory.workingDirectory + "Sources/App/Common/OpenAPI/swagger-ui.html")
        return Response(
            status: .ok,
            headers: ["Content-Type": "text/html"],
            body: .init(string: html)
        )
    }

    // Redirect /swagger to /docs for discoverability
    app.get("swagger") { req -> Response in
        return req.redirect(to: "/docs", redirectType: .permanent)
    }

    // Health check endpoint
    app.get("health") { req -> [String: String] in
        return ["status": "healthy"]
    }

    try app.autoMigrate().wait()
}
```

**Reference: Swagger UI Authentication Flow**
1. Navigate to http://localhost:8080/docs
2. Click "Authorize" button (top right)
3. Enter JWT token from sign-in response: `Bearer <token>`
4. Click "Authorize" in dialog
5. Click "Close"
6. JWT is now included in all "Try it out" requests

**Reference: Testing Workflow**
1. Use Swagger UI to call POST /api/auth/sign-in
2. Copy `accessToken` from response
3. Click "Authorize" and paste token
4. Try protected endpoints (e.g., GET /api/user/me)
5. Verify request succeeds with 200 response

### Success Criteria

- [ ] Build succeeds without errors
- [ ] `/docs` endpoint returns HTML page (HTTP 200)
- [ ] Swagger UI interface loads in browser
- [ ] All 21 endpoints visible under 5 tags (Auth, User, Rules Generation, Cache Admin, Frontend)
- [ ] `/swagger` redirects to `/docs` (HTTP 301/308)
- [ ] "Authorize" button visible in Swagger UI
- [ ] Clicking "Authorize" shows bearerAuth input field
- [ ] "Try it out" on public endpoint (e.g., /health) succeeds
- [ ] "Try it out" on protected endpoint requires authorization

### Verification Commands

```bash
# Build project
swift build

# Run application
swift run &
sleep 5

# Test /docs endpoint
curl -i http://localhost:8080/docs | head -20

# Test /swagger redirect
curl -i http://localhost:8080/swagger

# Verify OpenAPI spec accessible
curl -s http://localhost:8080/openapi.json | jq '.info.title'

# Count total endpoints
curl -s http://localhost:8080/openapi.json | jq '.paths | length'

# Manual testing in browser
open http://localhost:8080/docs

pkill -f "swift run"
```

### Notes

- Using Swagger UI 5.10.0 from CDN (unpkg.com) for simplicity
- `persistAuthorization: true` keeps JWT token across page reloads for better UX
- Alternative: Download and vendor Swagger UI static files for offline/air-gapped deployments
- The `/swagger` redirect helps developers who expect that common URL pattern
- Swagger UI automatically discovers security schemes from OpenAPI spec
