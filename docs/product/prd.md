---
title: "Product Requirements Document"
description: "Product requirements for project-rulebook-be backend"
author: Claude
date: 2026-01-23
---

# Product Requirements Document - project-rulebook-be

**Author:** Ivo
**Date:** 2025-12-25
**Status:** Production (serving iOS app, Android in development)

---

## Executive Summary

**Rulebook Backend** is the API service powering the Rulebook mobile applications. It provides AI-powered game box recognition and structured rules generation, enabling the mobile apps to deliver on the core promise: **"From box to playing in 60 seconds."**

The backend handles the computationally expensive AI processing, multi-model fallback logic, response caching, and rate limiting — allowing the mobile clients to remain lightweight and offline-capable.

### Vision Statement

**Instant intelligence for game night** — reliable, fast AI that transforms a photo into actionable rules.

### What Makes This Backend Special

| Differentiator | Why It Matters |
|----------------|----------------|
| **Multi-model AI resilience** | OpenAI + Gemini fallback ensures recognition even when one provider fails |
| **Intelligent caching** | Redis-based response caching reduces costs and improves latency for repeat queries |
| **Stateless design** | Enables offline-first mobile clients; no user accounts required for core features |
| **Rate limiting** | Protects AI costs while allowing fair usage (3 image analyses/hour, 10 rules/hour) |
| **Structured validation** | AI responses validated before delivery to ensure consistent, usable output |

### Core Value Proposition

The backend transforms raw AI capabilities into a **reliable, production-ready service** that mobile apps can depend on. While raw LLM APIs are powerful but unpredictable, Rulebook Backend provides consistent, validated, cached responses optimized for the game rules use case.

---

## Project Classification

| Attribute | Value |
|-----------|-------|
| **Technical Type** | API Backend Service |
| **Domain** | Consumer Entertainment / Utility |
| **Complexity** | Low (standard patterns, no regulatory requirements) |
| **Platform** | Swift 6.0 / Vapor 4.x / Linux (Railway deployment) |
| **Architecture** | Modular monolith with feature-scoped modules |
| **Project Context** | Brownfield — production service with active mobile clients |

### Technical Stack

| Component | Technology |
|-----------|------------|
| **Language** | Swift 6.0 |
| **Framework** | Vapor 4.110+ |
| **Database** | PostgreSQL (production) / SQLite (development) |
| **Cache** | Redis |
| **AI Providers** | OpenAI GPT-4, Google Gemini |
| **Authentication** | JWT (for admin/future features) |
| **API Documentation** | VaporToOpenAPI (auto-generated OpenAPI spec) |
| **Deployment** | Railway |

---

## Success Criteria

### API Success Metrics

| Criteria | Target | Measurement |
|----------|--------|-------------|
| **Availability** | 99.5% uptime | Railway monitoring |
| **Latency (P95)** | <30 seconds for image analysis | APM metrics |
| **Latency (P95)** | <15 seconds for rules generation | APM metrics |
| **Error Rate** | <1% of requests | Error logging |
| **Cache Hit Rate** | >60% for rules queries | Redis metrics |

### Business Success Metrics

| Criteria | Target | Measurement |
|----------|--------|-------------|
| **API Reliability** | Support mobile app launch | No blocking backend issues |
| **Cost Efficiency** | AI costs <$0.10 per successful scan | Provider billing |
| **Scalability** | Handle 1000 DAU without degradation | Load testing |

### Technical Success Metrics

| Criteria | Target |
|----------|--------|
| **Test Coverage** | >80% for critical paths |
| **Build Success** | CI passes on all PRs |
| **Security** | No critical vulnerabilities |
| **Documentation** | OpenAPI spec auto-generated and current |

---

## Product Scope

### Current State (MVP - Implemented)

#### API Endpoints

| Endpoint | Method | Purpose | Rate Limit |
|----------|--------|---------|------------|
| `/api/rules-generation/game-box-analysis` | POST | Image → Game identification | 3/hour |
| `/api/rules-generation/rules-summary` | POST | Title → Structured rules | 10/hour |

#### Modules

| Module | Status | Purpose |
|--------|--------|---------|
| **RulesGeneration** | ✅ Complete | Core AI pipeline for game recognition and rules |
| **Auth** | ✅ Complete | JWT-based authentication (admin, future user features) |
| **User** | ✅ Complete | User management foundation |
| **CacheAdmin** | ✅ Complete | Admin interface for cache management |
| **Frontend** | ✅ Complete | HTML template rendering for admin/landing |
| **Waitlist** | ✅ Complete | Pre-launch email collection |

