# API Contracts - project-rulebook-be

**Generated:** 2026-01-19
**Type:** REST API (Vapor/Swift)
**Base URL:** `/api/v1`

---

## Overview

This document catalogs all API endpoints discovered in the project-rulebook-be codebase. The API uses JWT bearer token authentication and supports OpenAPI specification via VaporToOpenAPI.

---

## Authentication Module (`/api/v1/auth`)

**Tag:** Auth
**Description:** User authentication and account management

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| POST | `/sign-in` | Basic (email/password) | Authenticate user with email and password. Returns JWT access token and refresh token. |
| POST | `/sign-up` | None | Create new user account with email and password. Sends email verification. |
| POST | `/apple-auth` | None | Authenticate or create account using Apple Sign In. |
| POST | `/refresh` | None | Exchange refresh token for new access token. |
| POST | `/reset-password` | None | Request password reset email. |
| POST | `/logout` | Bearer | Invalidate current refresh token and end authenticated session. |

### Request/Response Types:
- `Auth.Login.Request` / `Auth.Login.Response`
- `Auth.SignUp.Request` / `Auth.SignUp.Response`
- `Auth.Apple.Request` / `Auth.Apple.Response`
- `Auth.TokenRefresh.Request` / `Auth.TokenRefresh.Response`
- `Auth.PasswordReset.Request`

---

## User Module (`/api/v1/user`)

**Tag:** User
**Description:** User profile management and account operations

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| GET | `/me` | Bearer | Retrieve current authenticated user's profile information. |
| PATCH | `/update` | Bearer | Update current user's profile information (email, first name, last name). |
| DELETE | `/delete` | Bearer | Permanently delete current user account and all associated data. |
| GET | `/list` | Bearer + Admin | List all user accounts in the system. Admin only. |

### Request/Response Types:
- `User.Detail.Response`
- `User.Update.Request`

---

## Rules Generation Module (`/api/v1/rules-generation`)

**Tag:** Rules Generation
**Description:** AI-powered game box recognition and rules summarization

| Method | Endpoint | Auth | Rate Limit | Description |
|--------|----------|------|------------|-------------|
| POST | `/game-box-analysis` | None | 3/hour | Upload game box image (JPEG/PNG) for AI-powered title recognition. |
| POST | `/rules-summary` | None | 10/hour | Generate AI-powered rules summary for a board game by title. |

### Request/Response Types:
- `GameboxRecognition.Response`
- `RulesSummary.Request` / `RulesSummary.Response`

---

## Waitlist Module (`/api/v1/waitlist`)

**Tag:** Waitlist
**Description:** Email waitlist management

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| POST | `/` | None | Subscribe an email address to the waitlist. |
| GET | `/unsubscribe/:token` | None | Unsubscribe from the waitlist using token. |
| GET | `/stats` | Bearer + Admin | Get waitlist statistics. Admin only. |
| POST | `/notify` | Bearer + Admin | Send launch notification to all unnotified subscribers. Admin only. |

### Request/Response Types:
- `Waitlist.Subscribe.Request` / `Waitlist.Subscribe.Response`
- `Waitlist.Unsubscribe.Response`
- `Waitlist.Stats.Response`
- `Waitlist.Notify.Response`

---

## Cache Admin Module (`/api/admin/cache`)

**Tag:** Cache Admin
**Description:** Cache monitoring and management for administrators

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| GET | `/stats` | Bearer + Admin | Retrieve comprehensive cache statistics. |
| GET | `/health` | Bearer + Admin | Check cache health status with diagnostics. |
| GET | `/entries` | Bearer + Admin | List all cache entries with metadata. |
| GET | `/redis/health` | Bearer + Admin | Check Redis connection health and latency. |
| DELETE | `/` | Bearer + Admin | Clear all cache entries. |
| POST | `/cleanup` | Bearer + Admin | Manually trigger cache cleanup. |

### Request/Response Types:
- `CacheAdmin.Statistics.Response`
- `CacheAdmin.Health.Response`
- `CacheAdmin.Entries.Response`
- `CacheAdmin.RedisHealth.Response`
- `CacheAdmin.Clear.Response`
- `CacheAdmin.Cleanup.Response`

---

## System Endpoints

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| GET | `/health` | None | Health check endpoint |

---

## Authentication

All protected endpoints require JWT Bearer token authentication:
```
Authorization: Bearer <access_token>
```

Admin endpoints additionally require the user to have `isAdmin: true` in their account (enforced by `EnsureAdminUserMiddleware`).

---

## Rate Limiting

Rate limiting is applied via `RateLimitMiddleware`:
- Rules Generation endpoints are rate-limited (3 req/hour for image analysis, 10 req/hour for rules)
- Other endpoints may have global rate limits configured

---

## Endpoint Summary

| Module | Public | Protected | Admin | Total |
|--------|--------|-----------|-------|-------|
| Auth | 4 | 1 | 0 | 5 |
| User | 0 | 3 | 1 | 4 |
| Rules Generation | 2 | 0 | 0 | 2 |
| Waitlist | 2 | 0 | 2 | 4 |
| Cache Admin | 0 | 0 | 6 | 6 |
| System | 1 | 0 | 0 | 1 |
| **Total** | **9** | **4** | **9** | **22** |
