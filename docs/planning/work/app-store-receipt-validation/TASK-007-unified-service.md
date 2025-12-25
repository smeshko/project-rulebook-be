## TASK-007: Create Unified Purchase Validator and Register Services

---
**Status:** OPEN
**Branch:** feature/app-store-receipt-validation
**Type:** IMPLEMENTATION
**Phase:** 2
**Depends On:** TASK-005, TASK-006
---

### Overview

Create the unified purchase validator that implements PurchaseValidationService and routes to platform-specific validators. Register services in the application container.

**Files:**
- `Sources/App/Services/Purchases/UnifiedPurchaseValidator.swift` (create)
- `Sources/App/Common/Extensions/Application+Services.swift` (modify)
- `Sources/App/Entrypoint/Application-Setup.swift` (modify)

### Implementation Steps

**Commit 1: feat(purchases): implement UnifiedPurchaseValidator**
- [ ] Create `UnifiedPurchaseValidator` implementing `PurchaseValidationService`
- [ ] Initialize with both platform validators
- [ ] Delegate to appropriate validator based on method called

**Commit 2: feat(purchases): register purchase validation service**
- [ ] Add `purchaseValidationService` to `ServiceStorageContainer`
- [ ] Add Application extension property
- [ ] Add RequestServices property
- [ ] Initialize service in `setupServices()`

### Code Example

```swift
// Sources/App/Services/Purchases/UnifiedPurchaseValidator.swift
import Vapor

final class UnifiedPurchaseValidator: PurchaseValidationService, @unchecked Sendable {
    private let appStoreValidator: AppStoreValidator
    private let googlePlayValidator: GooglePlayValidator

    init(
        appStoreConfig: AppStoreConfig,
        googlePlayConfig: GooglePlayConfig,
        httpClient: Client,
        logger: Logger
    ) throws {
        self.appStoreValidator = try AppStoreValidator(config: appStoreConfig, logger: logger)
        self.googlePlayValidator = GooglePlayValidator(
            config: googlePlayConfig,
            httpClient: httpClient,
            logger: logger
        )
    }

    func validateiOS(signedTransaction: String) async throws -> PurchaseValidationResult {
        try await appStoreValidator.validate(signedTransaction: signedTransaction)
    }

    func validateAndroid(productId: String, purchaseToken: String) async throws -> PurchaseValidationResult {
        try await googlePlayValidator.validate(productId: productId, purchaseToken: purchaseToken)
    }
}

// Application+Services.swift - Add to ServiceStorageContainer:
var purchaseValidationService: PurchaseValidationService?

// Application+Services.swift - Add to Application extension:
var purchaseValidationService: PurchaseValidationService {
    get { serviceStorage.purchaseValidationService! }
    set { serviceStorage.purchaseValidationService = newValue }
}

// Application+Services.swift - Add to RequestServices struct:
var purchaseValidator: PurchaseValidationService {
    app.purchaseValidationService
}

// Application-Setup.swift - Add to setupServices():
do {
    let appStoreConfig = try configuration.appStore
    let googlePlayConfig = try configuration.googlePlay
    purchaseValidationService = try UnifiedPurchaseValidator(
        appStoreConfig: appStoreConfig,
        googlePlayConfig: googlePlayConfig,
        httpClient: client,
        logger: logger
    )
    logger.info("Purchase validation service initialized")
} catch {
    logger.warning("Purchase validation service not configured: \(error)")
    // Service is optional - app can run without it
}
```

### Success Criteria

- [ ] Build succeeds
- [ ] UnifiedPurchaseValidator compiles
- [ ] Service accessible via req.services.purchaseValidator
- [ ] Service initializes at app startup (or logs warning if config missing)

### Verification

```bash
swift build
swift run &  # Verify startup logs
```

### Notes

Service initialization is wrapped in try-catch to allow the app to run even if purchase validation credentials are not configured. This is helpful for local development.
