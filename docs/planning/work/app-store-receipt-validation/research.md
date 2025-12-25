# Research: Unified Purchase Verification

---
**Date:** 2025-12-24
**Updated:** 2025-12-25
**Requirements:** `docs/planning/work/app-store-receipt-validation/requirements.md`
**Linear:** [RULE-128](https://linear.app/project-rulebook/issue/RULE-128), [RULE-129](https://linear.app/project-rulebook/issue/RULE-129)
**Status:** complete
**Purchase Type:** Consumables (credits) - device-based, no user auth
---

## Platform Detection

**Stack:** Swift 6.0 / Vapor 4.110.1
**Version:** macOS 15+, Swift 6.0
**Build:** Swift Package Manager (SPM)

## Dependencies

| Dependency | Version | Purpose | Status |
|------------|---------|---------|--------|
| vapor | 4.110.1 | Web framework | existing |
| fluent | 4.12.0 | ORM/Database | existing |
| jwt | 4.0.0 | JWT handling | existing |
| redis | 4.0.0 | Caching | existing |
| app-store-server-library-swift | 4.0.0 | Apple receipt validation | **new** |
| google-auth-library-swift | - | Google OAuth (if available) | **new** (or manual implementation) |

## Codebase Patterns

### Architecture
- **Pattern:** Modular service-oriented architecture
  - Location: `Sources/App/Modules/` - each module self-contained
  - Usage: Modules register routes via `boot()`, post-init via `setUp()`

### Conventions
- **State:** Service injection via Application storage - `Application+Services.swift:8-143`
- **Errors:** Enum-based with `IdentifiableError` protocol - `UserError.swift:3-25`
- **Async:** async/await throughout - `RulesGenerationController.swift:110-156`
- **Naming:** Files: PascalCase, Types: PascalCase, Functions: camelCase

### Platform & Device Identification

**Device-Based Architecture:**
Purchases are tracked by device identifier (client-generated UUID) rather than user accounts. This is appropriate for consumable purchases (credits) that:
- Don't need to be restored across devices
- Don't require user authentication
- Are tied to the device where purchased

**Request Body Structure:**
```swift
struct ValidateRequest: Content {
    let deviceId: String       // Client-generated UUID, persisted on device
    let platform: PurchasePlatform  // .ios or .android
    let receiptData: String    // JWS for iOS, token for Android
    let productId: String?     // Required for Android, optional for iOS
}
```

**Platform Enum:**
```swift
public enum PurchasePlatform: String, Codable, Sendable {
    case ios
    case android
}
```

### Code Examples

#### Service Storage Pattern
```swift
// Application+Services.swift:8-33
final class ServiceStorageContainer: @unchecked Sendable {
    var llmService: LLMService?
    var emailService: EmailService?
    // Add: var purchaseValidationService: PurchaseValidationService?
}
```

#### Configuration Type Pattern
```swift
// ConfigurationTypes.swift:137-183
// iOS Configuration
struct AppStoreConfig: Sendable {
    let privateKey: String
    let keyId: String
    let issuerId: String
    let bundleId: String
    let appAppleId: Int64
    let environment: Environment

    enum Environment: String, Sendable {
        case sandbox, production
    }
}

// Android Configuration
struct GooglePlayConfig: Sendable {
    let packageName: String
    let serviceAccountJson: String  // Full JSON content of service account
}
```

#### Controller Pattern (Device-Based, No Auth)
```swift
// Pattern for unified endpoint with device-based identification
func validate(_ req: Request) async throws -> Purchases.Validate.Response {
    let input = try req.content.decode(Purchases.Validate.Request.self)
    let deviceId = input.deviceId

    // Validate with platform-specific validator
    let transaction = try await req.services.purchaseValidator.validate(
        platform: input.platform,
        receiptData: input.receiptData,
        productId: input.productId
    )

    // Check for duplicate (idempotent)
    if try await req.repositories.receipts.exists(
        transactionId: transaction.transactionId,
        platform: transaction.platform
    ) {
        return Purchases.Validate.Response(
            success: true,
            transactionId: transaction.transactionId,
            productId: transaction.productId,
            status: transaction.status.rawValue,
            isDuplicate: true
        )
    }

    // Store with deviceId (not userId)
    let receipt = ReceiptModel(from: transaction, deviceId: deviceId)
    try await req.repositories.receipts.create(receipt)

    return Purchases.Validate.Response(...)
}
```

### Google Play API Verification

**API Endpoint:**
```
GET https://androidpublisher.googleapis.com/androidpublisher/v3/applications/{packageName}/purchases/products/{productId}/tokens/{token}
```

**OAuth Flow:**
1. Load service account JSON
2. Generate JWT with claims for Google API scope
3. Exchange JWT for access token
4. Use access token in Authorization header

**Implementation Pattern:**
```swift
struct GooglePlayValidator {
    let config: GooglePlayConfig
    let httpClient: Client

    func validate(productId: String, purchaseToken: String) async throws -> GooglePlayPurchase {
        let accessToken = try await getAccessToken()

        let url = "https://androidpublisher.googleapis.com/androidpublisher/v3/applications/\(config.packageName)/purchases/products/\(productId)/tokens/\(purchaseToken)"

        let response = try await httpClient.get(URI(string: url), headers: [
            "Authorization": "Bearer \(accessToken)"
        ])

        return try response.content.decode(GooglePlayPurchase.self)
    }
}
```

## Integration Points

| Component | Location | Change | Impact |
|-----------|----------|--------|--------|
| Package.swift | `:24` | Add app-store-server-library-swift | New dependency |
| ConfigurationTypes.swift | `:183+` | Add AppStoreConfig, GooglePlayConfig | Config layer |
| ConfigurationService.swift | `:89+` | Add appStore, googlePlay properties | Config interface |
| ProductionConfiguration.swift | `:259+` | Implement config parsing | Config impl |
| Application+Services.swift | `:23, 115, 66` | Add unified service storage | Service layer |
| Application-Setup.swift | `:182, 82` | Init services + register module | Startup |

**Flow:**
```
Mobile App → POST /api/v1/purchases/validate
    → PurchasesController.validate (no auth required)
    → Parse platform from request body
    → Route to iOS or Android validator
    → Check duplicate by transactionId
    → Store in ReceiptModel with deviceId
    → Return unified response
```

## Clarifications & Decisions

### Unified vs Separate Endpoints
**Question:** Should iOS and Android have separate endpoints?
**Finding:** Single endpoint simplifies client integration
**Decision:** Use single `POST /api/v1/purchases/validate` with platform in request body
**Rationale:** Industry best practice; cleaner API surface; easier client maintenance

### Request Body Structure
**Question:** Different request bodies for iOS vs Android?
**Finding:**
- iOS sends JWS string (self-contained signed transaction)
- Android sends productId + purchaseToken
**Decision:** Use unified request body with deviceId, platform, and optional productId:
```swift
struct ValidateRequest: Content {
    let deviceId: String       // Required - client-generated UUID
    let platform: PurchasePlatform  // Required - ios or android
    let receiptData: String    // Required - JWS for iOS, token for Android
    let productId: String?     // Required for Android, optional for iOS
}
```
**Rationale:** Explicit platform field avoids User-Agent parsing; deviceId enables tracking without user auth

### Device-Based vs User-Based
**Question:** Should purchases be linked to user accounts?
**Finding:** For consumables (credits), device-based tracking is simpler and doesn't require user auth
**Decision:** Use deviceId (client-generated UUID) instead of userId
**Rationale:**
- Consumables don't need cross-device restore (Apple/Google don't restore them)
- No user account required to make purchases
- Simpler implementation; follows RevenueCat anonymous user pattern

