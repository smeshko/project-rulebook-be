---
type: feature
status: draft
priority: P1
created: 2025-12-24
slug: purchase-verification
feature_branch: feature/app-store-receipt-validation
linear_issues: RULE-128, RULE-129
linear_urls:
  - https://linear.app/project-rulebook/issue/RULE-128/implement-app-store-server-api-receipt-validation-endpoint
  - https://linear.app/project-rulebook/issue/RULE-129/implement-google-play-receipt-validation-endpoint
---

# Unified Purchase Verification Endpoint

## Overview

**Context**: iOS and Android clients need server-side verification of in-app purchases to ensure transaction authenticity and prevent receipt manipulation. Currently, there is no backend validation for purchases on either platform.

**Objective**: Implement a single unified purchase verification endpoint that accepts purchase tokens from both iOS (JWS) and Android (purchase tokens), routes to platform-specific validation services, and stores validated purchase records.

**Impact**: All mobile users making in-app purchases; backend services requiring purchase verification; subscription management flows.

## User Stories

**US-1**: As a mobile user, I want my in-app purchases validated on the server so that my purchases are securely verified and cannot be spoofed.
- **Given** I complete an in-app purchase on iOS or Android, **When** the app sends the token to the server, **Then** the server validates using the appropriate platform service and returns the verification result.

**US-2**: As a backend service, I want to query a user's validated purchases across platforms so that I can enforce entitlements and subscription access.
- **Given** a user has validated purchases from any platform, **When** I query the receipts repository, **Then** I receive accurate purchase state information including expiration dates.

**US-3**: As an API consumer, I want a single endpoint for all platforms so that client implementations are simpler and consistent.
- **Given** either iOS or Android app, **When** calling POST /api/purchases/verify with appropriate headers, **Then** the backend correctly routes to the platform-specific validation.

## Requirements

1. **REQ-001**: System SHALL accept purchase tokens via a single unified endpoint `POST /api/purchases/verify`
   - Rationale: Simplifies client integration and maintains consistent API surface

2. **REQ-002**: System SHALL identify platform from User-Agent header (iOS or Android)
   - Rationale: Standard HTTP pattern for platform identification; follows mobile API best practices

3. **REQ-003**: System SHALL validate iOS transactions using Apple App Store Server Library (JWS verification)
   - Rationale: Ensures transaction authenticity using Apple's official signing verification

4. **REQ-004**: System SHALL validate Android transactions using Google Play Developer API
   - Rationale: Google requires server-side API calls to verify purchase tokens

5. **REQ-005**: System SHALL support sandbox/test environments for both platforms
   - Rationale: Required for development testing and production deployments

6. **REQ-006**: System SHALL store validated transaction records linked to user accounts with platform identifier
   - Rationale: Enables cross-platform entitlement queries and subscription status checks

7. **REQ-007**: System SHALL return unified response format regardless of platform
   - Rationale: Clients receive consistent response structure

8. **REQ-008**: System SHALL require authentication for verification requests
   - Rationale: Transactions must be linked to authenticated user accounts

## Acceptance Criteria

### Functional
- [ ] **Given** iOS User-Agent and valid JWS, **When** POST /api/purchases/verify is called, **Then** returns verified=true with transaction details
- [ ] **Given** Android User-Agent and valid purchase token, **When** POST /api/purchases/verify is called, **Then** returns verified=true with transaction details
- [ ] **Given** invalid/tampered token for either platform, **When** verified, **Then** returns 400 with platform-appropriate error code
- [ ] **Given** unknown/missing platform in User-Agent, **When** verified, **Then** returns 400 with "unsupported_platform" error
- [ ] **Given** validated transaction from any platform, **When** stored, **Then** includes platform field (ios/android)

### Edge Cases
- [ ] Handles malformed tokens (returns 400, not 500)
- [ ] Handles network timeouts to Apple/Google services gracefully
- [ ] Handles duplicate validation requests idempotently
- [ ] Handles missing/invalid authentication (returns 401)
- [ ] Handles platform service outages with appropriate error response

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
- User-Agent header reliably contains platform identifier (iOS/Android)
- Existing JWT authentication middleware is compatible with this endpoint

## Open Questions
- [x] Single endpoint vs separate endpoints? → Single unified endpoint with platform routing
- [x] How to identify platform? → Parse User-Agent header for "iOS" or "Android"
- [x] Same request body for both platforms? → Yes, both send `purchaseToken` string field

---
**Next Steps**: Review requirements, proceed to research.md for technical patterns.
