# Data Models - project-rulebook-be

**Generated:** 2026-01-19
**ORM:** Fluent (Vapor)
**Databases:** PostgreSQL (primary), SQLite (development)

---

## Overview

This document catalogs all Fluent database models and their schemas discovered in the project-rulebook-be codebase.

---

## User Module

### UserAccountModel

**Table:** `users`
**Migration:** `UserMigrations.v1`

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `id` | UUID | Yes | Primary key |
| `email` | String | Yes | Unique constraint |
| `password` | String | No | Hashed via Bcrypt |
| `firstName` | String | No | |
| `lastName` | String | No | |
| `appleUserIdentifier` | String | No | Apple Sign In identifier |
| `isAdmin` | Bool | Yes | Admin privileges |
| `isEmailVerified` | Bool | Yes | Email verification status |
| `avatar` | UUID | No | Avatar reference |
| `createdAt` | DateTime | Auto | Creation timestamp |
| `updatedAt` | DateTime | Auto | Update timestamp |
| `deletedAt` | DateTime | Auto | Soft delete timestamp |

**Relationships:** None (root entity)

**Seed Data:** Admin user (`root@localhost.com` / `ChangeMe1`)

---

## Auth Module

### PasswordTokenModel

**Table:** (inferred from migration)
**Migration:** `AuthMigrations.v1`

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `id` | UUID | Yes | Primary key |
| `userId` | UUID | Yes | Foreign key → users |
| `value` | String | Yes | Token value |
| `expiresAt` | DateTime | Yes | Expiration timestamp |

**Relationships:**
- `@Parent` → `UserAccountModel`

### EmailTokenModel

**Table:** (inferred from migration)
**Migration:** `AuthMigrations.v1`

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `id` | UUID | Yes | Primary key |
| `userId` | UUID | Yes | Foreign key → users |
| `value` | String | Yes | Token value |
| `expiresAt` | DateTime | Yes | Expiration timestamp |

**Relationships:**
- `@Parent` → `UserAccountModel`

### RefreshTokenModel

**Table:** (inferred from migration)
**Migration:** `AuthMigrations.v1`

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `id` | UUID | Yes | Primary key |
| `value` | String | Yes | Token value |
| `userId` | UUID | Yes | Foreign key → users |
| `expiresAt` | DateTime | Yes | Expiration timestamp |

**Relationships:**
- `@Parent` → `UserAccountModel`

---

## Waitlist Module

### WaitlistEntryModel

**Table:** (inferred from migration)
**Migration:** `WaitlistMigrations.v1`

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `id` | UUID | Yes | Primary key |
| `email` | String | Yes | Subscriber email |
| `unsubscribeToken` | String | Yes | Unsubscribe token |

**Relationships:** None

---

## Rules Generation Module

### GeneratedRuleModel

**Table:** (inferred from migration)
**Migration:** `RulesGenerationMigrations.v1`

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `id` | UUID | Yes | Primary key |
| `originalTitle` | String | Yes | Original game title input |
| `sanitizedTitle` | String | Yes | Normalized title |
| `cacheKey` | String | Yes | Cache lookup key |
| `title` | String | Yes | Display title |
| `playerCount` | String | Yes | Player count info |
| `playTime` | String | Yes | Play time info |
| `summary` | String | Yes | Game summary |
| `initialSetup` | String | Yes | Setup instructions |
| `firstRoundGuide` | String | Yes | First round guide |
| `winCondition` | String | Yes | Win conditions |
| `deepDive` | String | Yes | Detailed rules |
| `resourcesVideoLinks` | String | Yes | Video tutorial links |
| `resourcesWebLinks` | String | Yes | Web resource links |
| `confidence` | String | Yes | AI confidence score |
| `notes` | String | Yes | Additional notes |

**Relationships:** None

---

## Entity Relationship Diagram

```
┌─────────────────────┐
│   UserAccountModel  │
│      (users)        │
├─────────────────────┤
│ id: UUID [PK]       │
│ email: String [UQ]  │
│ password: String?   │
│ firstName: String?  │
│ lastName: String?   │
│ isAdmin: Bool       │
│ isEmailVerified: Bool│
│ ...                 │
└─────────┬───────────┘
          │
          │ 1:N
          ├────────────────────────────────┐
          │                                │
          ▼                                ▼
┌─────────────────────┐      ┌─────────────────────┐
│  RefreshTokenModel  │      │   EmailTokenModel   │
├─────────────────────┤      ├─────────────────────┤
│ id: UUID [PK]       │      │ id: UUID [PK]       │
│ value: String       │      │ value: String       │
│ userId: UUID [FK]   │      │ userId: UUID [FK]   │
│ expiresAt: DateTime │      │ expiresAt: DateTime │
└─────────────────────┘      └─────────────────────┘
          │
          │
          ▼
┌─────────────────────┐
│ PasswordTokenModel  │
├─────────────────────┤
│ id: UUID [PK]       │
│ value: String       │
│ userId: UUID [FK]   │
│ expiresAt: DateTime │
└─────────────────────┘


┌─────────────────────┐      ┌─────────────────────┐
│ WaitlistEntryModel  │      │ GeneratedRuleModel  │
├─────────────────────┤      ├─────────────────────┤
│ id: UUID [PK]       │      │ id: UUID [PK]       │
│ email: String       │      │ originalTitle: Str  │
│ unsubscribeToken    │      │ sanitizedTitle: Str │
└─────────────────────┘      │ cacheKey: String    │
                             │ title: String       │
                             │ ...                 │
                             └─────────────────────┘
```

---

## Migration Summary

| Module | Migration | Description |
|--------|-----------|-------------|
| User | `UserMigrations.v1` | Creates users table |
| User | `UserMigrations.seed` | Seeds admin user |
| Auth | `AuthMigrations.v1` | Creates auth token tables |
| Waitlist | `WaitlistMigrations.v1` | Creates waitlist table |
| RulesGeneration | `RulesGenerationMigrations.v1` | Creates generated rules table |

---

## Database Schema Statistics

| Metric | Count |
|--------|-------|
| Total Tables | 5 |
| Total Fields | ~35 |
| Foreign Key Relationships | 3 |
| Unique Constraints | 1 (email) |
