---
title: "Architecture Documentation"
description: "System architecture and design decisions for project-rulebook-be"
author: Claude
date: 2026-01-23
---

# Architecture Documentation

Technical architecture, design decisions, and system documentation.

## Contents

| Document | Description |
|----------|-------------|
| [technical-architecture.md](technical-architecture.md) | System architecture, patterns, and technical details |
| [architectural-vision.md](architectural-vision.md) | Core principles and design philosophy |
| [ADRs/](ADRs/) | Architecture Decision Records |

> **Note:** For API endpoint contracts and database schemas, see [Reference Documentation](../reference/).

## Reading Order

For new developers:

1. **Start with** `architectural-vision.md` - understand the principles
2. **Then read** `technical-architecture.md` - learn the implementation
3. **Reference** ADRs for specific decisions

## Architecture Decision Records (ADRs)

| ADR | Status | Topic |
|-----|--------|-------|
| [ADR-001](ADRs/ADR-001-ServiceRegistry.md) | Superseded | ServiceRegistry (replaced by property accessors) |
| [ADR-002](ADRs/ADR-002-Module-Colocation-and-Simplification.md) | Accepted | Module organization |
| [ADR-003](ADRs/ADR-003-Clean-Architecture-Migration.md) | Accepted | Clean architecture approach |
| [ADR-004](ADRs/ADR-004-AOP-Simplification.md) | Accepted | Aspect-oriented programming |

## Key Architecture Concepts

- **Modular Monolith**: Feature-based modules with clear boundaries
- **Property-Based DI**: Simple `req.services.*` and `req.repositories.*` access
- **Controller-Centric**: Business logic in controllers, not separate use case layer
- **Repository Pattern**: Database operations abstracted for testability
