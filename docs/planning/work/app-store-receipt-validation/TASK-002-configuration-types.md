## TASK-002: Add Platform Configuration Types

---
**Status:** OPEN
**Branch:** feature/app-store-receipt-validation
**Type:** IMPLEMENTATION
**Phase:** 1
**Depends On:** TASK-001
---

### Overview

Add configuration types for both iOS (App Store) and Android (Google Play) platforms following existing APNS config pattern.

**Files:**
- `Sources/App/Services/Configuration/ConfigurationTypes.swift`
- `Sources/App/Services/Configuration/ConfigurationService.swift`
- `Sources/App/Services/Configuration/ProductionConfiguration.swift`

### Implementation Steps

**Commit 1: feat(config): add AppStoreConfig and GooglePlayConfig types**
- [ ] Add `AppStoreConfig` struct with environment enum
- [ ] Add `GooglePlayConfig` struct for Google Play credentials
- [ ] Add `appStore` property to ConfigurationService protocol
- [ ] Add `googlePlay` property to ConfigurationService protocol
- [ ] Implement both properties in ProductionConfiguration

### Code Example

```swift
// ConfigurationTypes.swift - Add after APNSConfig

struct AppStoreConfig: Sendable {
    let privateKey: String        // .p8 file content
    let keyId: String             // Key ID from App Store Connect
    let issuerId: String          // Issuer ID from App Store Connect
    let bundleId: String          // App bundle identifier
    let appAppleId: Int64         // Numeric App ID
    let environment: Environment

    enum Environment: String, Sendable {
        case sandbox
        case production
    }
}

struct GooglePlayConfig: Sendable {
    let packageName: String           // Android app package name
    let serviceAccountJson: String    // Full JSON content of service account
}

// ConfigurationService.swift - Add to protocol
var appStore: AppStoreConfig { get throws }
var googlePlay: GooglePlayConfig { get throws }

// ProductionConfiguration.swift - Add implementations
var appStore: AppStoreConfig {
    get throws {
        guard let privateKey = Environment.get("APP_STORE_PRIVATE_KEY") else {
            throw ConfigurationError.missingRequired(
                key: "APP_STORE_PRIVATE_KEY",
                reason: "Required for App Store receipt validation"
            )
        }
        guard let keyId = Environment.get("APP_STORE_KEY_ID") else {
            throw ConfigurationError.missingRequired(
                key: "APP_STORE_KEY_ID",
                reason: "Required for App Store receipt validation"
            )
        }
        guard let issuerId = Environment.get("APP_STORE_ISSUER_ID") else {
            throw ConfigurationError.missingRequired(
                key: "APP_STORE_ISSUER_ID",
                reason: "Required for App Store receipt validation"
            )
        }
        guard let bundleId = Environment.get("APP_STORE_BUNDLE_ID") else {
            throw ConfigurationError.missingRequired(
                key: "APP_STORE_BUNDLE_ID",
                reason: "Required for App Store receipt validation"
            )
        }
        guard let appIdString = Environment.get("APP_STORE_APP_ID"),
              let appAppleId = Int64(appIdString) else {
            throw ConfigurationError.missingRequired(
                key: "APP_STORE_APP_ID",
                reason: "Required for App Store receipt validation (numeric)"
            )
        }
        let envString = Environment.get("APP_STORE_ENVIRONMENT") ?? "production"
        let environment = AppStoreConfig.Environment(rawValue: envString) ?? .production

        return AppStoreConfig(
            privateKey: privateKey,
            keyId: keyId,
            issuerId: issuerId,
            bundleId: bundleId,
            appAppleId: appAppleId,
            environment: environment
        )
    }
}

var googlePlay: GooglePlayConfig {
    get throws {
        guard let packageName = Environment.get("GOOGLE_PLAY_PACKAGE_NAME") else {
            throw ConfigurationError.missingRequired(
                key: "GOOGLE_PLAY_PACKAGE_NAME",
                reason: "Required for Google Play receipt validation"
            )
        }
        guard let serviceAccountJson = Environment.get("GOOGLE_PLAY_SERVICE_ACCOUNT_JSON") else {
            throw ConfigurationError.missingRequired(
                key: "GOOGLE_PLAY_SERVICE_ACCOUNT_JSON",
                reason: "Required for Google Play receipt validation"
            )
        }
        return GooglePlayConfig(
            packageName: packageName,
            serviceAccountJson: serviceAccountJson
        )
    }
}
```

### Success Criteria

- [ ] Build succeeds
- [ ] Both config types compile
- [ ] Protocol properties added

### Verification

```bash
swift build
```

### Notes

Environment variables needed:

**iOS:**
- `APP_STORE_PRIVATE_KEY` - Content of .p8 file
- `APP_STORE_KEY_ID` - Key ID from App Store Connect
- `APP_STORE_ISSUER_ID` - Issuer ID from App Store Connect
- `APP_STORE_BUNDLE_ID` - App bundle identifier
- `APP_STORE_APP_ID` - Numeric App Apple ID
- `APP_STORE_ENVIRONMENT` - "sandbox" or "production"

**Android:**
- `GOOGLE_PLAY_PACKAGE_NAME` - Android app package name
- `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` - Full service account JSON
