# Epic 4: Platform Reliability & Performance

Improve system observability, response times, and operational resilience. Faster responses, better uptime, and improved debugging capabilities.

## Story 4.1: Add Health Check Endpoint
**Linear:** [RULE-141](https://linear.app/project-rulebook/issue/RULE-141)

**As a** DevOps engineer,
**I want** a health check endpoint,
**So that** Railway/Kubernetes can monitor service availability.

**Acceptance Criteria:**

**Given** a GET request to `/health`
**When** the service is running and healthy
**Then** response returns 200 OK with:
```json
{
  "status": "healthy",
  "timestamp": "2025-12-26T10:00:00Z",
  "checks": {
    "database": "ok",
    "redis": "ok"
  }
}
```

**Given** a database connection failure
**When** the health check runs
**Then** response returns 503 Service Unavailable with `"database": "error"`

**Given** a Redis connection failure
**When** the health check runs
**Then** response returns 503 Service Unavailable with `"redis": "error"`

**Given** the health endpoint
**When** it is called
**Then** it does NOT require authentication

---

## Story 4.2: Implement Structured Logging with Correlation IDs
**Linear:** [RULE-142](https://linear.app/project-rulebook/issue/RULE-142)

**As a** backend developer,
**I want** correlation IDs in all log entries,
**So that** I can trace requests across the entire lifecycle.

**Acceptance Criteria:**

**Given** an incoming request
**When** the request is processed
**Then** a unique `correlationId` is generated (or extracted from `X-Correlation-ID` header)
**And** the ID is attached to all log entries for that request

**Given** log output
**When** viewing logs
**Then** each entry includes: `timestamp`, `level`, `correlationId`, `message`, `context`

**Given** a request that calls external services (OpenAI, Gemini)
**When** logging external API calls
**Then** the correlation ID is included in those log entries

**Given** an error occurring during request processing
**When** the error is logged
**Then** it includes the correlation ID for easy debugging

**Given** the response headers
**When** a response is sent
**Then** the `X-Correlation-ID` header is included in the response

---

## Story 4.3: Optimize AI Prompt Engineering
**Linear:** [RULE-143](https://linear.app/project-rulebook/issue/RULE-143)

**As a** mobile app user,
**I want** faster AI responses,
**So that** I get game rules more quickly.

**Acceptance Criteria:**

**Given** the current prompts for game box analysis
**When** optimized prompts are deployed
**Then** average response time decreases by at least 20%

**Given** the current prompts for rules generation
**When** optimized prompts are deployed
**Then** average response time decreases by at least 20%

**Given** optimized prompts
**When** generating rules
**Then** output quality remains consistent (same structure, completeness)

**Given** the prompt optimization
**When** implemented
**Then** prompts are extracted to configurable templates for easy iteration

---

## Story 4.4: Implement Cache Warming for Popular Games
**Linear:** [RULE-144](https://linear.app/project-rulebook/issue/RULE-144)

**As a** mobile app user,
**I want** popular games to load instantly,
**So that** I don't wait for AI generation on common requests.

**Acceptance Criteria:**

**Given** the cache warming system
**When** it runs (on startup or scheduled)
**Then** it queries historical request data to identify top 50 most requested games

**Given** identified popular games
**When** cache warming executes
**Then** rules summaries are pre-generated and cached for each game

**Given** a cached popular game
**When** a user requests rules for that game
**Then** response time is <100ms (cache hit)

**Given** the warming process
**When** it runs
**Then** it respects rate limits and runs in background without impacting live traffic

**Given** an admin endpoint `/api/v1/admin/cache/warm`
**When** an admin triggers manual warming
**Then** the warming process starts immediately

---

## Story 4.5: Implement Low Confidence Fallback to Secondary Model
**Linear:** [RULE-145](https://linear.app/project-rulebook/issue/RULE-145)

**As a** mobile app user,
**I want** accurate game recognition,
**So that** I get correct rules even when the primary AI is uncertain.

**Acceptance Criteria:**

**Given** a game box analysis request
**When** the primary model (OpenAI) returns confidence < 70%
**Then** the request is automatically retried with secondary model (Gemini)

**Given** a rules generation request
**When** the primary model returns confidence < 70%
**Then** the request is automatically retried with secondary model

**Given** the secondary model returns higher confidence
**When** comparing results
**Then** the higher confidence result is returned to the user

**Given** both models return low confidence
**When** no clear winner exists
**Then** the primary model result is returned with a flag indicating low confidence

**Given** the fallback behavior
**When** it triggers
**Then** the event is logged with correlation ID for monitoring

---

## Story 4.6: Implement App Attest Verification for iOS
**Linear:** [RULE-126](https://linear.app/project-rulebook/issue/RULE-126)

**As a** backend operator,
**I want** API requests verified using Apple App Attest,
**So that** only legitimate iOS app instances can access protected endpoints.

**Acceptance Criteria:**

**Given** an iOS app with App Attest enabled
**When** the app makes its first API request
**Then** it sends an attestation object to `/api/v1/attest/verify`
**And** the backend validates it against Apple's servers
**And** returns a session token for subsequent requests

**Given** a valid attestation
**When** the backend verifies it
**Then** it checks: app ID matches, device is not jailbroken, attestation is fresh

**Given** an invalid or tampered attestation
**When** verification is attempted
**Then** response returns 403 Forbidden with appropriate error

**Given** protected API endpoints (rules-generation, receipts)
**When** a request is made without valid attestation token
**Then** response returns 401 Unauthorized

**Given** the attestation system
**When** configured
**Then** it can be disabled via environment variable for development/testing

**Given** attestation verification
**When** it succeeds or fails
**Then** the event is logged with device fingerprint for fraud detection
