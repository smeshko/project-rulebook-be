# PRD: Server-Side Receipt Validation

**Author:** John (PM)
**Date:** 2026-03-04
**Status:** Draft
**Priority:** High — should follow Epic 3 completion

---

## Executive Summary

### Problem

All API endpoints (`game-box-analysis`, `rules-summary`, `config`) are currently unauthenticated. Purchase verification happens entirely on-device using StoreKit 2's client-side signature checks, and credit balances are stored locally. This means:

- Anyone who discovers the API URLs can call them freely
- A jailbroken device can fake transactions and grant itself unlimited credits
- Refunded purchases are never detected — credits persist
- Transaction records can be wiped by reinstalling the app

### Solution

Move purchase validation to the server by forwarding StoreKit 2 transaction data to a backend endpoint that verifies directly with Apple's App Store Server API. The server becomes the **single source of truth** for whether a purchase is legitimate, and issues credits only after Apple confirms.

### What This Is NOT

- Not a user authentication system (no accounts, no login)
- Not JWT or session tokens (that's a future layer)
- Not DeviceCheck or App Attest (that's a future hardening layer)
- Not a full server-side credit ledger (credits remain on-device for now)

---

## Success Criteria

| Metric | Target |
|--------|--------|
| No purchase grants credits without Apple server confirmation | 100% |
| Duplicate transaction ID reuse rejected | 100% |
| Refunded transactions detected and flagged | Within 5 minutes of Apple notification |
| API latency increase from validation round-trip | < 2 seconds |
| Offline purchase recovery (validate when back online) | 100% of queued transactions |

---

## Functional Requirements

### FR1: Transaction Validation Endpoint

| ID | Requirement |
|----|-------------|
| FR1.1 | Backend exposes `POST /api/v1/receipts/validate` endpoint |
| FR1.2 | Accepts StoreKit 2 signed transaction data (JWS format) |
| FR1.3 | Forwards transaction to Apple App Store Server API for verification |
| FR1.4 | Returns validation result: `valid`, `invalid`, `already_processed` |
| FR1.5 | Stores transaction ID + receipt hash + validation timestamp in database |
| FR1.6 | Rejects transactions with previously seen transaction IDs |

### FR2: Rate Limiting

| ID | Requirement |
|----|-------------|
| FR2.1 | Rate limit validation endpoint by receipt hash (max 10 requests/hour per hash) |
| FR2.2 | Rate limit by IP address as secondary protection (max 30 requests/hour per IP) |
| FR2.3 | Return `429 Too Many Requests` with retry-after header when exceeded |

### FR3: iOS Client Changes

| ID | Requirement |
|----|-------------|
| FR3.1 | After StoreKit 2 local verification succeeds, send transaction JWS to backend |
| FR3.2 | Only grant credits after backend returns `valid` |
| FR3.3 | If backend is unreachable, queue transaction for retry (max 3 attempts with exponential backoff — aligns with Epic 3 stories 3.5/3.6) |
| FR3.4 | Store pending validations in Keychain so they survive app termination |
| FR3.5 | On app launch, retry any pending validations |

### FR4: Refund Detection

| ID | Requirement |
|----|-------------|
| FR4.1 | Register for Apple App Store Server Notifications V2 |
| FR4.2 | Handle `REFUND` notification type |
| FR4.3 | Mark transaction as refunded in database |
| FR4.4 | On next app sync, inform client of revoked credits (mechanism TBD — could be pull-based initially) |

---

## Non-Functional Requirements

| Category | Requirement |
|----------|-------------|
| **Security** | Backend never exposes Apple API credentials to client |
| **Security** | All communication over HTTPS/TLS 1.3 |
| **Security** | Transaction data validated against app bundle ID before processing |
| **Reliability** | Validation endpoint must handle Apple API downtime gracefully (queue and retry) |
| **Reliability** | Offline purchases must eventually be validated (no lost purchases) |
| **Performance** | Validation round-trip should not block UI — show optimistic state with confirmation |
| **Privacy** | No user-identifying data stored — only transaction IDs and receipt hashes |

---

## User Flow

```
┌─────────────────────────────────────────────────────────┐
│                    PURCHASE FLOW                         │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  User taps "Buy 10 Tokens"                              │
│       │                                                 │
│       ▼                                                 │
│  StoreKit 2 processes payment                           │
│       │                                                 │
│       ▼                                                 │
│  App receives signed Transaction (JWS)                  │
│       │                                                 │
│       ├──── Client-side verification (existing) ────┐   │
│       │     Still performed as fast sanity check     │   │
│       │                                              │   │
│       ▼                                              │   │
│  App sends JWS to POST /api/v1/receipts/validate     │   │
│       │                                              │   │
│       ▼                                              │   │
│  Backend validates with Apple App Store Server API    │   │
│       │                                              │   │
│       ├─── Valid ──► Store transaction, return 200    │   │
│       │                    │                         │   │
│       │                    ▼                         │   │
│       │              App grants credits              │   │
│       │                                              │   │
│       ├─── Invalid ──► Return 403                    │   │
│       │                    │                         │   │
│       │                    ▼                         │   │
│       │              App shows error, no credits     │   │
│       │                                              │   │
│       ├─── Unreachable ──► Queue for retry           │   │
│       │                    │                         │   │
│       │                    ▼                         │   │
│       │              Show "pending" state            │   │
│       │              Credits granted on confirmation │   │
│       │                                              │   │
│       └─── Already processed ──► Return 200 (idempotent)│
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---

## Decisions

| # | Question | Decision |
|---|----------|----------|
| 1 | Optimistic vs confirmed credits? | **Confirmed only** — credits granted only after server validates with Apple |
| 2 | Offline handling? | **Out of scope** — will be handled separately |
| 3 | Free $0.00 IAP for initial tokens? | **Deferred** — free users bypass this flow for now |
| 4 | Backend stack? | **Out of scope** — backend team decides |

## Scope Clarification

- This PRD covers **paid purchases only** — free initial tokens (3 credits) continue to be granted client-side without server validation
- Offline purchase queuing is excluded; to be scoped separately
- This flow applies only when the device is online at time of purchase

---

## Dependencies

- **Epic 3, Story 3.4** (Keychain migration) — pending validations stored in Keychain
- **Epic 3, Stories 3.5/3.6** (Network retry + backoff) — retry logic for failed validations
- **Epic 3, Story 3.3** (Refund detection) — FR4 extends this with server-side refund handling
- **Apple App Store Server API** access — requires App Store Connect configuration
- **Apple App Store Server Notifications V2** — requires endpoint registration in App Store Connect
