## TASK-005: Implement iOS App Store Validator

---
**Status:** OPEN
**Branch:** feature/app-store-receipt-validation
**Type:** IMPLEMENTATION
**Phase:** 2
**Depends On:** TASK-004
---

### Overview

Implement the iOS App Store receipt validator using Apple's App Store Server Library SignedDataVerifier for JWS transaction verification.

**Files:**
- `Sources/App/Services/Purchases/AppStoreValidator.swift` (create)

### Implementation Steps

**Commit 1: feat(purchases): implement AppStoreValidator using SignedDataVerifier**
- [ ] Create `AppStoreValidator` struct
- [ ] Initialize SignedDataVerifier with App Store config
- [ ] Implement `validateiOS` method using verifyAndDecodeTransaction
- [ ] Map library results to PurchaseValidationResult
- [ ] Handle verification errors appropriately

### Code Example

```swift
// Sources/App/Services/Purchases/AppStoreValidator.swift
import Vapor
import AppStoreServerLibrary

struct AppStoreValidator: Sendable {
    private let verifier: SignedDataVerifier
    private let logger: Logger

    init(config: AppStoreConfig, logger: Logger) throws {
        let environment: AppStoreServerLibrary.Environment = config.environment == .sandbox
            ? .sandbox
            : .production

        self.verifier = try SignedDataVerifier(
            rootCertificates: [],  // Library fetches Apple root certs automatically
            bundleId: config.bundleId,
            appAppleId: config.appAppleId,
            environment: environment,
            enableOnlineChecks: true
        )
        self.logger = logger
    }

    func validate(signedTransaction: String) async throws -> PurchaseValidationResult {
        logger.info("Validating iOS App Store transaction")

        let result = await verifier.verifyAndDecodeTransaction(signedTransaction: signedTransaction)

        switch result {
        case .valid(let transaction):
            logger.info("iOS transaction verified successfully",
                metadata: ["transactionId": "\(transaction.transactionId)"])

            return PurchaseValidationResult(
                verified: true,
                platform: .ios,
                transactionId: transaction.transactionId,
                originalTransactionId: transaction.originalTransactionId,
                productId: transaction.productId,
                purchaseDate: transaction.purchaseDate,
                expiresDate: transaction.expiresDate,
                revocationDate: transaction.revocationDate,
                environment: transaction.environment.rawValue
            )

        case .invalid(let error):
            logger.warning("iOS transaction validation failed",
                metadata: ["error": "\(error)"])

            switch error {
            case .invalidAppIdentifier:
                throw PurchaseValidationError.bundleMismatch
            case .invalidSignature:
                throw PurchaseValidationError.invalidSignature
            default:
                throw PurchaseValidationError.verificationFailed
            }
        }
    }
}
```

### Success Criteria

- [ ] Build succeeds
- [ ] SignedDataVerifier initializes without errors
- [ ] Validation maps to correct result types
- [ ] Errors are properly categorized

### Verification

```bash
swift build
```

### Notes

SignedDataVerifier handles:
- JWKS fetching and caching
- Certificate chain validation
- Signature verification
- Transaction data decoding

No external API calls for basic JWS validation.
