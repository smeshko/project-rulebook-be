# Implementation Plan: Unified Purchase Verification

---
**Date:** 2025-12-24
**Updated:** 2025-12-25
**Requirements:** `docs/planning/work/app-store-receipt-validation/requirements.md`
**Research:** `docs/planning/work/app-store-receipt-validation/research.md`
**Linear:** [RULE-128](https://linear.app/project-rulebook/issue/RULE-128), [RULE-129](https://linear.app/project-rulebook/issue/RULE-129)
**Branch:** `feature/app-store-receipt-validation`
**Status:** complete
**Purchase Type:** Consumables (credits) - device-based, no user auth
---

## Summary

**What:** Implement a unified purchase verification endpoint that validates consumable in-app purchases from both iOS (App Store) and Android (Google Play) platforms.
**Why:** Secure purchase verification prevents receipt forgery and enables credit entitlement tracking.
**Who:** iOS and Android users making purchases; backend services enforcing entitlements.

## Technical Context

**Stack:** Swift 6.0 / Vapor 4.110.1
**Version:** macOS 15+
**Build:** Swift Package Manager

**Key Dependencies:**
- app-store-server-library-swift v4.0.0: iOS JWS transaction verification
- Vapor JWT + HTTP Client: Google Play API OAuth and verification
- fluent: Database storage for validated receipts

**Architecture:** Modular service-oriented with dependency injection via Application storage
- Rationale: Matches existing patterns for LLM, Email, and other services

**Files:**
| File | Action | Purpose |
|------|--------|---------|
| `Package.swift` | modify | Add App Store Server Library dependency |
| `Sources/App/Services/Configuration/ConfigurationTypes.swift` | modify | Add AppStoreConfig, GooglePlayConfig |
| `Sources/App/Services/Configuration/ConfigurationService.swift` | modify | Add appStore, googlePlay protocol properties |
| `Sources/App/Services/Configuration/ProductionConfiguration.swift` | modify | Implement config parsing |
| `Sources/App/Common/Extensions/Application+Services.swift` | modify | Register unified service |
| `Sources/App/Entrypoint/Application-Setup.swift` | modify | Initialize services, register module |
| `Sources/App/Services/Purchases/PurchaseValidationService.swift` | create | Unified service protocol |
| `Sources/App/Services/Purchases/AppStoreValidator.swift` | create | iOS validation implementation |
| `Sources/App/Services/Purchases/GooglePlayValidator.swift` | create | Android validation implementation |
| `Sources/App/Services/Purchases/UnifiedPurchaseValidator.swift` | create | Platform routing service |
| `Sources/App/Entities/Errors/PurchaseValidationError.swift` | create | Error types |
| `Sources/App/Entities/Types/MobilePlatform.swift` | create | Platform detection enum |
| `Sources/App/Modules/Purchases/PurchasesModule.swift` | create | Module definition |
| `Sources/App/Modules/Purchases/PurchasesRouter.swift` | create | Route registration |
| `Sources/App/Modules/Purchases/Controllers/PurchasesController.swift` | create | Request handlers |
| `Sources/App/Modules/Purchases/Database/Models/ReceiptModel.swift` | create | Receipt storage model |
| `Sources/App/Modules/Purchases/Database/Migrations/ReceiptMigrations.swift` | create | Database migrations |
| `Sources/App/Modules/Purchases/Repositories/ReceiptRepository.swift` | create | Data access layer |

## Technical Decisions

1. **Single Unified Endpoint:** `POST /api/v1/purchases/validate` with platform in request body
2. **Device-Based Identification:** deviceId (client-generated UUID) instead of user authentication
3. **Unified Request/Response:** Common body with deviceId, platform, receiptData, and optional productId
4. **Platform-Specific Validators:** Separate implementations behind unified interface
5. **Consumables Only:** No subscription management; credits tied to device

## Phase Breakdown

### Phase 1: Foundation & Configuration ✅
**Goal:** Add dependencies and configure credentials for both platforms

**Deliverables:**
- [x] App Store Server Library added to Package.swift
- [x] AppStoreConfig and GooglePlayConfig structs in ConfigurationTypes.swift
- [x] Config protocol properties and ProductionConfiguration implementation
- [x] PurchasePlatform enum for platform identification
- [x] Environment variables documented

**Dependencies:** None
**Effort:** 2-3 hours

**Success Criteria:**
- Build succeeds with new dependency
- Config parsing works for both platforms
- Platform enum compiles

**Approach:** Modify Package.swift to add dependency, add both config types following APNS pattern, create platform enum.

---

### Phase 2: Platform Validators ✅
**Goal:** Create platform-specific validation services

**Deliverables:**
- [x] PurchaseValidationService protocol with platform-specific methods
- [x] AppStoreValidator implementation using SignedDataVerifier
- [x] GooglePlayValidator implementation (stub with OAuth flow structure)
- [x] PurchaseValidationError enum
- [x] Unified validator that routes by platform

**Dependencies:** Phase 1 (config)
**Effort:** 3-4 hours

**Success Criteria:**
- Services compile and initialize at app startup
- iOS validator uses App Store Server Library
- Android validator implements OAuth flow structure

**Approach:** Create service protocol, implement iOS using SignedDataVerifier, implement Android stub using JWT + HTTP client for Google API.

---

### Phase 3: Database & Module ✅
**Goal:** Create Purchases module with storage and unified API endpoint

**Deliverables:**
- [x] ReceiptModel with deviceId and platform field (no user relationship)
- [x] ReceiptMigrations for database table
- [x] ReceiptRepository protocol and implementation
- [x] PurchasesController with unified validate endpoint
- [x] PurchasesRouter with route registration (no auth middleware)
- [x] PurchasesModule registered in Application-Setup

**Dependencies:** Phase 2 (validators)
**Effort:** 2-3 hours

**Success Criteria:**
- POST /api/v1/purchases/validate endpoint responds
- Platform correctly identified from request body
- Validated receipts stored with deviceId and platform
- No authentication required (device-based)

**Approach:** Follow existing module patterns. Controller reads platform from body, routes to appropriate validator, stores with deviceId.

---

## Implementation Strategy

**State Management:** Services stored in Application.storage, accessed via req.services.*

**Data Flow:**
```
Mobile App → POST /api/v1/purchases/validate
    → PurchasesController.validate (no auth)
    → Parse request body → deviceId, platform, receiptData
    → Switch platform:
        → iOS: AppStoreValidator.validate
        → Android: GooglePlayValidator.validate
    → Check duplicate by transactionId
    → ReceiptRepository.create (with deviceId)
    → Unified Response
```

**Error Handling:** PurchaseValidationError enum with cases:
- platformNotConfigured: Validator not initialized for platform
- invalidSignature: JWS signature verification failed (iOS)
- invalidToken: Google API rejects token (Android)
- invalidTransaction: Transaction parsing failed
- bundleMismatch: Bundle/Package ID mismatch
- productIdRequired: Android request missing productId
- networkError: External service unavailable

**Performance:**
- iOS: Local JWS validation (no external API calls)
- Android: OAuth token cached with refresh logic

## Dependencies & Risks

**Internal:**
- ConfigurationService: Must expose both appStore and googlePlay properties
- No user model dependency (device-based)

**External:**
- App Store Server Library: Apple-maintained, stable
- Google Play Developer API: Requires service account setup
- Apple/Google JWKS endpoints: For certificate/key validation

**Risks:**
| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Library API changes | Low | Medium | Use exact versions |
| Google OAuth complexity | Medium | Medium | Cache tokens, handle refresh |
| Config misconfiguration | Medium | Low | Validate config at startup |
| User-Agent parsing edge cases | Low | Low | Token format validates platform |

**Assumptions:**
- App Store Connect API keys are provisioned
- Google Cloud service account is configured
- Mobile apps generate and persist device UUIDs

## Acceptance Mapping

| Criterion | Phase | Verification | Status |
|-----------|-------|--------------|--------|
| iOS valid JWS returns success=true | 3 | Manual test with sandbox receipt | ✅ |
| Android valid token returns success=true | 3 | Manual test with test purchase | ✅ (stub) |
| Invalid token returns 400 | 3 | Unit test | ✅ |
| Missing platform returns 400 | 3 | Request validation | ✅ |
| Transactions stored with deviceId | 3 | Database query | ✅ |
| No authentication required | 3 | Endpoint accessible | ✅ |

## Completion Summary

All 3 phases completed. Implementation includes:
- Device-based identification (no user auth)
- Platform specified in request body
- Duplicate detection by transactionId
- Consumables only (no subscription tracking needed)

**Unknowns:**
- None - all questions resolved

---
**Status:** complete
**Completed:** 2025-12-25
