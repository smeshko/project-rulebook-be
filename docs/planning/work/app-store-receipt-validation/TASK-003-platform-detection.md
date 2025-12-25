## TASK-003: Create Platform Detection and Error Types

---
**Status:** OPEN
**Branch:** feature/app-store-receipt-validation
**Type:** IMPLEMENTATION
**Phase:** 1
**Depends On:** TASK-002
---

### Overview

Create the MobilePlatform enum for detecting iOS/Android from User-Agent header, and PurchaseValidationError for error handling.

**Files:**
- `Sources/App/Entities/Types/MobilePlatform.swift` (create)
- `Sources/App/Entities/Errors/PurchaseValidationError.swift` (create)

### Implementation Steps

**Commit 1: feat(purchases): add MobilePlatform enum and PurchaseValidationError**
- [ ] Create `Sources/App/Entities/Types/` directory if needed
- [ ] Create `MobilePlatform` enum with iOS/Android cases
- [ ] Add static `detect(from:)` method for User-Agent parsing
- [ ] Create `PurchaseValidationError` enum following existing error pattern

### Code Example

```swift
// Sources/App/Entities/Types/MobilePlatform.swift
import Vapor

enum MobilePlatform: String, Sendable, Content {
    case ios
    case android

    /// Detect platform from User-Agent header value
    /// Looks for "iOS", "iPhone", "iPad" for iOS or "Android" for Android
    static func detect(from userAgent: String?) -> MobilePlatform? {
        guard let ua = userAgent?.lowercased() else { return nil }
        if ua.contains("ios") || ua.contains("iphone") || ua.contains("ipad") {
            return .ios
        }
        if ua.contains("android") {
            return .android
        }
        return nil
    }
}

// Sources/App/Entities/Errors/PurchaseValidationError.swift
import Vapor

public enum PurchaseValidationError: String, IdentifiableError {
    case unsupportedPlatform = "unsupported_platform"
    case invalidSignature = "invalid_signature"
    case invalidToken = "invalid_token"
    case invalidTransaction = "invalid_transaction"
    case bundleMismatch = "bundle_mismatch"
    case productIdRequired = "product_id_required"
    case verificationFailed = "verification_failed"
    case networkError = "network_error"

    public var identifier: String { rawValue }

    public var reason: String {
        switch self {
        case .unsupportedPlatform:
            return "Platform not supported. User-Agent must indicate iOS or Android."
        case .invalidSignature:
            return "Transaction signature verification failed"
        case .invalidToken:
            return "Purchase token is invalid or expired"
        case .invalidTransaction:
            return "Transaction data is malformed or invalid"
        case .bundleMismatch:
            return "App bundle/package ID does not match configured app"
        case .productIdRequired:
            return "Product ID is required for Android purchases"
        case .verificationFailed:
            return "Transaction verification failed"
        case .networkError:
            return "Unable to reach verification service"
        }
    }
}
```

### Success Criteria

- [ ] Build succeeds
- [ ] MobilePlatform correctly parses User-Agent strings
- [ ] PurchaseValidationError follows IdentifiableError pattern

### Verification

```bash
swift build
```

### Notes

Platform detection follows best practices from:
- [Brains & Beards - User-Agent for API calls](https://brainsandbeards.com/blog/2025-useragent-for-api-calls/)
- [MDN - User-Agent header](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/User-Agent)