## Risks & Unknowns

**Risks:**
1. Apple API changes - Mitigation: Use official library v4.0.0
2. Google OAuth token management - Mitigation: Implement proper caching with refresh
3. User-Agent spoofing - Mitigation: Token format validates platform anyway

**Unknowns:**
- [x] Swift Google Auth library availability - May need manual JWT implementation

## Summary

**Key Findings:**
1. Single unified endpoint is cleaner and follows mobile API best practices
2. User-Agent header parsing is standard for platform detection
3. iOS uses local JWS validation; Android requires Google API call
4. Response format can be unified across platforms

**Confidence:** High
- Clear patterns to follow
- Well-documented libraries and APIs
- No significant unknowns

**Next Steps:**
1. Add dependencies to Package.swift
2. Create configuration types for both platforms
3. Implement platform-specific validators
4. Create unified service that routes by platform
5. Create module with single endpoint

---
**Ready for Planning:** Yes

## Sources

- [User-Agent for API calls - Brains & Beards](https://brainsandbeards.com/blog/2025-useragent-for-api-calls/)
- [User-Agent header - MDN](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/User-Agent)
- [REST API Best Practices - Postman](https://blog.postman.com/rest-api-best-practices/)
- [Designing REST APIs for Mobile - Zuplo](https://zuplo.com/learning-center/designing-rest-apis-for-mobile-applications-best-practices)