#### Services

| Service | Status | Purpose |
|---------|--------|---------|
| **LLMService** | ✅ Complete | OpenAI + Gemini abstraction |
| **GoogleGeminiService** | ✅ Complete | Gemini API integration |
| **OpenAIService** | ✅ Complete | OpenAI API integration |
| **RedisAICacheService** | ✅ Complete | AI response caching |
| **AIResponseValidationService** | ✅ Complete | Validate AI output structure |
| **AIInputValidatorService** | ✅ Complete | Validate/sanitize input |
| **PromptSanitizerService** | ✅ Complete | Prevent prompt injection |
| **CacheKeyGeneratorService** | ✅ Complete | Consistent cache key generation |
| **EmailService** | ✅ Complete | Brevo integration for notifications |
| **ConfigurationService** | ✅ Complete | Environment-specific configuration |

---

### Phase 2: Improvements & Refactoring

| Feature | Priority | Description |
|---------|----------|-------------|
| **Response Time Optimization** | High | Optimize AI prompt engineering for faster responses |
| **Cache Warming** | Medium | Pre-populate cache for popular games |
| **Enhanced Fallback Logic** | Medium | Smarter model selection based on query type |
| **Structured Logging** | Medium | Better observability with correlation IDs |
| **Health Checks** | Medium | Kubernetes-ready health/readiness endpoints |
| **API Versioning** | Low | Version prefix for breaking changes (v1, v2) |

---

### Phase 3: Growth Features (v2.0)

| Feature | Priority | Description |
|---------|----------|-------------|
| **Receipt Validation** | High | Validate App Store/Play Store purchases server-side |
| **Feedback API** | Medium | Allow users to report incorrect rules |
| **Game Database** | Low | Curated database of verified game rules |
| **Subscription Support** | Low | Alternative to credit-based monetization |

---

### Out of Scope

| Feature | Rationale |
|---------|-----------|
| **Real-time collaboration** | Complexity; not aligned with use case |
| **User-generated content** | Moderation burden; focus on AI-generated |
| **Social features** | Mobile app concern, not backend |
| **Offline AI** | Cost/complexity; cloud AI is core value |
| **User Accounts** | Not needed for core functionality; app works without accounts |
| **Cloud Library Sync** | Removed; local-only game library is sufficient |
| **Usage Analytics (Backend)** | Handled by frontend apps |

---

## API Specification

### Base Configuration

| Environment | Base URL | Timeout |
|-------------|----------|---------|
| Production | `https://api.rulebook.app` | 30s |
| Staging | `https://project-rulebook-staging.up.railway.app` | 30s |
| Development | Local or ngrok tunnel | 60s |

### Endpoint 1: Game Box Analysis

**URL:** `POST /api/rules-generation/game-box-analysis`

**Purpose:** Identify a board game from a photo of its box.

**Request:**
- Content-Type: `image/jpeg` or `image/png` (binary stream)
- Max recommended size: 1024x1024

**Response:**
```json
{
  "guessedTitle": "Wingspan",
  "confidence": 94,
  "alternativeTitles": ["Wingspan: European Expansion"],
  "keywordsDetected": ["birds", "eggs", "stonemaier"],
  "notes": "Base game detected"
}
```

**Confidence Levels:**
| Range | Meaning | Mobile App Behavior |
|-------|---------|---------------------|
| 81-100% | High | Auto-proceed to rules generation |
| 61-80% | Medium | Show suggestion, ask for confirmation |
| 0-60% | Low | Require manual game name entry |

**Error Responses:**

| Status | Meaning | Retryable |
|--------|---------|-----------|
| 400 | Invalid image format | No |
| 413 | Image too large | No |
| 429 | Rate limit exceeded | Yes (after cooldown) |
| 503 | AI service unavailable | Yes |

---

### Endpoint 2: Rules Summary

**URL:** `POST /api/rules-generation/rules-summary`

**Purpose:** Generate structured rules for a given game title.

**Request:**
```json
{
  "gameTitle": "Wingspan"
}
```

