## TASK-005: Document RulesGeneration Module Endpoints

---
**Status:** COMPLETE
**Branch:** feature/openapi-documentation
**Type:** IMPLEMENTATION
**Phase:** 1
**Depends On:** TASK-002

---

### Overview

Add OpenAPI documentation metadata to the 2 RulesGeneration module endpoints. These are public AI-powered endpoints with rate limiting. Special attention needed for the streaming image upload endpoint.

### Files Modified

- `Sources/App/Modules/RulesGeneration/RulesGenerationRouter.swift`

### Implementation Steps

- [x] Add "Rules Generation" tag to the rules-generation route group
- [x] Document game box analysis endpoint (POST /api/rules-generation/game-box-analysis) with image upload and AI recognition description
- [x] Specify multipart/form-data or image/* content type for streaming endpoint
- [x] Document rules summary endpoint (POST /api/rules-generation/rules-summary) with AI-generated summary description
- [x] Note rate limiting in descriptions (from RateLimitMiddleware)
- [x] Verify both endpoints appear under "Rules Generation" tag in `/openapi.json`

### Code Example

**File: `Sources/App/Modules/RulesGeneration/RulesGenerationRouter.swift`**

```swift
import Vapor
import VaporToOpenAPI

struct RulesGenerationRouter: RouteCollection {
    let controller = RulesGenerationController()

    func boot(routes: any RoutesBuilder) throws {
        let api = routes
            .grouped("api")
            .grouped("rules-generation")
            .groupedOpenAPI(tag: "Rules Generation")  // Tag all AI endpoints

        // Image analysis endpoint - streaming binary data
        api
            .on(.POST, "game-box-analysis", body: .stream, use: controller.analyzeBoxPhoto)
            .description("Upload game box image for AI-powered title recognition. Returns guessed title, confidence score, and alternative suggestions. Rate limited to 3 requests/hour in production.")
            .requestBody(
                description: "Binary image data (JPEG, PNG, or HEIC format)",
                content: [
                    "image/jpeg": .init(schema: .string(format: .binary)),
                    "image/png": .init(schema: .string(format: .binary)),
                    "image/heic": .init(schema: .string(format: .binary))
                ]
            )

        // Rules generation endpoint - JSON input/output
        api
            .post("rules-summary", use: controller.generateRulesSummary)
            .description("Generate AI-powered rules summary for a board game by title. Returns setup instructions, first round guide, win conditions, and helpful resources. Rate limited to 10 requests/hour in production.")
    }
}
```

**Reference: Existing RulesGenerationRouter pattern (from research.md)**
```swift
struct RulesGenerationRouter: RouteCollection {
    let controller = RulesGenerationController()

    func boot(routes: any RoutesBuilder) throws {
        let api = routes
            .grouped("api")
            .grouped("rules-generation")

        // Image analysis endpoint - rate limiting handled by RateLimitMiddleware
        api.on(
            .POST, "game-box-analysis",
            body: .stream,  // Stream body for large files
            use: controller.analyzeBoxPhoto
        )

        // Rules generation endpoint
        api.post("rules-summary", use: controller.generateRulesSummary)
    }
}
```

**Reference: Rate limiting configuration (from research.md)**
```swift
// From RateLimitMiddleware.swift:167-211
private func determineRateLimit(for request: Request) -> RateLimitInfo {
    let path = request.url.path

    // AI-specific endpoints (3-50 requests/hour)
    if path.contains("/api/rules-generation/game-box-analysis") {
        return RateLimitInfo(type: .imageAnalysis, ...)
    }

    if path.contains("/api/rules-generation/rules-summary") {
        return RateLimitInfo(type: .rulesGeneration, ...)
    }
}
```

**Reference: RulesGeneration DTOs**
Schemas auto-generated from:
- `GameboxRecognition.Request` / `GameboxRecognition.Response` (image analysis)
- `RulesSummary.Request` / `RulesSummary.Response` (rules summary)

### Success Criteria

- [ ] Build succeeds without errors
- [ ] Both endpoints appear in `/openapi.json` under "Rules Generation" tag
- [ ] Each endpoint has description explaining AI functionality
- [ ] Game box analysis endpoint shows image/* content types
- [ ] Descriptions mention rate limiting
- [ ] Request/response schemas match DTO structures
- [ ] No security requirements (public endpoints)

### Verification Commands

```bash
# Build project
swift build

# Run and verify RulesGeneration endpoints
swift run &
sleep 5

# List all Rules Generation endpoints
curl -s http://localhost:8080/openapi.json | jq '.paths | to_entries | map(select(.key | contains("/rules-generation/"))) | from_entries'

# Check game-box-analysis request body content types
curl -s http://localhost:8080/openapi.json | jq '.paths["/api/rules-generation/game-box-analysis"].post.requestBody'

# Verify no security requirements (public endpoints)
curl -s http://localhost:8080/openapi.json | jq '.paths["/api/rules-generation/game-box-analysis"].post.security'

pkill -f "swift run"
```

### Notes

- These endpoints are public (no JWT required) but protected by rate limiting
- The streaming endpoint handles binary image data differently from JSON endpoints
- VaporToOpenAPI may need explicit `.requestBody()` configuration for the streaming endpoint
- Rate limits mentioned in descriptions help developers understand usage constraints
- Production rate limits: 3/hour for image analysis, 10/hour for rules summary
