---
stepsCompleted: [1]
step1CompletedAt: '2025-12-26'
inputDocuments:
  - path: '_bmad-output/prd.md'
    type: 'prd'
    description: 'Backend PRD for project-rulebook-be'
  - path: '_bmad-output/architecture.md'
    type: 'architecture'
    description: 'Architecture Decision Document'
  - path: 'docs/architecture/architectural-vision.md'
    type: 'supplementary'
    description: 'Architectural principles and vision'
  - path: 'docs/architecture/technical-architecture.md'
    type: 'supplementary'
    description: 'Technical implementation patterns'
project_name: 'project-rulebook-be'
user_name: 'Ivo'
date: '2025-12-26'
---

# project-rulebook-be - Epic Breakdown

## Overview

This document provides the complete epic and story breakdown for project-rulebook-be, decomposing the requirements from the PRD and Architecture into implementable stories.

## Requirements Inventory

### Functional Requirements

**Core API Requirements (Implemented):**
- FR1: API accepts image uploads for game box analysis ✅
- FR2: API returns game identification with confidence score ✅
- FR3: API provides alternative title suggestions ✅
- FR4: API generates structured rules from game title ✅
- FR5: Rules include setup, first round, win condition, deep dive ✅
- FR6: API validates and sanitizes all input ✅
- FR7: API validates AI response structure before returning ✅

**Caching Requirements (Implemented):**
- FR8: Cache rules responses by normalized game title ✅
- FR9: Cache image analysis results by image hash ✅
- FR10: Provide cache statistics endpoint (admin) ✅
- FR11: Support cache invalidation (admin) ✅

**Rate Limiting Requirements (Implemented):**
- FR12: Limit image analysis to 3 requests/hour per IP ✅
- FR13: Limit rules generation to 10 requests/hour per IP ✅
- FR14: Return 429 with retry-after header when limited ✅

**AI Provider Requirements (Implemented):**
- FR15: Support OpenAI as primary AI provider ✅
- FR16: Support Google Gemini as fallback provider ✅
- FR17: Automatic failover when primary provider fails ✅
- FR18: Configurable provider selection per environment ✅

**Security Requirements (Implemented):**
- FR19: All endpoints served over HTTPS ✅
- FR20: Prompt injection prevention via sanitization ✅
- FR21: No sensitive data in logs ✅
- FR22: Security headers on all responses ✅

**Future Requirements (To Be Implemented):**
- FR23: Receipt validation for IAP verification [Priority: High]
- FR24: User feedback submission for incorrect rules [Priority: Medium]
- FR25: Usage analytics collection (anonymous) [Priority: Medium]

**Out of Scope (Removed):**
- ~~User account creation and authentication~~ - Not implementing
- ~~Cloud sync of saved games library~~ - Not implementing

### Non-Functional Requirements

**Performance:**
- NFR1: Image analysis response time (P95) <30 seconds
- NFR2: Rules generation response time (P95) <15 seconds
- NFR3: Cached response time <100ms
- NFR4: Cold start time <5 seconds

**Reliability:**
- NFR5: Service availability 99.5% uptime
- NFR6: Graceful degradation on AI failure (fallback to secondary provider)
- NFR7: No data loss on restart (persistent cache in Redis)

**Scalability:**
- NFR8: Concurrent request handling - 100 simultaneous requests
- NFR9: Horizontal scaling support - stateless design
- NFR10: Database connection pooling - configured for production load

**Security:**
- NFR11: HTTPS-only communication
- NFR12: Input validation on all endpoints
- NFR13: Rate limiting to prevent abuse
- NFR14: No API keys in client-accessible responses

**Observability:**
- NFR15: Structured logging with correlation IDs
- NFR16: Error tracking with context
- NFR17: Performance metrics collection
- NFR18: Health check endpoints

### Additional Requirements

**From Architecture Document:**
- AR1: API Versioning - URL prefix versioning (`/api/v1/`) for all endpoints
- AR2: Receipt Validation Module - New module `Modules/Receipts/` with App Store and Play Store validation services
- AR3: Module Structure Pattern - All new modules follow established vertical slice structure
- AR4: Service Protocol-First Design - All services use protocol-based design for testability
- AR5: Error Handling Pattern - All errors conform to `AppError` enum
- AR6: Naming Conventions - Database tables (snake_case, plural), API endpoints (kebab-case), Swift types (PascalCase)

**From Architectural Vision (docs/architecture):**
- AV1: Elegant Simplicity - "Build less, but build it better"
- AV2: Contextual Cohesion - Everything related to a feature lives together within its module boundary
- AV3: Progressive Disclosure - Reveal complexity only when necessary
- AV4: Framework Harmony - Work with Vapor conventions, not against them
- AV5: Three-Strike Rule - Don't create abstractions until the third occurrence
- AV6: Standard Library First - Check Swift/Vapor before creating custom utilities

### FR Coverage Map

{{requirements_coverage_map}}

## Epic List

{{epics_list}}