**Response:**
```json
{
  "title": "Wingspan",
  "playerCount": "1-5 players",
  "playTime": "40-70 minutes",
  "summary": "A competitive bird-collection engine-building game...",
  "initialSetup": [
    "Give each player a player mat",
    "Shuffle the bird cards and deal 5 to each player",
    "Place food tokens in the bird feeder dice tower"
  ],
  "firstRoundGuide": [
    "On your turn, choose one of four actions",
    "Play a bird, gain food, lay eggs, or draw cards",
    "Actions become more powerful as you add birds"
  ],
  "winCondition": "Score the most points from birds, bonus cards, end-of-round goals, eggs, cached food, and tucked cards",
  "deepDive": [
    "Bird powers activate when you use the habitat row",
    "Some powers are 'when played', others are 'when activated'"
  ],
  "resources": {
    "videoLinks": [],
    "webLinks": []
  },
  "confidence": 95,
  "notes": "Base game rules; expansions add additional mechanics"
}
```

**Error Responses:**

| Status | Meaning | Retryable |
|--------|---------|-----------|
| 400 | Invalid/empty game title | No |
| 404 | Game not recognized | No (try different title) |
| 429 | Rate limit exceeded | Yes |
| 500 | AI generation failed | Yes |

---

## Functional Requirements

### Core API Requirements

| ID | Requirement | Status |
|----|-------------|--------|
| FR1 | API accepts image uploads for game box analysis | ✅ |
| FR2 | API returns game identification with confidence score | ✅ |
| FR3 | API provides alternative title suggestions | ✅ |
| FR4 | API generates structured rules from game title | ✅ |
| FR5 | Rules include setup, first round, win condition, deep dive | ✅ |
| FR6 | API validates and sanitizes all input | ✅ |
| FR7 | API validates AI response structure before returning | ✅ |

### Caching Requirements

| ID | Requirement | Status |
|----|-------------|--------|
| FR8 | Cache rules responses by normalized game title | ✅ |
| FR9 | Cache image analysis results by image hash | ✅ |
| FR10 | Provide cache statistics endpoint (admin) | ✅ |
| FR11 | Support cache invalidation (admin) | ✅ |

### Rate Limiting Requirements

| ID | Requirement | Status |
|----|-------------|--------|
| FR12 | Limit image analysis to 3 requests/hour per IP | ✅ |
| FR13 | Limit rules generation to 10 requests/hour per IP | ✅ |
| FR14 | Return 429 with retry-after header when limited | ✅ |

### AI Provider Requirements

| ID | Requirement | Status |
|----|-------------|--------|
| FR15 | Support OpenAI as primary AI provider | ✅ |
| FR16 | Support Google Gemini as fallback provider | ✅ |
| FR17 | Automatic failover when primary provider fails | ✅ |
| FR18 | Configurable provider selection per environment | ✅ |

### Security Requirements

| ID | Requirement | Status |
|----|-------------|--------|
| FR19 | All endpoints served over HTTPS | ✅ |
| FR20 | Prompt injection prevention via sanitization | ✅ |
| FR21 | No sensitive data in logs | ✅ |
| FR22 | Security headers on all responses | ✅ |

### Future Requirements (Phase 2-3)

| ID | Requirement | Priority |
|----|-------------|----------|
| FR23 | Receipt validation for IAP verification | High |
| FR24 | User feedback submission for incorrect rules | Medium |

---

## Non-Functional Requirements

### Performance

| NFR | Requirement | Target |
|-----|-------------|--------|
| NFR1 | Image analysis response time (P95) | <30 seconds |
| NFR2 | Rules generation response time (P95) | <15 seconds |
| NFR3 | Cached response time | <100ms |
| NFR4 | Cold start time | <5 seconds |

### Reliability

| NFR | Requirement | Target |
|-----|-------------|--------|
| NFR5 | Service availability | 99.5% uptime |
| NFR6 | Graceful degradation on AI failure | Fallback to secondary provider |
| NFR7 | No data loss on restart | Persistent cache in Redis |

### Scalability

| NFR | Requirement | Target |
|-----|-------------|--------|
| NFR8 | Concurrent request handling | 100 simultaneous requests |
| NFR9 | Horizontal scaling support | Stateless design |
| NFR10 | Database connection pooling | Configured for production load |

### Security

