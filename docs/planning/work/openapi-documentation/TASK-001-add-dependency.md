## TASK-001: Add VaporToOpenAPI Dependency

---
**Status:** COMPLETE
**Branch:** feature/openapi-documentation
**Type:** IMPLEMENTATION
**Phase:** 1
**Depends On:** None

---

### Overview

Add VaporToOpenAPI package dependency to Package.swift and register the `/openapi.json` endpoint that serves the generated OpenAPI specification. This establishes the foundation for all subsequent documentation work.

### Files Modified

- `Package.swift`
- `Sources/App/Entrypoint/configure.swift`

### Implementation Steps

- [x] Add VaporToOpenAPI package dependency to Package.swift dependencies array
- [x] Add VaporToOpenAPI product to App target dependencies
- [x] Run `swift package resolve` to fetch the new dependency
- [x] Import VaporToOpenAPI in configure.swift
- [x] Register `/openapi.json` endpoint using `app.routes.openAPI`
- [x] Verify endpoint returns basic OpenAPI JSON structure

### Code Example

**File: `Package.swift`**

```swift
dependencies: [
    .package(url: "https://github.com/vapor/vapor.git", from: "4.110.1"),
    .package(url: "https://github.com/vapor/fluent.git", from: "4.8.0"),
    // ... existing dependencies ...
    .package(url: "https://github.com/dankinsoid/VaporToOpenAPI.git", from: "4.8.1"),
],
targets: [
    .executableTarget(
        name: "App",
        dependencies: [
            vapor, fluent,
            // ... existing dependencies ...
            .product(name: "VaporToOpenAPI", package: "VaporToOpenAPI"),
        ]
    ),
]
```

**File: `Sources/App/Entrypoint/configure.swift`**

```swift
import Vapor
import VaporToOpenAPI  // Add this import

public func configure(_ app: Application) throws {
    // ... existing configuration ...
    try app.setupModules()

    // Register OpenAPI endpoint
    app.get("openapi.json") { req -> Response in
        let openAPI = try req.application.routes.openAPI(
            info: .init(
                title: "Project Rulebook API",
                version: "1.0.0"
            )
        )
        return try await openAPI.encodeResponse(for: req)
    }

    // Health check endpoint for Railway
    app.get("health") { req -> [String: String] in
        return [
            "status": "healthy"
        ]
    }

    try app.autoMigrate().wait()
}
```

**Reference: Existing configure.swift pattern (configure.swift:9-28)**
```swift
public func configure(_ app: Application) throws {
    // Initialize configuration first
    try app.setupConfiguration()

    try app.setupDB()
    try app.setupJWT()
    try app.setupRedis()
    try app.setupServices()
    try app.setupMiddleware()
    try app.setupModules()  // Routes registered here

    // Add new endpoints after modules are set up
    app.get("health") { req -> [String: String] in
        return ["status": "healthy"]
    }
}
```

### Success Criteria

- [x] Build succeeds without errors (`swift build`)
- [x] Dependency resolution completes successfully
- [x] No new compiler warnings introduced
- [x] `GET /openapi.json` returns HTTP 200
- [x] Response is valid JSON with OpenAPI 3.0.1 structure
- [x] Response contains `info.title` and `info.version` fields

### Verification Commands

```bash
# Resolve dependencies
swift package resolve

# Build project
swift build

# Run application and test endpoint
swift run &
sleep 5
curl -i http://localhost:8080/openapi.json | head -20
pkill -f "swift run"
```

### Notes

- VaporToOpenAPI will initially generate an empty `paths` object since no route metadata has been added yet
- This is expected and will be populated in subsequent tasks
- The OpenAPI spec version will be 3.0.1 (industry standard, supported by Swagger UI)
