# Epic 1: API Versioning & Stability

Establish versioned API endpoints to enable safe, backward-compatible evolution of the API. Mobile apps can pin to specific API versions, ensuring stability during updates.

## Story 1.1: Add API Version Prefix to All Public Routes
**Linear:** [RULE-130](https://linear.app/project-rulebook/issue/RULE-130)

**As a** mobile app developer,
**I want** all API endpoints to use the `/api/v1/` prefix,
**So that** I can pin my app to a specific API version for stability.

**Acceptance Criteria:**

**Given** the RulesGeneration module routes
**When** a client calls `/api/v1/rules-generation/game-box-analysis`
**Then** the endpoint responds correctly
**And** the old `/api/rules-generation/game-box-analysis` route no longer exists

**Given** the Auth module routes
**When** a client calls `/api/v1/auth/sign-in`, `/api/v1/auth/sign-up`, `/api/v1/auth/refresh-token`
**Then** all auth endpoints respond correctly under the new prefix

**Given** the User module routes
**When** a client calls `/api/v1/users/profile`
**Then** user endpoints respond correctly under the new prefix

**Given** the Waitlist module routes
**When** a client calls `/api/v1/waitlist/subscribe`
**Then** waitlist endpoints respond correctly under the new prefix

**Given** any request to unversioned `/api/` routes
**When** a client calls the old paths
**Then** the server returns 404 Not Found

---

## Story 1.2: Implement Remote Config Endpoint
**Linear:** [RULE-123](https://linear.app/project-rulebook/issue/RULE-123)

**As a** mobile app,
**I want** to fetch feature flags and configuration from the backend,
**So that** app behavior can be controlled remotely without app updates.

**Acceptance Criteria:**

**Given** a GET request to `/api/v1/config`
**When** the request is made
**Then** response returns a JSON dictionary of configuration values:
```json
{
  "featureFlags": {
    "enableNewScanner": true,
    "showPromotion": false
  },
  "settings": {
    "maxRetries": 3,
    "cacheTimeoutSeconds": 300
  },
  "version": "1.0.0"
}
```

**Given** the config endpoint
**When** it is called
**Then** it does NOT require authentication (public endpoint)

**Given** configuration data
**When** stored in the system
**Then** it is persisted in PostgreSQL with Redis caching (5 min TTL)

**Given** configuration values
**When** defining them
**Then** they support typed values: boolean, integer, string, JSON object

**Given** an admin endpoint `/api/v1/admin/config`
**When** an authenticated admin updates configuration
**Then** the cache is invalidated and new values take effect immediately

**Given** a cache miss
**When** Redis cache expires
**Then** configuration is re-fetched from PostgreSQL and cached

---
