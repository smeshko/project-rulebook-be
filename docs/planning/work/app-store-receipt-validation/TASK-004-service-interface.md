## TASK-004: Create Purchase Validation Service Interface

---
**Status:** OPEN
**Branch:** feature/app-store-receipt-validation
**Type:** IMPLEMENTATION
**Phase:** 2
**Depends On:** TASK-003
---

### Overview

Create the unified purchase validation service protocol and result types that abstract over platform-specific implementations.

**Files:**
- `Sources/App/Services/Purchases/PurchaseValidationService.swift` (create)

### Implementation Steps

**Commit 1: feat(purchases): add PurchaseValidationService protocol and result types**
- [ ] Create `Sources/App/Services/Purchases/` directory
- [ ] Create `PurchaseValidationService` protocol
- [ ] Define `PurchaseValidationResult` struct for unified response
- [ ] Define `VerifyPurchaseRequest` for controller input

### Code Example

```swift
// Sources/App/Services/Purchases/PurchaseValidationService.swift
import Vapor

/// Unified result from purchase validation across all platforms
struct PurchaseValidationResult: Content, Sendable {
    let verified: Bool
    let platform: MobilePlatform
    let transactionId: String
    let originalTransactionId: String
    let productId: String
    let purchaseDate: Date
    let expiresDate: Date?
    let revocationDate: Date?
    let environment: String  // "sandbox" or "production"
}

/// Request body for purchase verification endpoint
struct VerifyPurchaseRequest: Content, Sendable {
    /// The purchase token/JWS from the mobile app
    let purchaseToken: String

    /// Product ID - required for Android, optional for iOS (embedded in JWS)
    let productId: String?
}

/// Unified purchase validation service that routes to platform-specific implementations
protocol PurchaseValidationService: Sendable {
    /// Validate an iOS App Store transaction (JWS format)
    func validateiOS(signedTransaction: String) async throws -> PurchaseValidationResult

    /// Validate an Android Google Play purchase
    func validateAndroid(productId: String, purchaseToken: String) async throws -> PurchaseValidationResult
}

/// Extension to handle platform routing
extension PurchaseValidationService {
    func validate(
        platform: MobilePlatform,
        request: VerifyPurchaseRequest
    ) async throws -> PurchaseValidationResult {
        switch platform {
        case .ios:
            return try await validateiOS(signedTransaction: request.purchaseToken)
        case .android:
            guard let productId = request.productId else {
                throw PurchaseValidationError.productIdRequired
            }
            return try await validateAndroid(productId: productId, purchaseToken: request.purchaseToken)
        }
    }
}
```

### Success Criteria

- [ ] Build succeeds
- [ ] Protocol and types compile
- [ ] Platform routing extension works

### Verification

```bash
swift build
```

### Notes

The extension provides a convenience method for platform routing used by the controller.
iOS JWS contains embedded productId, so it's optional in the request.
