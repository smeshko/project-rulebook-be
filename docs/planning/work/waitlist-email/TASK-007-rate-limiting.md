## TASK-007: Add Waitlist Rate Limiting

---
**Status:** OPEN
**Branch:** feature/waitlist-email
**Type:** IMPLEMENTATION
**Phase:** 1
**Depends On:** None
---

### Overview

Add waitlist-specific rate limiting to prevent spam abuse on the public signup endpoint. Configure moderate limits (10 requests/hour per IP).

**Files:**
- `Sources/App/Middlewares/Security/RateLimit/RateLimitTypes.swift` (modify)
- `Sources/App/Middlewares/Security/RateLimit/RateLimitMiddleware.swift` (modify)

### Implementation Steps

**Commit 1: Add waitlist rate limit type and path detection**
- [ ] Add `waitlist` case to `RateLimitType` enum with rawValue "waitlist"
- [ ] Add `waitlistLimit` and `waitlistWindow` properties to `RateLimitConfiguration` (if exists) or use inline values
- [ ] Add path detection for `/api/waitlist` in `determineRateLimit()` method
- [ ] Place path check BEFORE the general `/api/` catch-all

### Code Example

```swift
// Add to RateLimitTypes.swift:20-82
// Sources/App/Middlewares/Security/RateLimit/RateLimitTypes.swift

enum RateLimitType: String, CaseIterable {
    case imageAnalysis = "image_analysis"
    case rulesGeneration = "rules_generation"
    case admin = "admin"
    case api = "api"
    case general = "general"
    case waitlist = "waitlist"  // Add this case
}
```

```swift
// Add to RateLimitMiddleware.swift:167-211
// Sources/App/Middlewares/Security/RateLimit/RateLimitMiddleware.swift

private func determineRateLimit(for request: Request) -> RateLimitInfo {
    let path = request.url.path

    // AI-specific endpoints
    if path.contains("/api/rules-generation/game-box-analysis") {
        return RateLimitInfo(
            type: .imageAnalysis,
            maxRequests: configuration.imageAnalysisLimit,
            windowSeconds: configuration.imageAnalysisWindow
        )
    }

    if path.contains("/api/rules-generation/rules-summary") {
        return RateLimitInfo(
            type: .rulesGeneration,
            maxRequests: configuration.rulesGenerationLimit,
            windowSeconds: configuration.rulesGenerationWindow
        )
    }

    // Waitlist endpoint - ADD THIS BLOCK before admin/api
    if path.hasPrefix("/api/waitlist") {
        return RateLimitInfo(
            type: .waitlist,
            maxRequests: 10,  // 10 requests per hour
            windowSeconds: 3600  // 1 hour window
        )
    }

    // Admin endpoints
    if path.contains("/api/admin/") {
        return RateLimitInfo(
            type: .admin,
            maxRequests: configuration.adminLimit,
            windowSeconds: configuration.adminWindow
        )
    }

    // API endpoints (catch-all)
    if path.hasPrefix("/api/") {
        return RateLimitInfo(
            type: .api,
            maxRequests: configuration.apiLimit,
            windowSeconds: configuration.apiWindow
        )
    }

    // General web endpoints
    return RateLimitInfo(
        type: .general,
        maxRequests: configuration.generalLimit,
        windowSeconds: configuration.generalWindow
    )
}
```

### Success Criteria

- [ ] Build succeeds
- [ ] RateLimitType includes `waitlist` case
- [ ] `/api/waitlist` requests use waitlist-specific limits
- [ ] Path check is before general `/api/` catch-all

### Verification

```bash
swift build
```

### Notes

- 10 requests/hour is a reasonable limit for legitimate signups
- Must be placed BEFORE the `/api/` catch-all or it will never match
- Using inline values (10, 3600) for simplicity - can be moved to configuration later
- This protects against automated spam while allowing real users
