# Epic 2: In-App Purchase Verification

Enable server-side validation of App Store and Play Store purchases to secure the credit-based monetization system. Users can purchase credits with confidence that their transactions are securely verified.

## Story 2.1: Create Receipts Module Foundation
**Linear:** [RULE-136](https://linear.app/project-rulebook/issue/RULE-136)

**As a** backend developer,
**I want** a Receipts module with database model and repository,
**So that** I can store validated transaction records.

**Acceptance Criteria:**

**Given** the project structure
**When** the Receipts module is created
**Then** it follows the established module pattern with:
- `ReceiptsModule.swift` for registration
- `ReceiptsRouter.swift` for route definitions
- `Controller/ReceiptsController.swift`
- `Models/Receipts+Model.swift` for request/response DTOs
- `Database/Models/TransactionModel.swift`
- `Database/Migrations/ReceiptsMigrations.swift`
- `Repositories/ReceiptsRepository.swift`

**Given** the TransactionModel
**When** a transaction is stored
**Then** it captures: `id`, `transactionId` (from store), `platform` (ios/android), `productId`, `creditAmount` (1, 3, or 10), `createdAt`

**Given** the repository
**When** checking for duplicate transactions
**Then** it can query by `transactionId` to enforce idempotency

---

## Story 2.2: Implement App Store Receipt Validation
**Linear:** [RULE-128](https://linear.app/project-rulebook/issue/RULE-128)

**As a** iOS app user,
**I want** my App Store purchases validated server-side,
**So that** my credits are securely verified.

**Acceptance Criteria:**

**Given** a valid App Store receipt
**When** the `AppStoreValidationService` validates it
**Then** it calls Apple's App Store Server API
**And** returns success with the product ID and transaction ID

**Given** an invalid or tampered receipt
**When** validation is attempted
**Then** the service returns failure with appropriate error

**Given** a previously validated transaction ID
**When** the same receipt is submitted again
**Then** validation succeeds but is marked as duplicate (idempotent)

**Given** the service configuration
**When** the service is initialized
**Then** it uses environment variables for Apple API credentials

---

## Story 2.3: Implement Play Store Receipt Validation
**Linear:** [RULE-129](https://linear.app/project-rulebook/issue/RULE-129)

**As an** Android app user,
**I want** my Play Store purchases validated server-side,
**So that** my credits are securely verified.

**Acceptance Criteria:**

**Given** a valid Play Store purchase token
**When** the `PlayStoreValidationService` validates it
**Then** it calls Google Play Developer API
**And** returns success with the product ID and transaction ID

**Given** an invalid or tampered purchase token
**When** validation is attempted
**Then** the service returns failure with appropriate error

**Given** a previously validated transaction ID
**When** the same purchase is submitted again
**Then** validation succeeds but is marked as duplicate (idempotent)

**Given** the service configuration
**When** the service is initialized
**Then** it uses environment variables for Google API credentials

---

## Story 2.4: Create Receipt Validation Endpoint
**Linear:** [RULE-137](https://linear.app/project-rulebook/issue/RULE-137)

**As a** mobile app,
**I want** a single endpoint to validate purchases,
**So that** I can verify transactions regardless of platform.

**Acceptance Criteria:**

**Given** a POST request to `/api/v1/receipts/validate`
**When** the request contains `{ "platform": "ios", "receiptData": "...", "productId": "..." }`
**Then** the App Store validation service is called
**And** success response `{ "success": true, "transactionId": "..." }` is returned

**Given** a POST request to `/api/v1/receipts/validate`
**When** the request contains `{ "platform": "android", "purchaseToken": "...", "productId": "..." }`
**Then** the Play Store validation service is called
**And** success response `{ "success": true, "transactionId": "..." }` is returned

**Given** a validation failure
**When** the receipt/token is invalid
**Then** response `{ "success": false, "error": "..." }` is returned with appropriate HTTP status

**Given** a successful validation
**When** the transaction is new (not duplicate)
**Then** the transaction is stored in the database

**Given** a valid product ID
**When** validating a purchase
**Then** the product maps to credit amounts: `credits_1` → 1, `credits_3` → 3, `credits_10` → 10

---