| NFR | Requirement |
|-----|-------------|
| NFR11 | HTTPS-only communication |
| NFR12 | Input validation on all endpoints |
| NFR13 | Rate limiting to prevent abuse |
| NFR14 | No API keys in client-accessible responses |

### Observability

| NFR | Requirement |
|-----|-------------|
| NFR15 | Structured logging with correlation IDs |
| NFR16 | Error tracking with context |
| NFR17 | Performance metrics collection |
| NFR18 | Health check endpoints |

---

## Technical Architecture

### System Context

```
┌─────────────────────────────────────────────────────────────────┐
│                         Mobile Clients                          │
│  ┌─────────────────┐              ┌─────────────────┐          │
│  │   iOS App       │              │  Android App    │          │
│  │   (SwiftUI/TCA) │              │  (Compose/MVI)  │          │
│  └────────┬────────┘              └────────┬────────┘          │
└───────────┼────────────────────────────────┼────────────────────┘
            │                                │
            │         HTTPS / REST           │
            └───────────────┬────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Rulebook Backend (Vapor)                     │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                    API Layer                              │  │
│  │  • RulesGenerationRouter                                  │  │
│  │  • Rate Limiting Middleware                               │  │
│  │  • Security Headers Middleware                            │  │
│  └──────────────────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                  Business Logic                           │  │
│  │  • RulesGenerationController                              │  │
│  │  • AI Response Validation                                 │  │
│  │  • Prompt Sanitization                                    │  │
│  └──────────────────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                    Services                               │  │
│  │  • LLMService (OpenAI + Gemini)                          │  │
│  │  • CacheService (Redis)                                   │  │
│  │  • EmailService (Brevo)                                   │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
            │                    │                    │
            ▼                    ▼                    ▼
     ┌───────────┐        ┌───────────┐        ┌───────────┐
     │ PostgreSQL│        │   Redis   │        │ AI APIs   │
     │ (Data)    │        │ (Cache)   │        │ (LLM)     │
     └───────────┘        └───────────┘        └───────────┘
```

### Module Structure

```
Sources/App/
├── Common/                    # Shared utilities
│   ├── Errors/               # Error types
│   ├── Extensions/           # Swift extensions
│   ├── Framework/            # Base protocols
│   ├── Middleware/           # Request middleware
│   └── Validation/           # Validation rules
├── Entrypoint/               # App bootstrap
├── Middlewares/              # Security, rate limiting
├── Modules/
│   ├── Auth/                 # Authentication
│   ├── CacheAdmin/           # Cache management
│   ├── Frontend/             # HTML templates
│   ├── RulesGeneration/      # Core business logic
│   ├── User/                 # User management
│   └── Waitlist/             # Email collection
└── Services/
    ├── Cache/                # Redis caching
    ├── Configuration/        # Environment config
    ├── Email/                # Brevo integration
    ├── LLM/                  # AI provider abstraction
    └── Validation/           # Input/output validation
```

---

## Deployment & Operations

### Environments

| Environment | Purpose | Database | Cache |
|-------------|---------|----------|-------|
| Development | Local development | SQLite | In-memory |
| Staging | Pre-production testing | PostgreSQL | Redis |
| Production | Live service | PostgreSQL | Redis |

### Environment Variables

| Variable | Purpose | Required |
|----------|---------|----------|
| `DATABASE_URL` | PostgreSQL connection string | Yes (prod) |
| `REDIS_URL` | Redis connection string | Yes (prod) |
| `OPENAI_API_KEY` | OpenAI API access | Yes |
| `GEMINI_API_KEY` | Google Gemini API access | Yes |
| `JWT_SECRET` | JWT signing secret | Yes |
| `BREVO_API_KEY` | Email service | Optional |

### Deployment Pipeline

1. Push to `staging` branch → Deploy to staging environment
2. Manual testing and validation
3. Merge to `main` → Deploy to production
4. Monitor for errors/performance issues

---

## Roadmap Summary

### Now (Implemented)
- Core API endpoints for image analysis and rules generation
- Multi-model AI with fallback
- Redis caching
- Rate limiting
- Security hardening

### Next (Phase 2)
- Performance optimization
- Enhanced observability
- Cache warming for popular games
- API versioning preparation

### Later (Phase 3 - v2.0)
- Receipt validation for purchases
- Feedback mechanism

---

*Product Requirements Document - project-rulebook-be*
*Generated: 2025-12-25*
