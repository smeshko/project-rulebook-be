---
type: feature
status: complete
priority: P1
created: 2025-12-24
updated: 2025-12-25
slug: purchase-verification
feature_branch: feature/app-store-receipt-validation
linear_issues: RULE-128, RULE-129
linear_urls:
  - https://linear.app/project-rulebook/issue/RULE-128/implement-app-store-server-api-receipt-validation-endpoint
  - https://linear.app/project-rulebook/issue/RULE-129/implement-google-play-receipt-validation-endpoint
---

# Unified Purchase Verification Endpoint

## Overview

**Context**: iOS and Android clients need server-side verification of in-app purchases (consumable credits) to ensure transaction authenticity and prevent receipt manipulation. Currently, there is no backend validation for purchases on either platform.

**Objective**: Implement a single unified purchase verification endpoint that accepts purchase tokens from both iOS (JWS) and Android (purchase tokens), routes to platform-specific validation services, and stores validated purchase records linked to device identifiers.

**Impact**: All mobile users making in-app purchases; backend services requiring purchase verification.

**Purchase Type**: Consumables only (credits). No subscription management required.

## User Stories

**US-1**: As a mobile user, I want my in-app purchases validated on the server so that my purchases are securely verified and cannot be spoofed.
- **Given** I complete an in-app purchase on iOS or Android, **When** the app sends the token and device ID to the server, **Then** the server validates using the appropriate platform service and returns the verification result.

**US-2**: As a backend service, I want to query a device's validated purchases so that I can enforce entitlements.
- **Given** a device has validated purchases, **When** I query the receipts repository by device ID, **Then** I receive accurate purchase state information.

**US-3**: As an API consumer, I want a single endpoint for all platforms so that client implementations are simpler and consistent.
- **Given** either iOS or Android app, **When** calling POST /api/v1/purchases/validate with device ID and platform in request body, **Then** the backend correctly routes to the platform-specific validation.

## Requirements

1. **REQ-001**: System SHALL accept purchase tokens via a single unified endpoint `POST /api/v1/purchases/validate`
   - Rationale: Simplifies client integration and maintains consistent API surface

2. **REQ-002**: System SHALL identify platform from request body `platform` field (ios or android)
   - Rationale: Explicit platform identification in request body; no reliance on User-Agent parsing

3. **REQ-003**: System SHALL validate iOS transactions using Apple App Store Server Library (JWS verification)
   - Rationale: Ensures transaction authenticity using Apple's official signing verification

4. **REQ-004**: System SHALL validate Android transactions using Google Play Developer API
   - Rationale: Google requires server-side API calls to verify purchase tokens

5. **REQ-005**: System SHALL support sandbox/test environments for both platforms
   - Rationale: Required for development testing and production deployments

6. **REQ-006**: System SHALL store validated transaction records linked to device identifiers with platform field
   - Rationale: Enables device-based entitlement queries; no user authentication required

7. **REQ-007**: System SHALL return unified response format regardless of platform
   - Rationale: Clients receive consistent response structure

8. **REQ-008**: System SHALL NOT require user authentication for verification requests
   - Rationale: Consumable purchases are device-based; users may not have accounts

## Acceptance Criteria

### Functional
- [x] **Given** platform=ios and valid JWS, **When** POST /api/v1/purchases/validate is called, **Then** returns success=true with transaction details
- [x] **Given** platform=android and valid purchase token, **When** POST /api/v1/purchases/validate is called, **Then** returns success=true with transaction details
- [x] **Given** invalid/tampered token for either platform, **When** verified, **Then** returns 400 with platform-appropriate error code
- [x] **Given** missing platform in request body, **When** verified, **Then** returns 400 with validation error
- [x] **Given** validated transaction from any platform, **When** stored, **Then** includes platform field and device_id

### Edge Cases
- [x] Handles malformed tokens (returns 400, not 500)
- [x] Handles network timeouts to Apple/Google services gracefully
- [x] Handles duplicate validation requests idempotently (returns isDuplicate: true)
- [x] Works without user authentication (device-based)
- [x] Handles platform service outages with appropriate error response

## Affected Areas

**Components**:
- ConfigurationService - Add App Store and Google Play API credentials
- ServiceStorageContainer - Register platform validation services
- Request+Services - Expose unified purchase validator to controllers

**Files**:
- `Sources/App/Services/Configuration/ConfigurationTypes.swift` - Add AppStoreConfig, GooglePlayConfig
- `Sources/App/Services/Configuration/ProductionConfiguration.swift` - Parse environment variables
- `Sources/App/Common/Extensions/Application+Services.swift` - Service registration
- `Sources/App/Entrypoint/Application-Setup.swift` - Service initialization
- `Package.swift` - Add App Store Server Library dependency

## Assumptions
- Apple App Store Server Library v4.0.0 is stable and production-ready
- Google Play Developer API credentials are available with appropriate permissions
- Client apps generate and persist a unique device UUID for identification
- Consumable purchases do not need to be restored across devices

## Open Questions
- [x] Single endpoint vs separate endpoints? → Single unified endpoint with platform routing
- [x] How to identify platform? → Platform field in request body (not User-Agent)
- [x] Same request body for both platforms? → Yes, with deviceId, platform, receiptData, and optional productId
- [x] User authentication required? → No, device-based identification only
- [x] What purchase types? → Consumables only (credits)

---
**Status**: Complete - Implementation merged to feature branch
